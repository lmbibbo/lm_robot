//+------------------------------------------------------------------+
//|                                                      Executor.mqh|
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#ifndef LMROBOT_EXECUTION_EXECUTOR_MQH
#define LMROBOT_EXECUTION_EXECUTOR_MQH

#include <Trade/Trade.mqh>
#include "../Core/BasketState.mqh"

//+------------------------------------------------------------------+
//| Resultado de una operacion de ejecucion.                         |
//+------------------------------------------------------------------+
enum ENUM_EXECUTION_STATUS
  {
   EXECUTION_STATUS_OK                = 0,
   EXECUTION_STATUS_REJECTED          = 1,
   EXECUTION_STATUS_RETRY_EXHAUSTED   = 2,
   EXECUTION_STATUS_INVALID_STOP      = 3,
   EXECUTION_STATUS_INVALID_VOLUME    = 4,
   EXECUTION_STATUS_NO_MARGIN         = 5
  };

//+------------------------------------------------------------------+
//| Limites y propiedades de ejecucion del simbolo.                  |
//+------------------------------------------------------------------+
struct SymbolLimits
  {
   string   symbol;
   double   point;
   double   volumeStep;
   double   volumeMin;
   double   volumeMax;
   double   stopsLevelPoints;
   double   freezeLevelPoints;
   bool     valid;
  };

//+------------------------------------------------------------------+
//| Configuracion de reintentos y magic.                             |
//+------------------------------------------------------------------+
struct ExecutorConfig
  {
   int      maxAttempts;
   int      retryDelayMs;
   int      deadlineMs;
   long     magic;
  };

//+------------------------------------------------------------------+
//| Orden normalizada que recibe el backend.                         |
//+------------------------------------------------------------------+
struct OrderRequest
  {
   string            symbol;
   ENUM_ORDER_TYPE   type;
   double            volume;
   double            price;
   double            sl;
   double            tp;
   string            comment;
   long              magic;
  };

//+------------------------------------------------------------------+
//| Resultado detallado de una ejecucion.                            |
//+------------------------------------------------------------------+
struct ExecutionReport
  {
   ENUM_EXECUTION_STATUS status;
   int                   attempts;
   int                   retcode;
   int                   modifiedCount;
   int                   failedCount;
   double                normalizedVolume;
   double                requiredMargin;
   string                reason;
  };

//+------------------------------------------------------------------+
//| Deja el reporte en estado neutro.                                |
//+------------------------------------------------------------------+
void LmResetExecutionReport(ExecutionReport &report)
  {
   report.status           = EXECUTION_STATUS_REJECTED;
   report.attempts         = 0;
   report.retcode          = 0;
   report.modifiedCount    = 0;
   report.failedCount      = 0;
   report.normalizedVolume = 0.0;
   report.requiredMargin   = 0.0;
   report.reason           = "";
  }

//+------------------------------------------------------------------+
//| Carga los limites de volumen y stops del simbolo.                |
//+------------------------------------------------------------------+
bool LmLoadSymbolLimits(const string symbol, SymbolLimits &limits)
  {
   limits.symbol            = symbol;
   limits.point             = SymbolInfoDouble(symbol, SYMBOL_POINT);
   limits.volumeStep        = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   limits.volumeMin         = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   limits.volumeMax         = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   limits.stopsLevelPoints  = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   limits.freezeLevelPoints = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   limits.valid = (limits.point > 0.0 &&
                   limits.volumeStep > 0.0 &&
                   limits.volumeMin > 0.0 &&
                   limits.volumeMax >= limits.volumeMin);

   return(limits.valid);
  }

//+------------------------------------------------------------------+
//| Normaliza el volumen al step y lo acota a min/max del simbolo.   |
//+------------------------------------------------------------------+
double LmNormalizeVolume(const double requested,
                         const double step,
                         const double minVolume,
                         const double maxVolume)
  {
   if(step <= 0.0 || minVolume <= 0.0 || maxVolume < minVolume || requested <= 0.0)
      return(0.0);

   double maxValid = MathFloor((maxVolume + 1e-9) / step) * step;
   double minValid = MathCeil((minVolume - 1e-9) / step) * step;

   if(maxValid < minValid || maxValid <= 0.0)
      return(0.0);

   double normalized = MathRound(requested / step) * step;

   if(normalized < minValid)
      normalized = minValid;

   if(normalized > maxValid)
      normalized = maxValid;

   return(NormalizeDouble(normalized, 8));
  }

//+------------------------------------------------------------------+
//| Valida que el stop loss exista y respete el stops level.          |
//+------------------------------------------------------------------+
bool LmValidateStopLoss(const ENUM_ORDER_TYPE type,
                        const double price,
                        const double sl,
                        const double stopsLevelPoints,
                        const double point,
                        string &reason)
  {
   reason = "";

   if(sl <= 0.0)
     {
      reason = "stop loss ausente";
      return(false);
     }

   if(point <= 0.0 || price <= 0.0)
     {
      reason = "precio o punto del simbolo invalido";
      return(false);
     }

   double minDistance = stopsLevelPoints * point;

   if(type == ORDER_TYPE_BUY)
     {
      if(sl >= price)
        {
         reason = "stop loss de compra debe estar por debajo del precio";
         return(false);
        }

      if(price - sl < minDistance - 1e-12)
        {
         reason = StringFormat("stop loss dentro del stops level (%.1f < %.1f puntos)",
                               (price - sl) / point, stopsLevelPoints);
         return(false);
        }

      return(true);
     }

   if(type == ORDER_TYPE_SELL)
     {
      if(sl <= price)
        {
         reason = "stop loss de venta debe estar por encima del precio";
         return(false);
        }

      if(sl - price < minDistance - 1e-12)
        {
         reason = StringFormat("stop loss dentro del stops level (%.1f < %.1f puntos)",
                               (sl - price) / point, stopsLevelPoints);
         return(false);
        }

      return(true);
     }

   reason = "tipo de orden no soportado";
   return(false);
  }

//+------------------------------------------------------------------+
//| Compara el margen requerido contra el margen libre.              |
//+------------------------------------------------------------------+
bool LmHasEnoughMargin(const double requiredMargin, const double freeMargin)
  {
   return(requiredMargin >= 0.0 && freeMargin >= requiredMargin);
  }

//+------------------------------------------------------------------+
//| Backend abstracto: produccion usa CTrade, tests usan un simulado.|
//+------------------------------------------------------------------+
class IExecutionBackend
  {
public:
   virtual bool Send(const OrderRequest &request, int &retcode)
     {
      retcode = 0;
      return(false);
     }

   virtual bool Modify(const ulong ticket, const double sl, const double tp, int &retcode)
     {
      retcode = 0;
      return(false);
     }
  };

//+------------------------------------------------------------------+
//| Proveedor de margen abstracto.                                   |
//+------------------------------------------------------------------+
class IAccountInfoProvider
  {
public:
   virtual double FreeMargin()
     {
      return(0.0);
     }

   virtual bool CalcMargin(const ENUM_ORDER_TYPE type, const string symbol,
                           const double volume, const double price, double &margin)
     {
      margin = 0.0;
      return(false);
     }
  };

//+------------------------------------------------------------------+
//| Backend real con CTrade.                                         |
//+------------------------------------------------------------------+
class CLiveExecutionBackend : public IExecutionBackend
  {
private:
   CTrade m_trade;

public:
   CLiveExecutionBackend(const long magic = 0)
     {
      m_trade.SetExpertMagicNumber((ulong)magic);
      m_trade.SetDeviationInPoints(10);
     }

   void SetDeviation(const int points) { m_trade.SetDeviationInPoints(points); }
   void SetMagic(const long magic)     { m_trade.SetExpertMagicNumber((ulong)magic); }

   virtual bool Send(const OrderRequest &request, int &retcode)
     {
      bool result = false;

      //--- En modo portafolio cada estrategia envia con su propio magic.
      if(request.magic > 0)
         m_trade.SetExpertMagicNumber((ulong)request.magic);

      if(request.type == ORDER_TYPE_BUY)
         result = m_trade.Buy(request.volume, request.symbol, request.price,
                              request.sl, request.tp, request.comment);
      else if(request.type == ORDER_TYPE_SELL)
         result = m_trade.Sell(request.volume, request.symbol, request.price,
                               request.sl, request.tp, request.comment);

      retcode = (int)m_trade.ResultRetcode();
      return(result);
     }

   virtual bool Modify(const ulong ticket, const double sl, const double tp, int &retcode)
     {
      bool result = m_trade.PositionModify(ticket, sl, tp);
      retcode = (int)m_trade.ResultRetcode();
      return(result);
     }
  };

//+------------------------------------------------------------------+
//| Proveedor real de margen y cuenta.                               |
//+------------------------------------------------------------------+
class CLiveAccountInfoProvider : public IAccountInfoProvider
  {
public:
   virtual double FreeMargin()
     {
      return(AccountInfoDouble(ACCOUNT_MARGIN_FREE));
     }

   virtual bool CalcMargin(const ENUM_ORDER_TYPE type, const string symbol,
                           const double volume, const double price, double &margin)
     {
      return(OrderCalcMargin(type, symbol, volume, price, margin));
     }
  };

//+------------------------------------------------------------------+
//| Ejecutor: valida, normaliza y reintenta de forma acotada.        |
//+------------------------------------------------------------------+
class CExecutor
  {
private:
   IExecutionBackend      *m_backend;
   IAccountInfoProvider   *m_accounts;
   SymbolLimits            m_limits;
   ExecutorConfig          m_config;

public:
   CExecutor()
     {
      m_backend  = NULL;
      m_accounts = NULL;
     }

   bool Init(IExecutionBackend *backend, IAccountInfoProvider *accounts,
             const SymbolLimits &limits, const ExecutorConfig &config)
     {
      if(backend == NULL || accounts == NULL)
         return(false);

      if(!limits.valid || config.maxAttempts <= 0)
         return(false);

      m_backend  = backend;
      m_accounts = accounts;
      m_limits   = limits;
      m_config   = config;
      return(true);
     }

   //--- Envia una orden con volumen normalizado, SL validado y margen.
   ENUM_EXECUTION_STATUS Send(const OrderRequest &request, ExecutionReport &report)
     {
      LmResetExecutionReport(report);

      if(m_backend == NULL || m_accounts == NULL)
        {
         report.reason = "executor sin backend o proveedor de cuenta";
         return(report.status);
        }

      if(request.symbol != m_limits.symbol)
        {
         report.reason = "el simbolo de la orden no coincide con el executor";
         return(report.status);
        }

      if(request.type != ORDER_TYPE_BUY && request.type != ORDER_TYPE_SELL)
        {
         report.reason = "tipo de orden no soportado";
         return(report.status);
        }

      double volume = LmNormalizeVolume(request.volume, m_limits.volumeStep,
                                        m_limits.volumeMin, m_limits.volumeMax);
      report.normalizedVolume = volume;

      if(volume <= 0.0)
        {
         report.status = EXECUTION_STATUS_INVALID_VOLUME;
         report.reason = "volumen invalido tras normalizacion";
         return(report.status);
        }

      string reason = "";
      if(!LmValidateStopLoss(request.type, request.price, request.sl,
                             m_limits.stopsLevelPoints, m_limits.point, reason))
        {
         report.status = EXECUTION_STATUS_INVALID_STOP;
         report.reason = reason;
         return(report.status);
        }

      double requiredMargin = 0.0;
      if(!m_accounts.CalcMargin(request.type, request.symbol, volume,
                                request.price, requiredMargin))
        {
         report.reason = "no se pudo calcular el margen requerido";
         return(report.status);
        }

      report.requiredMargin = requiredMargin;

      double freeMargin = m_accounts.FreeMargin();
      if(!LmHasEnoughMargin(requiredMargin, freeMargin))
        {
         report.status = EXECUTION_STATUS_NO_MARGIN;
         report.reason = StringFormat("margen insuficiente (requerido=%.2f, libre=%.2f)",
                                      requiredMargin, freeMargin);
         return(report.status);
        }

      OrderRequest normalized = request;
      normalized.volume = volume;
      normalized.magic  = (request.magic > 0 ? request.magic : m_config.magic);

      uint start     = GetTickCount();
      bool sent      = false;
      int  retcode   = 0;
      int  attempt   = 0;

      while(attempt < m_config.maxAttempts)
        {
         if(m_config.deadlineMs > 0 &&
            (int)(GetTickCount() - start) >= m_config.deadlineMs)
            break;

         attempt++;
         sent = m_backend.Send(normalized, retcode);
         report.retcode = retcode;

         if(sent)
            break;

         if(m_config.retryDelayMs > 0 && attempt < m_config.maxAttempts)
            Sleep(m_config.retryDelayMs);
        }

      report.attempts = attempt;

      if(sent)
        {
         report.status = EXECUTION_STATUS_OK;
         return(report.status);
        }

      report.status = EXECUTION_STATUS_RETRY_EXHAUSTED;
      report.reason = "reintentos agotados o deadline vencido";
      return(report.status);
     }

   //--- Modifica SL y TP de todas las posiciones de la canasta.
   ENUM_EXECUTION_STATUS ModifyBasket(const BasketPosition &positions[],
                                      const double sl, const double tp,
                                      ExecutionReport &report)
     {
      LmResetExecutionReport(report);

      if(m_backend == NULL)
        {
         report.reason = "executor sin backend";
         return(report.status);
        }

      int total = ArraySize(positions);
      if(total <= 0)
        {
         report.reason = "canasta vacia";
         return(report.status);
        }

      uint start = GetTickCount();

      for(int i = 0; i < total; i++)
        {
         if(positions[i].ticket == 0)
           {
            report.failedCount++;
            continue;
           }

         bool modified = false;
         int  attempt  = 0;
         int  retcode  = 0;

         while(attempt < m_config.maxAttempts)
           {
            if(m_config.deadlineMs > 0 &&
               (int)(GetTickCount() - start) >= m_config.deadlineMs)
               break;

            attempt++;
            modified = m_backend.Modify(positions[i].ticket, sl, tp, retcode);
            report.retcode = retcode;

            if(modified)
               break;

            if(m_config.retryDelayMs > 0 && attempt < m_config.maxAttempts)
               Sleep(m_config.retryDelayMs);
           }

         report.attempts += attempt;

         if(modified)
            report.modifiedCount++;
         else
            report.failedCount++;
        }

      if(report.failedCount == 0)
        {
         report.status = EXECUTION_STATUS_OK;
         return(report.status);
        }

      report.status = EXECUTION_STATUS_RETRY_EXHAUSTED;
      report.reason = StringFormat("proteccion aplicada a %d de %d posiciones",
                                   report.modifiedCount, total);
      return(report.status);
     }

   //--- Version de produccion: recolecta la canasta real y la modifica.
   ENUM_EXECUTION_STATUS ModifyBasketLive(const long magic,
                                          const double sl, const double tp,
                                          ExecutionReport &report)
     {
      BasketPosition positions[];
      LmCollectBasketPositions(m_limits.symbol, magic, positions);
      return(ModifyBasket(positions, sl, tp, report));
     }

   SymbolLimits Limits() { return(m_limits); }
  };

#endif // LMROBOT_EXECUTION_EXECUTOR_MQH
