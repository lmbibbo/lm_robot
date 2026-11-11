//+------------------------------------------------------------------+
//|                                                  TestRunner.mq5 |
//|                                     lm_robot test harness (MQL5)|
//+------------------------------------------------------------------+
#property copyright "lm_robot"
#property version   "1.00"
#property description "Runner minimo de aserciones para los modulos de lm_robot."

#include "../Include/LmRobot/Core/MarketContext.mqh"
#include "../Include/LmRobot/Core/BasketState.mqh"
#include "../Include/LmRobot/Core/Account.mqh"
#include "../Include/LmRobot/Core/Runtime.mqh"
#include "../Include/LmRobot/Execution/Executor.mqh"
#include "../Include/LmRobot/Risk/RiskPolicy.mqh"
#include "../Include/LmRobot/Risk/DailyLossGuard.mqh"
#include "../Include/LmRobot/Risk/SessionGuard.mqh"
#include "../Include/LmRobot/Strategies/Signal.mqh"
#include "../Include/LmRobot/Strategies/Scalper.mqh"
#include "../Include/LmRobot/Strategies/Fibonacci.mqh"
#include "../Include/LmRobot/Strategies/TrendMaster.mqh"
#include "../Include/LmRobot/Strategies/Strategy.mqh"
#include "../Include/LmRobot/UI/Dashboard.mqh"
#include "../Include/LmRobot/Harness/SignalCsv.mqh"

//--- Fuerza un fallo para verificar que el runner realmente falla.
input bool InjectFailure = false;

int g_passed = 0;
int g_failed = 0;

//+------------------------------------------------------------------+
//| Aserciones                                                       |
//+------------------------------------------------------------------+
void AssertTrue(bool condition, const string name)
  {
   if(condition)
     {
      g_passed++;
      PrintFormat("PASS  %s", name);
     }
   else
     {
      g_failed++;
      PrintFormat("FAIL  %s", name);
     }
  }

void AssertEqualInt(long actual, long expected, const string name)
  {
   if(actual == expected)
     {
      g_passed++;
      PrintFormat("PASS  %s", name);
     }
   else
     {
      g_failed++;
      PrintFormat("FAIL  %s (esperado=%I64d, actual=%I64d)", name, expected, actual);
     }
  }

void AssertEqualDouble(double actual, double expected, double tolerance, const string name)
  {
   if(MathAbs(actual - expected) <= tolerance)
     {
      g_passed++;
      PrintFormat("PASS  %s", name);
     }
   else
     {
      g_failed++;
      PrintFormat("FAIL  %s (esperado=%.10f, actual=%.10f, tolerancia=%.10f)",
                  name, expected, actual, tolerance);
     }
  }

//+------------------------------------------------------------------+
//| Instrumento sintetico de 5 digitos para pruebas.                 |
//+------------------------------------------------------------------+
InstrumentInfo MakeFiveDigitInstrument()
  {
   InstrumentInfo instrument;

   instrument.symbol         = "TEST5";
   instrument.digits         = 5;
   instrument.point          = 0.00001;
   instrument.pipSize        = LmPipSize(5, 0.00001);
   instrument.tickSize       = 0.00001;
   instrument.tickValue      = 1.0;
   instrument.pipValuePerLot = LmPipValuePerLot(1.0, 0.00001, instrument.pipSize);
   instrument.stopsLevel     = 20;
   instrument.freezeLevel    = 0;
   instrument.valid          = true;

   return(instrument);
  }

//+------------------------------------------------------------------+
//| Posicion sintetica para pruebas de la canasta.                   |
//+------------------------------------------------------------------+
BasketPosition MakeBasketPosition(const ulong ticket, const long magic, const string symbol,
                                  const ENUM_POSITION_TYPE type, const double volume,
                                  const double openPrice, const datetime openTime,
                                  const double profit = 0.0, const double swap = 0.0,
                                  const double commission = 0.0)
  {
   BasketPosition position;

   position.ticket     = ticket;
   position.magic      = magic;
   position.symbol     = symbol;
   position.type       = type;
   position.volume     = volume;
   position.openPrice  = openPrice;
   position.sl         = 0.0;
   position.tp         = 0.0;
   position.openTime   = openTime;
   position.profit     = profit;
   position.swap       = swap;
   position.commission = commission;

   return(position);
  }

//+------------------------------------------------------------------+
//| 3.1 Scan filtrado por simbolo y magic.                           |
//+------------------------------------------------------------------+
void TestBasketScanFiltering()
  {
   BasketPosition positions[4];
   positions[0] = MakeBasketPosition(1, 111, "TEST", POSITION_TYPE_BUY, 0.01, 1.1000,
                                     D'2026.01.02 10:00:00');
   positions[1] = MakeBasketPosition(2, 222, "TEST", POSITION_TYPE_BUY, 0.50, 1.2000,
                                     D'2026.01.02 10:01:00');
   positions[2] = MakeBasketPosition(3, 111, "OTHER", POSITION_TYPE_SELL, 0.50, 1.3000,
                                     D'2026.01.02 10:02:00');
   positions[3] = MakeBasketPosition(4, 111, "TEST", POSITION_TYPE_BUY, 0.02, 1.1010,
                                     D'2026.01.02 10:03:00');

   BasketState basket;
   AssertTrue(LmAggregateBasket("TEST", 111, positions, basket),
              "scan de canasta por simbolo y magic");
   AssertEqualInt(basket.count, 2, "scan ignora posiciones de otro magic y simbolo");
   AssertEqualDouble(basket.volume, 0.03, 1e-9, "scan suma solo el volumen propio");
   AssertEqualDouble(basket.averagePrice, 1.1006666667, 1e-9,
                     "scan ignora el promedio de posiciones ajenas");
   AssertEqualDouble(basket.lastOpenPrice, 1.1010, 1e-12,
                     "scan devuelve el precio de la ultima orden");
   AssertEqualInt((int)basket.direction, (int)BASKET_DIRECTION_BUY,
                  "scan devuelve la direccion de la canasta");
  }

//+------------------------------------------------------------------+
//| 3.2 Promedio ponderado y PnL con profit + swap + commission.     |
//+------------------------------------------------------------------+
void TestBasketAverageAndPnl()
  {
   BasketPosition positions[2];
   positions[0] = MakeBasketPosition(1, 111, "TEST", POSITION_TYPE_BUY, 0.01, 1.0000,
                                     D'2026.01.02 10:00:00', 1.5, 0.1, -0.3);
   positions[1] = MakeBasketPosition(2, 111, "TEST", POSITION_TYPE_BUY, 0.02, 1.0010,
                                     D'2026.01.02 10:05:00', -0.5, -0.2, -0.4);

   BasketState basket;
   LmAggregateBasket("TEST", 111, positions, basket);

   AssertEqualDouble(basket.averagePrice, 1.0006666667, 1e-9,
                     "promedio ponderado 0.01@1.0000 + 0.02@1.0010");
   AssertEqualDouble(NormalizeDouble(basket.averagePrice, 4), 1.0007, 1e-9,
                     "promedio ponderado redondeado a 4 digitos = 1.0007");
   AssertEqualDouble(basket.pnl, 0.2, 1e-9,
                     "PnL de canasta incluye profit + swap + commission");
  }

//+------------------------------------------------------------------+
//| 3.3 Ciclo de vida y reinicio del contador de pasos.              |
//+------------------------------------------------------------------+
void TestBasketLifecycle()
  {
   BasketPosition one[1];
   one[0] = MakeBasketPosition(1, 111, "TEST", POSITION_TYPE_BUY, 0.01, 1.1000,
                               D'2026.01.02 10:00:00');

   BasketPosition many[3];
   many[0] = one[0];
   many[1] = MakeBasketPosition(2, 111, "TEST", POSITION_TYPE_BUY, 0.02, 1.0990,
                                D'2026.01.02 10:05:00');
   many[2] = MakeBasketPosition(3, 111, "TEST", POSITION_TYPE_BUY, 0.03, 1.0980,
                                D'2026.01.02 10:10:00');

   BasketState emptyBasket;
   BasketPosition none[];
   LmAggregateBasket("TEST", 111, none, emptyBasket);

   BasketState basket;
   CBasketTracker tracker;

   AssertEqualInt((int)tracker.State(), (int)BASKET_LIFECYCLE_FLAT,
                  "la canasta inicia plana");
   AssertEqualInt(tracker.StepCount(), 0, "la canasta plana no tiene pasos");

   LmAggregateBasket("TEST", 111, one, basket);
   tracker.Update(basket);
   AssertEqualInt((int)tracker.State(), (int)BASKET_LIFECYCLE_OPEN,
                  "con una posicion la canasta queda abierta");
   AssertEqualInt(tracker.StepCount(), 0, "el primer lote no cuenta como paso");
   AssertTrue(!tracker.AllowsDirection(BASKET_DIRECTION_SELL),
              "canasta abierta no permite la direccion opuesta");

   LmAggregateBasket("TEST", 111, many, basket);
   tracker.Update(basket);
   AssertEqualInt(tracker.StepCount(), 2, "tres posiciones equivalen a dos pasos");
   AssertTrue(tracker.IsOpen(), "la canasta sigue abierta");

   tracker.Update(emptyBasket);
   AssertEqualInt((int)tracker.State(), (int)BASKET_LIFECYCLE_CLOSED,
                  "al cerrarse la canasta pasa a CLOSED");
   AssertEqualInt(tracker.StepCount(), 0,
                  "al cerrar toda la canasta el contador vuelve a cero");

   tracker.Update(emptyBasket);
   AssertEqualInt((int)tracker.State(), (int)BASKET_LIFECYCLE_FLAT,
                  "tras el tick de cierre la canasta queda plana");
   AssertTrue(tracker.CanOpenFirst(), "una canasta plana permite la primera orden");
  }

//+------------------------------------------------------------------+
//| 3.4 Deteccion del paso de grid por distancia en pips.            |
//+------------------------------------------------------------------+
void TestBasketGridStep()
  {
   double pipSize = 0.0001;

   BasketPosition buyPositions[1];
   buyPositions[0] = MakeBasketPosition(1, 111, "TEST", POSITION_TYPE_BUY, 0.01, 1.1000,
                                        D'2026.01.02 10:00:00');
   BasketState buyBasket;
   LmAggregateBasket("TEST", 111, buyPositions, buyBasket);

   AssertEqualDouble(LmGridDistancePips(buyBasket, 1.0978, pipSize), 22.0, 1e-9,
                     "compra que cae 22 pips");
   AssertTrue(LmGridStepReached(buyBasket, 1.0978, 22.0, pipSize),
              "compra que cae alcanza el paso de grid");
   AssertTrue(!LmGridStepReached(buyBasket, 1.0980, 22.0, pipSize),
              "compra que cae 20 pips no alcanza el paso");
   AssertTrue(!LmGridStepReached(buyBasket, 1.1020, 22.0, pipSize),
              "compra que sube no habilita el paso");

   BasketPosition sellPositions[1];
   sellPositions[0] = MakeBasketPosition(2, 111, "TEST", POSITION_TYPE_SELL, 0.01, 1.1000,
                                         D'2026.01.02 10:00:00');
   BasketState sellBasket;
   LmAggregateBasket("TEST", 111, sellPositions, sellBasket);

   AssertTrue(LmGridStepReached(sellBasket, 1.1022, 22.0, pipSize),
              "venta que sube alcanza el paso de grid");
   AssertTrue(!LmGridStepReached(sellBasket, 1.1020, 22.0, pipSize),
              "venta que sube 20 pips no alcanza el paso");
   AssertTrue(!LmGridStepReached(sellBasket, 1.0980, 22.0, pipSize),
              "venta que baja no habilita el paso");
  }

//+------------------------------------------------------------------+
//| Doble de prueba para el backend de ejecucion.                    |
//+------------------------------------------------------------------+
class CTestExecutionBackend : public IExecutionBackend
  {
private:
   bool    m_acceptSend;
   bool    m_acceptModify;
   int     m_sendCalls;
   int     m_modifyCalls;
   double  m_lastVolume;
   ulong   m_tickets[];
   double  m_sl[];
   double  m_tp[];

public:
   CTestExecutionBackend(const bool acceptSend = true, const bool acceptModify = true)
     {
      m_acceptSend   = acceptSend;
      m_acceptModify = acceptModify;
      m_sendCalls    = 0;
      m_modifyCalls  = 0;
      m_lastVolume   = 0.0;
     }

   virtual bool Send(const OrderRequest &request, int &retcode)
     {
      m_sendCalls++;
      m_lastVolume = request.volume;
      retcode = (m_acceptSend ? 10009 : 10004);
      return(m_acceptSend);
     }

   virtual bool Modify(const ulong ticket, const double sl, const double tp, int &retcode)
     {
      int index = ArraySize(m_tickets);
      ArrayResize(m_tickets, index + 1);
      ArrayResize(m_sl, index + 1);
      ArrayResize(m_tp, index + 1);

      m_tickets[index] = ticket;
      m_sl[index]      = sl;
      m_tp[index]      = tp;

      m_modifyCalls++;
      retcode = (m_acceptModify ? 10009 : 10004);
      return(m_acceptModify);
     }

   int    SendCalls()    { return(m_sendCalls); }
   int    ModifyCalls()  { return(m_modifyCalls); }
   double LastVolume()   { return(m_lastVolume); }
   ulong  TicketAt(const int index) { return(m_tickets[index]); }
   double SlAt(const int index)     { return(m_sl[index]); }
   double TpAt(const int index)     { return(m_tp[index]); }
  };

//+------------------------------------------------------------------+
//| Doble de prueba para el proveedor de margen.                     |
//+------------------------------------------------------------------+
class CTestAccountProvider : public IAccountInfoProvider
  {
private:
   double m_freeMargin;
   double m_requiredMargin;

public:
   CTestAccountProvider(const double freeMargin, const double requiredMargin)
     {
      m_freeMargin     = freeMargin;
      m_requiredMargin = requiredMargin;
     }

   virtual double FreeMargin()
     {
      return(m_freeMargin);
     }

   virtual bool CalcMargin(const ENUM_ORDER_TYPE type, const string symbol,
                           const double volume, const double price, double &margin)
     {
      margin = m_requiredMargin;
      return(true);
     }
  };

SymbolLimits MakeExecutionLimits()
  {
   SymbolLimits limits;

   limits.symbol            = "TEST";
   limits.point             = 0.0001;
   limits.volumeStep        = 0.01;
   limits.volumeMin         = 0.01;
   limits.volumeMax         = 1.0;
   limits.stopsLevelPoints  = 10.0;
   limits.freezeLevelPoints = 0.0;
   limits.valid             = true;

   return(limits);
  }

ExecutorConfig MakeExecutionConfig(const int maxAttempts = 3,
                                   const int retryDelayMs = 0,
                                   const int deadlineMs = 1000)
  {
   ExecutorConfig config;

   config.maxAttempts  = maxAttempts;
   config.retryDelayMs = retryDelayMs;
   config.deadlineMs   = deadlineMs;
   config.magic        = 111;

   return(config);
  }

OrderRequest MakeOrderRequest(const ENUM_ORDER_TYPE type, const double volume,
                              const double price, const double sl, const double tp = 0.0)
  {
   OrderRequest request;

   request.symbol  = "TEST";
   request.type    = type;
   request.volume  = volume;
   request.price   = price;
   request.sl      = sl;
   request.tp      = tp;
   request.comment = "test";

   return(request);
  }

//+------------------------------------------------------------------+
//| State compartido por el backend y la fuente de canasta.          |
//+------------------------------------------------------------------+
class CTestBrokerState
  {
public:
   BasketPosition m_positions[];
   ulong          m_nextTicket;
   long           m_magic;
   string         m_symbol;
   double         m_bid;
   double         m_ask;
   int            m_sendCalls;
   int            m_modifyCalls;
   datetime       m_openTime;

   CTestBrokerState()
     {
      m_nextTicket  = 1;
      m_magic       = 111;
      m_symbol      = "TEST5";
      m_bid         = 0.0;
      m_ask         = 0.0;
      m_sendCalls   = 0;
      m_modifyCalls = 0;
      m_openTime    = D'2026.01.02 10:00:00';
     }

   int Count() { return(ArraySize(m_positions)); }
   BasketPosition PositionAt(const int index) { return(m_positions[index]); }
   int SendCalls()   { return(m_sendCalls); }
   int ModifyCalls() { return(m_modifyCalls); }

   void RemoveAt(const int index)
     {
      int total = ArraySize(m_positions);

      for(int i = index; i < total - 1; i++)
         m_positions[i] = m_positions[i + 1];

      ArrayResize(m_positions, total - 1);
     }

   void CloseHits()
     {
      for(int i = ArraySize(m_positions) - 1; i >= 0; i--)
        {
         bool closed = false;

         if(m_positions[i].type == POSITION_TYPE_BUY)
           {
            if(m_positions[i].sl > 0.0 && m_bid <= m_positions[i].sl)
               closed = true;

            if(m_positions[i].tp > 0.0 && m_bid >= m_positions[i].tp)
               closed = true;
           }
         else
           {
            if(m_positions[i].sl > 0.0 && m_ask >= m_positions[i].sl)
               closed = true;

            if(m_positions[i].tp > 0.0 && m_ask <= m_positions[i].tp)
               closed = true;
           }

         if(closed)
            RemoveAt(i);
        }
     }

   void SetQuote(const double bid, const double ask)
     {
      m_bid = bid;
      m_ask = ask;
      CloseHits();
     }

   void ClearProtection()
     {
      for(int i = 0; i < ArraySize(m_positions); i++)
        {
         m_positions[i].sl = 0.0;
         m_positions[i].tp = 0.0;
        }
     }

   bool Send(const OrderRequest &request, int &retcode)
     {
      int index = ArraySize(m_positions);
      ArrayResize(m_positions, index + 1);

      m_positions[index].ticket     = m_nextTicket++;
      m_positions[index].magic      = (request.magic > 0 ? request.magic : m_magic);
      m_positions[index].symbol     = request.symbol;
      m_positions[index].type       = (request.type == ORDER_TYPE_BUY
                                       ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
      m_positions[index].volume     = request.volume;
      m_positions[index].openPrice  = request.price;
      m_positions[index].sl         = request.sl;
      m_positions[index].tp         = request.tp;
      m_positions[index].openTime   = m_openTime + (datetime)(index * 60);
      m_positions[index].profit     = 0.0;
      m_positions[index].swap       = 0.0;
      m_positions[index].commission = 0.0;

      m_sendCalls++;
      retcode = 10009;
      return(true);
     }

   bool Modify(const ulong ticket, const double sl, const double tp, int &retcode)
     {
      for(int i = 0; i < ArraySize(m_positions); i++)
        {
         if(m_positions[i].ticket == ticket)
           {
            m_positions[i].sl = sl;
            m_positions[i].tp = tp;
            m_modifyCalls++;
            retcode = 10009;
            return(true);
           }
        }

      retcode = 10004;
      return(false);
     }
  };

//+------------------------------------------------------------------+
//| Backend simulado que crea y modifica posiciones en memoria.      |
//+------------------------------------------------------------------+
class CTestBrokerBackend : public IExecutionBackend
  {
private:
   CTestBrokerState *m_state;

public:
   CTestBrokerBackend(CTestBrokerState *state)
     {
      m_state = state;
     }

   virtual bool Send(const OrderRequest &request, int &retcode)
     {
      return(m_state.Send(request, retcode));
     }

   virtual bool Modify(const ulong ticket, const double sl, const double tp, int &retcode)
     {
      return(m_state.Modify(ticket, sl, tp, retcode));
     }
  };

//+------------------------------------------------------------------+
//| Fuente de canasta sobre el broker simulado.                      |
//+------------------------------------------------------------------+
class CTestBrokerBasketSource : public ILmBasketSource
  {
private:
   CTestBrokerState *m_state;

public:
   CTestBrokerBasketSource(CTestBrokerState *state)
     {
      m_state = state;
     }

   virtual bool Scan(const long magic, BasketState &basket)
     {
      return(LmAggregateBasket(m_state.m_symbol, magic, m_state.m_positions, basket));
     }

   virtual int Positions(const long magic, BasketPosition &positions[])
     {
      ArrayResize(positions, 0);
      int used = 0;

      for(int i = 0; i < ArraySize(m_state.m_positions); i++)
        {
         if(m_state.m_positions[i].magic != magic ||
            m_state.m_positions[i].symbol != m_state.m_symbol)
            continue;

         ArrayResize(positions, used + 1);
         positions[used] = m_state.m_positions[i];
         used++;
        }

      return(used);
     }
  };

//+------------------------------------------------------------------+
//| Barras cerradas inyectadas para el runtime.                      |
//+------------------------------------------------------------------+
class CTestBarSource : public ILmBarSource
  {
private:
   datetime m_barTime;
   double   m_close1;
   double   m_close2;
   double   m_high1;
   double   m_low2;
   double   m_rsi;
   bool     m_hasRsi;

public:
   CTestBarSource()
     {
      m_barTime = 0;
      m_close1  = 0.0;
      m_close2  = 0.0;
      m_high1   = 0.0;
      m_low2    = 0.0;
      m_rsi     = 50.0;
      m_hasRsi  = false;
     }

   void Set(const datetime barTime, const double close1, const double close2)
     {
      m_barTime = barTime;
      m_close1  = close1;
      m_close2  = close2;
      m_high1   = MathMax(close1, close2);
      m_low2    = MathMin(close1, close2);
      m_hasRsi  = false;
      m_rsi     = 50.0;
     }

   void SetRsi(const double rsi)
     {
      m_rsi    = rsi;
      m_hasRsi = true;
     }

   virtual bool BarTime(datetime &barTime)
     {
      barTime = m_barTime;
      return(m_barTime > 0);
     }

   virtual bool Close(const int shift, double &value)
     {
      if(shift == 1)
        {
         value = m_close1;
         return(true);
        }

      if(shift == 2)
        {
         value = m_close2;
         return(true);
        }

      value = 0.0;
      return(false);
     }

   virtual bool High(const int shift, double &value)
     {
      if(shift == 1)
        {
         value = m_high1;
         return(true);
        }

      value = 0.0;
      return(false);
     }

   virtual bool Low(const int shift, double &value)
     {
      if(shift == 2)
        {
         value = m_low2;
         return(true);
        }

      value = 0.0;
      return(false);
     }

   virtual bool Rsi(const int shift, double &value)
     {
      value = m_rsi;
      return(m_hasRsi);
     }
  };

//+------------------------------------------------------------------+
//| Limites y configuracion del runtime para las pruebas.            |
//+------------------------------------------------------------------+
SymbolLimits MakeRuntimeLimits()
  {
   SymbolLimits limits;

   limits.symbol            = "TEST5";
   limits.point             = 0.00001;
   limits.volumeStep        = 0.01;
   limits.volumeMin         = 0.01;
   limits.volumeMax         = 100.0;
   limits.stopsLevelPoints  = 20.0;
   limits.freezeLevelPoints = 0.0;
   limits.valid             = true;

   return(limits);
  }

RuntimeConfig MakeRuntimeConfig()
  {
   RuntimeConfig config;

   config.magic    = 111;
   config.strategy = LM_STRATEGY_SCALPER_PRO;
   config.risk     = LmDefaultRiskConfig();
   config.risk.riskMode = LM_RISK_MANUAL;
   config.session  = LmDefaultSessionConfig();

   return(config);
  }

//+------------------------------------------------------------------+
//| 4.1 Normalizacion del volumen al step, minimo y maximo.          |
//+------------------------------------------------------------------+
void TestExecutorVolumeNormalization()
  {
   AssertEqualDouble(LmNormalizeVolume(0.017, 0.01, 0.01, 1.0), 0.02, 1e-9,
                     "volumen 0.017 se ajusta al multiplo mas cercano 0.02");
   AssertEqualDouble(LmNormalizeVolume(0.013, 0.01, 0.01, 1.0), 0.01, 1e-9,
                     "volumen 0.013 se ajusta al multiplo mas cercano 0.01");
   AssertEqualDouble(LmNormalizeVolume(0.001, 0.01, 0.01, 1.0), 0.01, 1e-9,
                     "volumen debajo del minimo se acota al minimo");
   AssertEqualDouble(LmNormalizeVolume(2.0, 0.01, 0.01, 1.0), 1.0, 1e-9,
                     "volumen encima del maximo se acota al maximo");
   AssertEqualDouble(LmNormalizeVolume(0.26, 0.1, 0.1, 0.25), 0.2, 1e-9,
                     "el maximo se ajusta al multiplo valido inferior");
   AssertEqualDouble(LmNormalizeVolume(0.02, 0.0, 0.01, 1.0), 0.0, 1e-9,
                     "step invalido devuelve cero");

   SymbolLimits limits = MakeExecutionLimits();
   CTestExecutionBackend backend;
   CTestAccountProvider accounts(1000.0, 10.0);
   CExecutor executor;
   AssertTrue(executor.Init(&backend, &accounts, limits, MakeExecutionConfig()),
              "executor inicializado para normalizacion");

   OrderRequest request = MakeOrderRequest(ORDER_TYPE_BUY, 0.017, 1.1000, 1.0990);
   ExecutionReport report;
   AssertEqualInt((int)executor.Send(request, report), (int)EXECUTION_STATUS_OK,
                  "orden con volumen no multiple se envia normalizada");
   AssertEqualDouble(report.normalizedVolume, 0.02, 1e-9,
                     "el reporte expone el volumen normalizado");
   AssertEqualDouble(backend.LastVolume(), 0.02, 1e-9,
                     "el backend recibe el volumen normalizado");
  }

//+------------------------------------------------------------------+
//| 4.2 Rechazo de ordenes sin SL o con SL dentro del stops level.   |
//+------------------------------------------------------------------+
void TestExecutorStopLossValidation()
  {
   string reason = "";

   AssertTrue(LmValidateStopLoss(ORDER_TYPE_BUY, 1.1000, 1.0990, 10.0, 0.0001, reason),
              "SL de compra a 10 puntos es valido");
   AssertTrue(!LmValidateStopLoss(ORDER_TYPE_BUY, 1.1000, 0.0, 10.0, 0.0001, reason),
              "compra sin SL se rechaza");
   AssertTrue(reason != "", "el rechazo sin SL registra el motivo");
   AssertTrue(!LmValidateStopLoss(ORDER_TYPE_BUY, 1.1000, 1.0995, 10.0, 0.0001, reason),
              "SL de compra dentro del stops level se rechaza");
   AssertTrue(reason != "", "el rechazo por stops level registra el motivo");
   AssertTrue(LmValidateStopLoss(ORDER_TYPE_SELL, 1.1000, 1.1010, 10.0, 0.0001, reason),
              "SL de venta a 10 puntos es valido");
   AssertTrue(!LmValidateStopLoss(ORDER_TYPE_SELL, 1.1000, 1.1005, 10.0, 0.0001, reason),
              "SL de venta dentro del stops level se rechaza");

   SymbolLimits limits = MakeExecutionLimits();
   CTestExecutionBackend backend;
   CTestAccountProvider accounts(1000.0, 10.0);
   CExecutor executor;
   executor.Init(&backend, &accounts, limits, MakeExecutionConfig());

   OrderRequest noStop = MakeOrderRequest(ORDER_TYPE_BUY, 0.01, 1.1000, 0.0);
   ExecutionReport report;
   AssertEqualInt((int)executor.Send(noStop, report), (int)EXECUTION_STATUS_INVALID_STOP,
                  "el executor rechaza la orden sin stop loss");
   AssertEqualInt(backend.SendCalls(), 0, "la orden sin stop loss no se envia");
   AssertTrue(report.reason != "", "el executor registra el motivo del rechazo");

   OrderRequest tightStop = MakeOrderRequest(ORDER_TYPE_BUY, 0.01, 1.1000, 1.0995);
   AssertEqualInt((int)executor.Send(tightStop, report), (int)EXECUTION_STATUS_INVALID_STOP,
                  "el executor rechaza el stop dentro del stops level");
   AssertEqualInt(backend.SendCalls(), 0, "la orden con stop invalido no se envia");
  }

//+------------------------------------------------------------------+
//| 4.3 Reintentos acotados por cantidad y por deadline.             |
//+------------------------------------------------------------------+
void TestExecutorRetryLimits()
  {
   SymbolLimits limits = MakeExecutionLimits();
   CTestAccountProvider accounts(1000.0, 10.0);
   OrderRequest request = MakeOrderRequest(ORDER_TYPE_BUY, 0.01, 1.1000, 1.0990);
   ExecutionReport report;

   CTestExecutionBackend alwaysRejects(false, true);
   CExecutor executor;
   executor.Init(&alwaysRejects, &accounts, limits, MakeExecutionConfig(3, 0, 1000));
   AssertEqualInt((int)executor.Send(request, report), (int)EXECUTION_STATUS_RETRY_EXHAUSTED,
                  "un backend que rechaza siempre agota los reintentos");
   AssertEqualInt(report.attempts, 3, "el executor respeta el maximo de intentos");
   AssertEqualInt(alwaysRejects.SendCalls(), 3, "el backend recibe exactamente tres intentos");

   CTestExecutionBackend deadlineRejects(false, true);
   CExecutor deadlineExecutor;
   deadlineExecutor.Init(&deadlineRejects, &accounts, limits, MakeExecutionConfig(100, 10, 1));
   AssertEqualInt((int)deadlineExecutor.Send(request, report),
                  (int)EXECUTION_STATUS_RETRY_EXHAUSTED,
                  "un deadline vencido corta los reintentos");
   AssertTrue(report.attempts < 100, "el deadline limita los intentos antes del maximo");
   AssertTrue(deadlineRejects.SendCalls() < 100, "el backend no recibe los cien intentos");
  }

//+------------------------------------------------------------------+
//| 4.4 Modificacion de SL y TP de toda la canasta.                  |
//+------------------------------------------------------------------+
void TestExecutorBasketProtection()
  {
   BasketPosition positions[3];
   positions[0] = MakeBasketPosition(1, 111, "TEST", POSITION_TYPE_BUY, 0.01, 1.1000,
                                     D'2026.01.02 10:00:00');
   positions[1] = MakeBasketPosition(2, 111, "TEST", POSITION_TYPE_BUY, 0.02, 1.0990,
                                     D'2026.01.02 10:05:00');
   positions[2] = MakeBasketPosition(3, 111, "TEST", POSITION_TYPE_BUY, 0.03, 1.0980,
                                     D'2026.01.02 10:10:00');

   SymbolLimits limits = MakeExecutionLimits();
   CTestExecutionBackend backend(true, true);
   CTestAccountProvider accounts(1000.0, 10.0);
   CExecutor executor;
   executor.Init(&backend, &accounts, limits, MakeExecutionConfig());

   ExecutionReport report;
   AssertEqualInt((int)executor.ModifyBasket(positions, 1.0900, 1.1100, report),
                  (int)EXECUTION_STATUS_OK,
                  "la proteccion de la canasta se aplica a todas las posiciones");
   AssertEqualInt(report.modifiedCount, 3, "se modifican las tres posiciones");
   AssertEqualInt(backend.ModifyCalls(), 3, "el backend recibe una modificacion por posicion");

   for(int i = 0; i < 3; i++)
     {
      AssertEqualInt((int)backend.TicketAt(i), i + 1,
                     StringFormat("posicion %d modificada por ticket", i + 1));
      AssertEqualDouble(backend.SlAt(i), 1.0900, 1e-12,
                        StringFormat("posicion %d comparte el SL", i + 1));
      AssertEqualDouble(backend.TpAt(i), 1.1100, 1e-12,
                        StringFormat("posicion %d comparte el TP", i + 1));
     }
  }

//+------------------------------------------------------------------+
//| 4.5 Verificacion de margen libre antes de enviar.                |
//+------------------------------------------------------------------+
void TestExecutorMarginCheck()
  {
   AssertTrue(LmHasEnoughMargin(10.0, 10.0), "margen libre igual al requerido alcanza");
   AssertTrue(LmHasEnoughMargin(5.0, 10.0), "margen libre mayor al requerido alcanza");
   AssertTrue(!LmHasEnoughMargin(10.0, 5.0), "margen libre insuficiente se detecta");

   SymbolLimits limits = MakeExecutionLimits();
   OrderRequest request = MakeOrderRequest(ORDER_TYPE_BUY, 0.01, 1.1000, 1.0990);
   ExecutionReport report;

   CTestExecutionBackend noMarginBackend;
   CTestAccountProvider noMargin(5.0, 10.0);
   CExecutor noMarginExecutor;
   noMarginExecutor.Init(&noMarginBackend, &noMargin, limits, MakeExecutionConfig());
   AssertEqualInt((int)noMarginExecutor.Send(request, report),
                  (int)EXECUTION_STATUS_NO_MARGIN,
                  "la orden sin margen se rechaza");
   AssertEqualInt(noMarginBackend.SendCalls(), 0,
                  "la canasta no se altera cuando falta margen");
   AssertTrue(report.reason != "", "el rechazo por margen registra el motivo");

   CTestExecutionBackend fundedBackend;
   CTestAccountProvider funded(1000.0, 10.0);
   CExecutor fundedExecutor;
   fundedExecutor.Init(&fundedBackend, &funded, limits, MakeExecutionConfig());
   AssertEqualInt((int)fundedExecutor.Send(request, report), (int)EXECUTION_STATUS_OK,
                  "la orden con margen suficiente se envia");
   AssertEqualInt(fundedBackend.SendCalls(), 1, "el backend recibe la orden con margen");
  }

//+------------------------------------------------------------------+
//| 5.1 Lote inicial por riesgo y clamp al broker.                   |
//+------------------------------------------------------------------+
void TestRiskInitialLot()
  {
   AssertEqualDouble(LmInitialLot(10000.0, 0.5, 40.0, 10.0, 0.01, 0.01, 100.0),
                     0.12, 1e-9,
                     "lote inicial 10000, 0.5%, 40 pips y 10 por pip = 0.12");
   AssertEqualDouble(LmInitialLot(100.0, 0.5, 40.0, 10.0, 0.01, 0.01, 100.0),
                     0.01, 1e-9,
                     "un lote debajo del minimo se eleva al minimo del broker");
   AssertEqualDouble(LmInitialLot(1000000.0, 0.5, 40.0, 10.0, 0.01, 0.01, 0.20),
                     0.20, 1e-9,
                     "un lote encima del maximo se acota al maximo del broker");
   AssertEqualDouble(LmInitialLot(10000.0, 0.5, 0.0, 10.0, 0.01, 0.01, 100.0),
                     0.0, 1e-9,
                     "un stop loss cero no produce lote");

   RiskConfig config = LmDefaultRiskConfig();
   config.maxLotPerOrder        = 1.0;
   config.maxVolumePerStrategy  = 1.0;

   RiskStepPlan plan;
   AssertTrue(LmPlanInitialOrder(config, 10000.0, 10.0, 0.01, 0.01, 100.0, plan),
              "la primera orden cabe en el presupuesto de canasta");
   AssertEqualDouble(plan.volume, 0.12, 1e-9,
                     "la primera orden usa el lote calculado por riesgo");
   AssertEqualInt((int)plan.decision, (int)RISK_DECISION_OPEN_FIRST,
                  "la primera orden se marca como apertura");

   RiskConfig tiny = LmDefaultRiskConfig();
   AssertTrue(!LmPlanInitialOrder(tiny, 100.0, 10.0, 0.01, 0.01, 100.0, plan),
              "el minimo del broker que excede el presupuesto rechaza la apertura");
   AssertEqualInt((int)plan.decision, (int)RISK_DECISION_REJECT,
                  "la apertura rechazada no se envia");
   AssertTrue(plan.reason != "", "el rechazo de apertura registra el motivo");
  }

//+------------------------------------------------------------------+
//| 5.2 Perdida proyectada y rechazo del paso de grid.               |
//+------------------------------------------------------------------+
void TestRiskProjectedLoss()
  {
   AssertEqualDouble(LmProjectedLoss(0.30, 40.0, 10.0), 120.0, 1e-9,
                     "perdida proyectada de 0.30 lotes a 40 pips");
   AssertEqualDouble(LmBasketLossBudget(10000.0, 2.0), 200.0, 1e-9,
                     "presupuesto del 2% sobre 10000");
   AssertTrue(LmFitsBasketBudget(200.0, 10000.0, 2.0),
              "una perdida igual al presupuesto cabe");
   AssertTrue(!LmFitsBasketBudget(200.01, 10000.0, 2.0),
              "una perdida encima del presupuesto no cabe");

   RiskConfig config = LmDefaultRiskConfig();
   config.maxLotPerOrder       = 10.0;
   config.maxVolumePerStrategy = 10.0;
   config.maxGridSteps         = 10;

   RiskStepPlan plan;
   AssertTrue(LmPlanGridOrder(config, 10000.0, 10.0, 0.30, 1, 0.10,
                              0.01, 0.01, 100.0, plan),
              "un paso dentro del presupuesto se acepta");
   AssertEqualDouble(plan.volume, 0.10, 1e-9,
                     "el paso aceptado conserva su volumen");
   AssertEqualDouble(plan.projectedLoss, 160.0, 1e-9,
                     "la perdida proyectada suma el volumen existente");
   AssertEqualInt((int)plan.decision, (int)RISK_DECISION_OPEN_GRID,
                  "el paso aceptado se marca como grid");

   AssertTrue(!LmPlanGridOrder(config, 10000.0, 10.0, 0.45, 1, 0.10,
                               0.01, 0.01, 100.0, plan),
              "un paso que excede el 2% del balance se rechaza");
   AssertEqualInt((int)plan.decision, (int)RISK_DECISION_REJECT,
                  "el paso rechazado no se envia");
   AssertEqualDouble(plan.volume, 0.0, 1e-9,
                     "el paso rechazado no expone volumen");
   AssertTrue(plan.reason != "", "el rechazo por presupuesto registra el motivo");
  }

//+------------------------------------------------------------------+
//| 5.3 Topes independientes de volumen por orden, canasta y pasos.  |
//+------------------------------------------------------------------+
void TestRiskVolumeAndStepCaps()
  {
   AssertEqualDouble(LmCapVolumePerOrder(0.50, 0.10), 0.10, 1e-9,
                     "el tope por orden recorta el volumen");
   AssertEqualDouble(LmCapVolumePerOrder(0.05, 0.10), 0.05, 1e-9,
                     "un volumen debajo del tope por orden no se altera");
   AssertEqualDouble(LmCapVolumePerBasket(0.20, 0.25, 0.30), 0.05, 1e-9,
                     "el tope por canasta usa solo el remanente");
   AssertEqualDouble(LmCapVolumePerBasket(0.10, 0.30, 0.30), 0.0, 1e-9,
                     "una canasta llena no admite mas volumen");
   AssertTrue(LmMaxStepsReached(4, 4), "el tope de pasos se alcanza en el maximo");
   AssertTrue(!LmMaxStepsReached(3, 4), "un paso debajo del maximo sigue habilitado");
   AssertEqualDouble(LmGridLot(0.02, 1.5, 2), 0.045, 1e-9,
                     "lote del paso 2 con multiplicador 1.5");

   RiskConfig config = LmDefaultRiskConfig();
   config.maxBasketLossPct     = 100.0;
   config.maxVolumePerStrategy = 10.0;
   config.maxGridSteps         = 10;

   RiskStepPlan plan;
   config.maxLotPerOrder = 0.10;
   AssertTrue(LmPlanGridOrder(config, 10000.0, 10.0, 0.0, 1, 0.50,
                              0.01, 0.01, 100.0, plan),
              "el paso se acepta tras aplicar el tope por orden");
   AssertEqualDouble(plan.volume, 0.10, 1e-9,
                     "el tope por orden limita el paso de grid");

   config.maxLotPerOrder       = 10.0;
   config.maxVolumePerStrategy = 0.30;
   AssertTrue(LmPlanGridOrder(config, 10000.0, 10.0, 0.25, 2, 0.20,
                              0.01, 0.01, 100.0, plan),
              "el paso se acepta tras aplicar el tope por canasta");
   AssertEqualDouble(plan.volume, 0.05, 1e-9,
                     "el tope por canasta limita el paso de grid");

   config.maxVolumePerStrategy = 10.0;
   config.maxGridSteps         = 4;
   AssertTrue(!LmPlanGridOrder(config, 10000.0, 10.0, 0.20, 4, 0.10,
                               0.01, 0.01, 100.0, plan),
              "con el tope de pasos alcanzado no se planifica otro paso");
   AssertEqualInt((int)plan.decision, (int)RISK_DECISION_REJECT,
                  "el tope de pasos rechaza el paso");
  }

//+------------------------------------------------------------------+
//| 5.3b Lote y SL proporcionales al ATR y factor de volatilidad.    |
//+------------------------------------------------------------------+
void TestRiskVolatilityScaling()
  {
   RiskConfig config = LmDefaultRiskConfig();
   config.slPips       = 40.0;
   config.atrSlMultiplier = 1.667;

   //--- SL derivado del ATR: SlPips actua como piso.
   AssertEqualDouble(LmEffectiveSlPips(config, 0.0), 40.0, 1e-9,
                     "sin ATR el SL queda en SlPips");
   AssertEqualDouble(LmEffectiveSlPips(config, 10.0), 40.0, 1e-9,
                     "un ATR bajo no reduce el SL por debajo del piso");
   AssertEqualDouble(LmEffectiveSlPips(config, 60.0), 100.02, 1e-9,
                     "un ATR alto amplia el SL de forma proporcional");

   RiskConfig wide = config;
   wide.slPips = 1000.0;
   AssertEqualDouble(LmEffectiveSlPips(wide, 60.0), 1000.0, 1e-9,
                     "el piso configurado domina al ATR");

   //--- Factor de volatilidad relativa, acotado.
   AssertEqualDouble(LmVolatilityFactor(10.0, 10.0, 0.3, 2.0), 1.0, 1e-9,
                     "volatilidad igual a la media no ajusta el lote");
   AssertEqualDouble(LmVolatilityFactor(10.0, 20.0, 0.3, 2.0), 2.0, 1e-9,
                     "volatilidad baja sube el lote hasta el tope");
   AssertEqualDouble(LmVolatilityFactor(40.0, 10.0, 0.3, 2.0), 0.3, 1e-9,
                     "volatilidad alta reduce el lote hasta el piso");
   AssertEqualDouble(LmVolatilityFactor(10.0, 5.0, 0.3, 2.0), 0.5, 1e-9,
                     "el factor es la razon media/actual");
   AssertEqualDouble(LmVolatilityFactor(0.0, 20.0, 0.3, 2.0), 1.0, 1e-9,
                     "sin ATR actual no hay ajuste");

   //--- Lote proporcional al balance, al riesgo y al factor.
   AssertEqualDouble(LmInitialLot(10000.0, 0.5, 40.0, 10.0, 0.01, 0.01, 100.0, 0.5),
                     0.06, 1e-9,
                     "el factor de volatilidad escala el lote");
   AssertEqualDouble(LmInitialLot(20000.0, 0.5, 40.0, 10.0, 0.01, 0.01, 100.0),
                     0.24, 1e-9,
                     "el lote es proporcional al balance");
   AssertEqualDouble(LmInitialLot(10000.0, 1.0, 40.0, 10.0, 0.01, 0.01, 100.0),
                     0.25, 1e-9,
                     "el lote es proporcional al riesgo");

   //--- La planificacion usa el mismo SL por ATR y aplica el factor.
   config.maxLotPerOrder       = 1.0;
   config.maxVolumePerStrategy = 1.0;

   RiskStepPlan plan;
   AssertTrue(LmPlanInitialOrder(config, 10000.0, 10.0, 0.01, 0.01, 100.0,
                                 plan, 30.0, 45.0),
              "la apertura con ATR cabe en el presupuesto");
   AssertEqualDouble(plan.slPips, 50.01, 1e-9,
                     "la apertura usa el SL derivado del ATR");
   AssertEqualDouble(plan.volume, 0.14, 1e-9,
                     "la apertura aplica SL por ATR y factor de volatilidad");
   AssertEqualDouble(plan.projectedLoss, 70.014, 1e-9,
                     "la perdida proyectada usa el SL por ATR");

   //--- El paso de grid valida el presupuesto con el SL por ATR.
   config.maxBasketLossPct = 2.0;
   AssertTrue(LmPlanGridOrder(config, 10000.0, 10.0, 0.20, 1, 0.10,
                              0.01, 0.01, 100.0, plan, 30.0),
              "el paso con ATR dentro del presupuesto se acepta");
   AssertEqualDouble(plan.slPips, 50.01, 1e-9,
                     "el paso usa el SL derivado del ATR");
   AssertTrue(!LmPlanGridOrder(config, 10000.0, 10.0, 0.20, 1, 0.10,
                               0.01, 0.01, 100.0, plan, 120.0),
              "un ATR alto reduce el SL permitido y rechaza el paso");
  }

//+------------------------------------------------------------------+
//| Store en memoria que simula el reinicio del terminal.            |
//+------------------------------------------------------------------+
class CTestDailyStore : public IDailyStateStore
  {
private:
   string m_keys[];
   double m_values[];

public:
   virtual bool Load(const string key, double &value)
     {
      for(int i = 0; i < ArraySize(m_keys); i++)
        {
         if(m_keys[i] == key)
           {
            value = m_values[i];
            return(true);
           }
        }

      value = 0.0;
      return(false);
     }

   virtual bool Save(const string key, const double value)
     {
      for(int i = 0; i < ArraySize(m_keys); i++)
        {
         if(m_keys[i] == key)
           {
            m_values[i] = value;
            return(true);
           }
        }

      int index = ArraySize(m_keys);
      ArrayResize(m_keys, index + 1);
      ArrayResize(m_values, index + 1);

      m_keys[index]   = key;
      m_values[index] = value;
      return(true);
     }
  };

//+------------------------------------------------------------------+
//| 5.4 Limite diario persistente por cuenta y dia del servidor.     |
//+------------------------------------------------------------------+
void TestDailyLossGuard()
  {
   CTestDailyStore store;
   CDailyLossGuard guard;
   AssertTrue(guard.Init(&store, 123456, 4.0), "la guarda diaria se inicializa");

   DailyLossState state;
   datetime day1 = D'2026.03.10 08:00:00';

   AssertTrue(guard.Evaluate(day1, 10000.0, state),
              "la primera evaluacion del dia registra la equidad");
   AssertEqualDouble(state.startEquity, 10000.0, 1e-9,
                     "la equidad de inicio del dia queda guardada");
   AssertTrue(!state.blocked, "sin caida no se bloquean las aperturas");

   AssertTrue(guard.Evaluate(day1, 9601.0, state), "evaluacion con caida pequena");
   AssertTrue(!state.blocked, "una caida debajo del 4% no bloquea");

   AssertTrue(guard.Evaluate(day1, 9590.0, state), "evaluacion con caida sobre el limite");
   AssertTrue(state.blocked, "una caida superior al 4% bloquea las aperturas");
   AssertTrue(guard.IsBlocked(), "la guarda conserva el bloqueo");

   //--- Reinicio simulado: misma persistencia, nueva instancia.
   CDailyLossGuard restarted;
   AssertTrue(restarted.Init(&store, 123456, 4.0), "la guarda diaria se reinicia");
   AssertTrue(restarted.Evaluate(day1, 10000.0, state),
              "tras el reinicio la equidad se recupera");
   AssertTrue(state.blocked,
              "el bloqueo diario sobrevive al reinicio aunque la equidad se recupere");
   AssertEqualDouble(state.startEquity, 10000.0, 1e-9,
                     "la equidad de inicio sobrevive al reinicio");

   //--- Nuevo dia del servidor: se habilita una nueva referencia.
   AssertTrue(restarted.Evaluate(D'2026.03.11 00:01:00', 10000.0, state),
              "la evaluacion del dia siguiente funciona");
   AssertTrue(!state.blocked, "el dia siguiente vuelve a habilitar aperturas");
   AssertEqualDouble(state.startEquity, 10000.0, 1e-9,
                     "el dia siguiente registra su propia equidad de inicio");

   //--- Otra cuenta no hereda el estado de la primera.
   CDailyLossGuard other;
   AssertTrue(other.Init(&store, 999999, 4.0), "la guarda de otra cuenta se inicializa");
   AssertTrue(other.Evaluate(day1, 9590.0, state), "la otra cuenta se evalua");
   AssertTrue(!state.blocked, "el bloqueo no se comparte entre cuentas");

   //--- Claves y formulas auxiliares.
   AssertTrue(LmDailyStartKey(123456, day1) !=
              LmDailyStartKey(123456, D'2026.03.11 00:01:00'),
              "la clave de inicio cambia con el dia del servidor");
   AssertTrue(LmDailyStartKey(123456, day1) != LmDailyStartKey(999999, day1),
              "la clave de inicio cambia con la cuenta");
   AssertEqualDouble(LmDailyDropPct(10000.0, 9600.0), 4.0, 1e-9,
                     "la caida porcentual diaria se calcula sobre la equidad inicial");
   AssertTrue(LmDailyLimitReached(4.0, 4.0), "el limite se alcanza en el umbral");
  }

//+------------------------------------------------------------------+
//| 5.5 La gestion tiene prioridad sobre las aperturas.              |
//+------------------------------------------------------------------+
void TestRiskManagementPriority()
  {
   AssertTrue(LmCanManagePositions(true),
              "la gestion se permite con el limite diario activo");
   AssertTrue(LmCanManagePositions(false),
              "la gestion se permite sin el limite diario");

   AssertTrue(!LmCanOpenNew(true, false, false, true),
              "el limite diario bloquea solo las aperturas");
   AssertTrue(!LmCanOpenNew(false, true, false, true),
              "el spread maximo bloquea las aperturas");
   AssertTrue(!LmCanOpenNew(false, false, true, true),
              "la volatilidad alta bloquea las aperturas");
   AssertTrue(!LmCanOpenNew(false, false, false, false),
              "la sesion cerrada bloquea las aperturas");
   AssertTrue(LmCanOpenNew(false, false, false, true),
              "sin guards activos se permiten aperturas");

   BasketPosition positions[2];
   positions[0] = MakeBasketPosition(1, 111, "TEST", POSITION_TYPE_BUY, 0.01, 1.1000,
                                     D'2026.01.02 10:00:00');
   positions[1] = MakeBasketPosition(2, 111, "TEST", POSITION_TYPE_BUY, 0.02, 1.0990,
                                     D'2026.01.02 10:05:00');

   SymbolLimits limits = MakeExecutionLimits();
   CTestExecutionBackend backend(true, true);
   CTestAccountProvider accounts(1000.0, 10.0);
   CExecutor executor;
   executor.Init(&backend, &accounts, limits, MakeExecutionConfig());

   ExecutionReport report;
   AssertEqualInt((int)executor.ModifyBasket(positions, 1.0900, 1.1100, report),
                  (int)EXECUTION_STATUS_OK,
                  "la proteccion por SL se aplica igual con el limite diario activo");
   AssertEqualInt(report.modifiedCount, 2,
                  "la gestion alcanza toda la canasta aunque las aperturas esten bloqueadas");
  }

//+------------------------------------------------------------------+
//| 6.4 Senal pura de Scalper Pro y determinismo.                    |
//+------------------------------------------------------------------+
void TestScalperSignal()
  {
   AssertEqualInt((int)LmScalperSignal(1.1000, 1.0990), (int)SIGNAL_SELL,
                  "close[2] > close[1] devuelve SELL");
   AssertEqualInt((int)LmScalperSignal(1.0990, 1.1000), (int)SIGNAL_BUY,
                  "close[2] < close[1] devuelve BUY");
   AssertEqualInt((int)LmScalperSignal(1.1000, 1.1000), (int)SIGNAL_BUY,
                  "close[2] == close[1] devuelve BUY");

   ENUM_SIGNAL_DIRECTION first  = LmScalperSignal(1.1000, 1.0990);
   ENUM_SIGNAL_DIRECTION second = LmScalperSignal(1.1000, 1.0990);
   AssertEqualInt((int)second, (int)first,
                  "dos evaluaciones con las mismas entradas son deterministas");

   AssertTrue(LmSignalDirectionName(SIGNAL_SELL) == "SELL",
              "el nombre de SELL es estable para el CSV");
   AssertEqualInt((int)LmSignalDirectionFromName("NONE"), (int)SIGNAL_NONE,
                  "NONE se puede leer del CSV");
   AssertTrue(LmTimeframeName(PERIOD_H1) == "H1",
              "el timeframe H1 se escribe sin el prefijo PERIOD_");
  }

//+------------------------------------------------------------------+
//| 8.1 Senal pura de Fibonacci Focus: SELL, BUY y NONE.             |
//+------------------------------------------------------------------+
void TestFibonacciSignal()
  {
   AssertEqualInt((int)LmFibonacciSignal(1.1010, 1.0995, true, 40.0),
                  (int)SIGNAL_SELL,
                  "Fibonacci: high[1] > low[2] y RSI > 30 devuelve SELL");
   AssertEqualInt((int)LmFibonacciSignal(1.0990, 1.1000, true, 60.0),
                  (int)SIGNAL_BUY,
                  "Fibonacci: high[1] <= low[2] y RSI < 70 devuelve BUY");
   AssertEqualInt((int)LmFibonacciSignal(1.0990, 1.1000, true, 70.0),
                  (int)SIGNAL_NONE,
                  "Fibonacci: RSI >= 70 bloquea la rama de compra");
   AssertEqualInt((int)LmFibonacciSignal(1.1010, 1.0995, true, 30.0),
                  (int)SIGNAL_NONE,
                  "Fibonacci: RSI <= 30 bloquea la rama de venta");
   AssertEqualInt((int)LmFibonacciSignal(1.1010, 1.0995, false, 40.0),
                  (int)SIGNAL_NONE,
                  "Fibonacci: sin RSI la senal es NONE");

   ENUM_SIGNAL_DIRECTION first  = LmFibonacciSignal(1.1010, 1.0995, true, 40.0);
   ENUM_SIGNAL_DIRECTION second = LmFibonacciSignal(1.1010, 1.0995, true, 40.0);
   AssertEqualInt((int)second, (int)first,
                  "Fibonacci: dos evaluaciones con las mismas entradas son deterministas");
  }

//+------------------------------------------------------------------+
//| 8.2 Senal pura de TrendMaster: SELL, BUY y NONE.                 |
//+------------------------------------------------------------------+
void TestTrendMasterSignal()
  {
   AssertEqualInt((int)LmTrendMasterSignal(1.1000, 1.0990, true, 40.0),
                  (int)SIGNAL_SELL,
                  "TrendMaster: close[2] > close[1] y RSI > 30 devuelve SELL");
   AssertEqualInt((int)LmTrendMasterSignal(1.0990, 1.1000, true, 60.0),
                  (int)SIGNAL_BUY,
                  "TrendMaster: close[2] <= close[1] y RSI < 70 devuelve BUY");
   AssertEqualInt((int)LmTrendMasterSignal(1.0990, 1.1000, true, 70.0),
                  (int)SIGNAL_NONE,
                  "TrendMaster: RSI >= 70 bloquea la rama de compra");
   AssertEqualInt((int)LmTrendMasterSignal(1.1000, 1.0990, true, 30.0),
                  (int)SIGNAL_NONE,
                  "TrendMaster: RSI <= 30 bloquea la rama de venta");
   AssertEqualInt((int)LmTrendMasterSignal(1.1000, 1.0990, false, 40.0),
                  (int)SIGNAL_NONE,
                  "TrendMaster: sin RSI la senal es NONE");

   ENUM_SIGNAL_DIRECTION first  = LmTrendMasterSignal(1.1000, 1.0990, true, 40.0);
   ENUM_SIGNAL_DIRECTION second = LmTrendMasterSignal(1.1000, 1.0990, true, 40.0);
   AssertEqualInt((int)second, (int)first,
                  "TrendMaster: dos evaluaciones con las mismas entradas son deterministas");
  }

//+------------------------------------------------------------------+
//| 6.2 Exportacion CSV con fecha, estrategia, direccion y timeframe.|
//+------------------------------------------------------------------+
void TestSignalCsvExport()
  {
   string filename = "lm_robot_test_signal_export.csv";
   FileDelete(filename);

   datetime times[3];
   times[0] = D'2026.01.02 10:00:00';
   times[1] = D'2026.01.02 11:00:00';
   times[2] = D'2026.01.02 12:00:00';

   ENUM_SIGNAL_DIRECTION directions[3];
   directions[0] = SIGNAL_BUY;
   directions[1] = SIGNAL_SELL;
   directions[2] = SIGNAL_NONE;

   int written = 0;
   AssertTrue(LmExportSignalSeries(times, directions, 0, 3, "Scalper", "H1",
                                   filename, written),
              "la exportacion CSV escribe la serie de senales");
   AssertEqualInt(written, 3, "se escriben las tres filas solicitadas");

   CSignalCsvReader reader;
   AssertTrue(reader.Load(filename), "el CSV exportado se puede leer");
   AssertEqualInt(reader.Count(), 3, "el CSV contiene una fila por senal");

   SignalRow row;
   AssertTrue(reader.RowAt(2, row), "la tercera fila esta disponible");
   AssertEqualInt((int)row.direction, (int)SIGNAL_NONE,
                  "la exportacion conserva las senales NONE");
   AssertTrue(row.strategy == "Scalper", "la fila conserva la estrategia");
   AssertTrue(row.timeframe == "H1", "la fila conserva el timeframe");
   AssertTrue(row.time == times[2], "la fila conserva la fecha del servidor");

   FileDelete(filename);
  }

//+------------------------------------------------------------------+
//| 6.3 Comparador CSV: coincidencias, faltantes, sobrantes.         |
//+------------------------------------------------------------------+
void TestSignalCsvComparator()
  {
   string referenceFile = "lm_robot_test_signal_ref.csv";
   string sameFile      = "lm_robot_test_signal_same.csv";
   string diffFile      = "lm_robot_test_signal_diff.csv";

   FileDelete(referenceFile);
   FileDelete(sameFile);
   FileDelete(diffFile);

   CSignalCsvWriter reference;
   AssertTrue(reference.Open(referenceFile), "se crea el CSV de referencia");
   reference.WriteRow(D'2026.01.02 10:00:00', "Scalper", SIGNAL_SELL, "H1");
   reference.WriteRow(D'2026.01.02 11:00:00', "Scalper", SIGNAL_BUY,  "H1");
   reference.WriteRow(D'2026.01.02 12:00:00', "Scalper", SIGNAL_NONE, "H1");
   reference.Close();

   CSignalCsvWriter same;
   AssertTrue(same.Open(sameFile), "se crea el CSV identico");
   same.WriteRow(D'2026.01.02 10:00:00', "Scalper", SIGNAL_SELL, "H1");
   same.WriteRow(D'2026.01.02 11:00:00', "Scalper", SIGNAL_BUY,  "H1");
   same.WriteRow(D'2026.01.02 12:00:00', "Scalper", SIGNAL_NONE, "H1");
   same.Close();

   CSignalCsvWriter diff;
   AssertTrue(diff.Open(diffFile), "se crea el CSV alterado");
   diff.WriteRow(D'2026.01.02 10:00:00', "Scalper", SIGNAL_SELL, "H1");
   diff.WriteRow(D'2026.01.02 11:00:00', "Scalper", SIGNAL_NONE, "H1");
   diff.WriteRow(D'2026.01.02 13:00:00', "Scalper", SIGNAL_BUY,  "H1");
   diff.Close();

   CSignalComparison comparison;
   AssertTrue(LmCompareSignalCsvFiles(referenceFile, sameFile, comparison),
              "el comparador lee dos CSV identicos");
   AssertEqualInt(comparison.referenceCount, 3, "la referencia tiene tres filas");
   AssertEqualInt(comparison.actualCount, 3, "el CSV nuevo tiene tres filas");
   AssertEqualInt(comparison.matches, 3, "las tres filas coinciden");
   AssertEqualInt(comparison.missing, 0, "no hay filas faltantes");
   AssertEqualInt(comparison.extra, 0, "no hay filas sobrantes");
   AssertEqualInt(comparison.mismatched, 0, "no hay direcciones diferentes");
   AssertTrue(comparison.parity, "dos CSV identicos declaran paridad");

   AssertTrue(LmCompareSignalCsvFiles(referenceFile, diffFile, comparison),
              "el comparador lee el CSV alterado");
   AssertEqualInt(comparison.matches, 1, "solo la primera fila coincide");
   AssertEqualInt(comparison.mismatched, 1, "se detecta una direccion diferente");
   AssertEqualInt(comparison.missing, 1, "se detecta una fila faltante");
   AssertEqualInt(comparison.extra, 1, "se detecta una fila sobrante");
   AssertTrue(!comparison.parity, "el CSV alterado no declara paridad");
   AssertTrue(ArraySize(comparison.details) >= 3,
              "el reporte detalla cada diferencia");

   FileDelete(referenceFile);
   FileDelete(sameFile);
   FileDelete(diffFile);
  }

//+------------------------------------------------------------------+
//| 2.1 Deteccion de pip.                                            |
//+------------------------------------------------------------------+
void TestPipDetection()
  {
   double point5 = 0.00001;
   double point4 = 0.0001;
   double point3 = 0.001;
   double point2 = 0.01;

   AssertEqualDouble(LmPipSize(5, point5), point5 * 10.0, 1e-12,
                     "pip en simbolo de 5 digitos = 10 puntos");
   AssertEqualDouble(LmPipSize(4, point4), point4, 1e-12,
                     "pip en simbolo de 4 digitos = 1 punto");
   AssertEqualDouble(LmPipSize(3, point3), point3 * 10.0, 1e-12,
                     "pip en simbolo de 3 digitos = 10 puntos");
   AssertEqualDouble(LmPipSize(2, point2), point2, 1e-12,
                     "pip en simbolo de 2 digitos = 1 punto");

   AssertEqualDouble(LmPipsToPoints(20.0, LmPipSize(5, point5), point5), 200.0, 1e-9,
                     "20 pips en 5 digitos = 200 puntos");
   AssertEqualDouble(LmPipsToPoints(20.0, LmPipSize(4, point4), point4), 20.0, 1e-9,
                     "20 pips en 4 digitos = 20 puntos");
  }

//+------------------------------------------------------------------+
//| 2.2 Valor del pip por lote.                                      |
//+------------------------------------------------------------------+
void TestPipValuePerLot()
  {
   double pipValue5 = LmPipValuePerLot(1.0, 0.00001, LmPipSize(5, 0.00001));
   double pipValue4 = LmPipValuePerLot(10.0, 0.0001, LmPipSize(4, 0.0001));

   AssertEqualDouble(pipValue5, 10.0, 1e-9,
                     "valor del pip por lote en simbolo de 5 digitos");
   AssertEqualDouble(pipValue4, 10.0, 1e-9,
                     "valor del pip por lote en simbolo de 4 digitos");
   AssertEqualDouble(LmPipValuePerLot(1.0, 0.0, 0.0001), 0.0, 1e-12,
                     "valor del pip con tick size invalido = 0");
  }

//+------------------------------------------------------------------+
//| 2.3 Snapshot de un tick reutilizado por varios consumidores.     |
//+------------------------------------------------------------------+
void TestMarketSnapshot()
  {
   InstrumentInfo instrument = MakeFiveDigitInstrument();
   CMarketContext context;

   AssertTrue(context.InitFromInstrument(instrument, 3.0, 25.0),
              "contexto de prueba inicializado desde el instrumento");
   AssertTrue(context.RefreshFromTick(1.10000, 1.10020, D'2026.01.02 10:00:00'),
              "snapshot del tick construido");

   MarketSnapshot consumerA = context.Snapshot();
   MarketSnapshot consumerB = context.Snapshot();

   AssertEqualDouble(consumerA.bid, consumerB.bid, 1e-12,
                     "dos consumidores del tick leen el mismo bid");
   AssertEqualDouble(consumerA.ask, consumerB.ask, 1e-12,
                     "dos consumidores del tick leen el mismo ask");
   AssertEqualDouble(consumerA.bid, 1.10000, 1e-12, "bid del snapshot");
   AssertEqualDouble(consumerA.ask, 1.10020, 1e-12, "ask del snapshot");
   AssertEqualDouble(consumerA.spreadPips, 2.0, 1e-9, "spread del snapshot en pips");
   AssertEqualInt(context.Refreshes(), 1, "el tick se leyo una sola vez");
   AssertEqualDouble(context.Bid(), 1.10000, 1e-12,
                     "el getter reutiliza el bid leido");
   AssertEqualInt(context.Refreshes(), 1,
                  "los getters no vuelven a leer el mercado");

   //--- ATR actual y medio viajan en el mismo snapshot.
   AssertTrue(context.RefreshFromValues(1.10000, 1.10020,
                                        D'2026.01.02 10:01:00',
                                        true, 12.5, 10.0),
              "snapshot con ATR inyectado");
   AssertEqualDouble(context.AtrPips(), 12.5, 1e-9,
                     "el snapshot expone el ATR actual en pips");
   AssertEqualDouble(context.AtrAvgPips(), 10.0, 1e-9,
                     "el snapshot expone la media del ATR en pips");
  }

//+------------------------------------------------------------------+
//| 2.5 Flags de spread maximo y volatilidad alta.                   |
//+------------------------------------------------------------------+
void TestMarketFlags()
  {
   AssertTrue(!LmSpreadBlocked(2.0, 3.0), "spread debajo del maximo no bloquea");
   AssertTrue(LmSpreadBlocked(4.0, 3.0), "spread encima del maximo bloquea");
   AssertTrue(!LmSpreadBlocked(3.0, 3.0), "spread igual al maximo no bloquea");

   AssertTrue(!LmHighVolatility(true, 20.0, 25.0), "ATR debajo del maximo no alerta");
   AssertTrue(LmHighVolatility(true, 30.0, 25.0), "ATR encima del maximo alerta");
   AssertTrue(!LmHighVolatility(false, 30.0, 25.0), "sin lectura de ATR no hay alerta");

   InstrumentInfo instrument = MakeFiveDigitInstrument();
   CMarketContext context;
   context.InitFromInstrument(instrument, 3.0, 25.0);

   context.RefreshFromTick(1.10000, 1.10020, D'2026.01.02 10:00:00');
   AssertTrue(!context.SpreadBlocked(), "snapshot con spread en rango no bloquea");

   context.RefreshFromTick(1.10000, 1.10040, D'2026.01.02 10:01:00');
   AssertTrue(context.SpreadBlocked(), "snapshot con spread alto bloquea");
  }

//+------------------------------------------------------------------+
//| 2.4 Handles creados una vez y liberados al desinicializar.       |
//+------------------------------------------------------------------+
void TestMarketHandles()
  {
   CMarketContext context;

   bool initialized = context.Init(_Symbol, _Period, 14, _Period, 14, 3.0, 30.0);
   AssertTrue(initialized, "handles RSI/ATR creados en la inicializacion");
   AssertTrue(context.RsiHandle() != INVALID_HANDLE, "handle RSI valido");
   AssertTrue(context.AtrHandle() != INVALID_HANDLE, "handle ATR valido");

   int creations = context.HandleCreations();
   for(int i = 0; i < 10; i++)
      context.RefreshFromTick(1.10000, 1.10010, D'2026.01.02 10:00:00');

   AssertEqualInt(context.HandleCreations(), creations,
                  "diez ticks no crean handles nuevos");
   AssertEqualInt(context.Refreshes(), 10, "diez ticks contabilizados");

   context.ReleaseHandles();
   AssertTrue(context.RsiHandle() == INVALID_HANDLE && context.AtrHandle() == INVALID_HANDLE,
              "handles liberados en la desinicializacion");
  }

//+------------------------------------------------------------------+
//| 7.2 Cuenta hedging y 7.3 seleccion de estrategia.                |
//+------------------------------------------------------------------+
void TestAccountAndStrategySelection()
  {
   AssertTrue(LmIsHedgingAccount(ACCOUNT_MARGIN_MODE_RETAIL_HEDGING),
              "una cuenta hedging es aceptada");
   AssertTrue(!LmIsHedgingAccount(ACCOUNT_MARGIN_MODE_RETAIL_NETTING),
              "una cuenta netting es rechazada");
   AssertTrue(LmAccountModeError(ACCOUNT_MARGIN_MODE_RETAIL_NETTING) != "",
              "la cuenta netting produce un mensaje explicito");
   AssertTrue(LmAccountModeError(ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) == "",
              "la cuenta hedging no produce error");

   AssertTrue(LmStrategyIsValid(LM_STRATEGY_SCALPER_PRO),
              "Scalper Pro es una estrategia valida");
   AssertTrue(LmStrategyIsValid(LM_STRATEGY_FIBONACCI_FOCUS),
              "Fibonacci Focus es una estrategia valida");
   AssertTrue(LmStrategyIsValid(LM_STRATEGY_TREND_MASTER),
              "TrendMaster es una estrategia valida");
   AssertTrue(!LmStrategyIsValid((ENUM_LM_STRATEGY)99),
              "un valor fuera del enum es una estrategia invalida");
   AssertTrue(LmStrategyName(LM_STRATEGY_SCALPER_PRO) == "Scalper Pro",
              "el nombre de la estrategia es estable");

   AssertEqualInt((int)LmEvaluateStrategy(LM_STRATEGY_SCALPER_PRO, 1.0990, 1.1000,
                                          1.1000, 1.0990, false, 0.0),
                  (int)SIGNAL_SELL,
                  "la estrategia seleccionada evalua la regla de Scalper");
   AssertEqualInt((int)LmEvaluateStrategy(LM_STRATEGY_FIBONACCI_FOCUS, 1.0990, 1.1000,
                                          1.1000, 1.0990, true, 40.0),
                  (int)SIGNAL_SELL,
                  "la estrategia seleccionada evalua la regla de Fibonacci");
   AssertEqualInt((int)LmEvaluateStrategy(LM_STRATEGY_FIBONACCI_FOCUS, 1.0990, 1.1000,
                                          1.1000, 1.0990, true, 20.0),
                  (int)SIGNAL_NONE,
                  "Fibonacci comparte el contrato y puede devolver NONE");
   AssertEqualInt((int)LmEvaluateStrategy(LM_STRATEGY_TREND_MASTER, 1.0990, 1.1000,
                                          1.1000, 1.0990, true, 40.0),
                  (int)SIGNAL_SELL,
                  "la estrategia seleccionada evalua la regla de TrendMaster");
   AssertEqualInt((int)LmEvaluateStrategy(LM_STRATEGY_TREND_MASTER, 1.0990, 1.1000,
                                          1.1000, 1.0990, true, 20.0),
                  (int)SIGNAL_NONE,
                  "TrendMaster comparte el contrato y puede devolver NONE");
   AssertEqualInt((int)LmEvaluateStrategy((ENUM_LM_STRATEGY)99, 1.0990, 1.1000,
                                          1.1000, 1.0990, false, 0.0),
                  (int)SIGNAL_NONE,
                  "una estrategia invalida no produce senal");
  }

//+------------------------------------------------------------------+
//| 7.1 Una evaluacion por barra cerrada.                            |
//+------------------------------------------------------------------+
void TestBarGate()
  {
   CLmBarGate gate;
   datetime bar = D'2026.01.02 10:00:00';
   int evaluations = 0;

   for(int i = 0; i < 10; i++)
     {
      if(gate.ShouldEvaluate(bar))
         evaluations++;
     }

   AssertEqualInt(evaluations, 1, "diez ticks de la misma barra producen una evaluacion");
   AssertEqualInt(gate.Evaluations(), 1, "el contador del gate refleja una evaluacion");

   AssertTrue(gate.ShouldEvaluate(bar + 3600),
              "el cierre de la barra siguiente habilita otra evaluacion");
   AssertEqualInt(gate.Evaluations(), 2, "el contador avanza al cambiar la barra");
   AssertTrue(!gate.ShouldEvaluate(bar + 3600),
              "un tick posterior de la misma barra no reevalua");
  }

//+------------------------------------------------------------------+
//| 7.4 Filtro de sesion por hora del servidor.                      |
//+------------------------------------------------------------------+
void TestSessionGuard()
  {
   SessionConfig off = LmDefaultSessionConfig();
   AssertTrue(LmSessionOpen(D'2026.01.02 03:00:00', off),
              "sin filtro la sesion siempre esta abierta");

   SessionConfig day;
   day.enabled   = true;
   day.startHour = 8;
   day.endHour   = 17;

   AssertTrue(LmSessionOpen(D'2026.01.02 09:00:00', day),
              "la sesion diurna abre a las 09:00");
   AssertTrue(!LmSessionOpen(D'2026.01.02 18:00:00', day),
              "la sesion diurna cierra a las 18:00");

   SessionConfig night;
   night.enabled   = true;
   night.startHour = 22;
   night.endHour   = 6;

   AssertTrue(LmSessionOpen(D'2026.01.02 23:00:00', night),
              "la sesion nocturna abre antes de medianoche");
   AssertTrue(LmSessionOpen(D'2026.01.02 03:00:00', night),
              "la sesion nocturna sigue abierta despues de medianoche");
   AssertTrue(!LmSessionOpen(D'2026.01.02 12:00:00', night),
              "la sesion nocturna esta cerrada al mediodia");

   SessionConfig invalid;
   invalid.enabled   = true;
   invalid.startHour = 25;
   invalid.endHour   = 3;

   AssertTrue(!LmSessionConfigValid(invalid),
              "una hora de inicio invalida se detecta");
  }

//+------------------------------------------------------------------+
//| 7.5 Pipeline completo: apertura, grid, proteccion y cierre.      |
//+------------------------------------------------------------------+
void TestRuntimePipeline()
  {
   CTestBrokerState broker;
   broker.m_magic  = 111;
   broker.m_symbol = "TEST5";

   CTestBrokerBackend backend(&broker);
   CTestBrokerBasketSource baskets(&broker);
   CTestBarSource bars;

   InstrumentInfo instrument = MakeFiveDigitInstrument();
   CMarketContext market;
   AssertTrue(market.InitFromInstrument(instrument, 3.0, 25.0),
              "el runtime inicia con un instrumento de prueba");

   CTestAccountProvider accounts(1000.0, 10.0);
   CExecutor executor;
   AssertTrue(executor.Init(&backend, &accounts, MakeRuntimeLimits(),
                            MakeExecutionConfig(3, 0, 1000)),
              "el runtime inicia con un ejecutor simulado");

   CTestDailyStore store;
   CDailyLossGuard daily;
   AssertTrue(daily.Init(&store, 123456, 4.0),
              "el runtime inicia con una guarda diaria de prueba");

   RuntimeConfig config = MakeRuntimeConfig();
   CLmRuntime runtime;
   AssertTrue(runtime.Init(&market, &baskets, &bars, &executor, &daily, config),
              "el runtime se inicializa");

   datetime bar1 = D'2026.01.02 10:00:00';
   bars.Set(bar1, 1.1000, 1.0990);
   broker.SetQuote(1.10000, 1.10002);
   market.RefreshFromTick(1.10000, 1.10002, bar1);

   AssertTrue(runtime.ProcessTick(bar1, 10000.0, 10000.0),
              "el primer tick se procesa");
   AssertEqualInt(runtime.OrdersSent(), 1, "el pipeline abre la primera orden");
   AssertEqualInt(broker.Count(), 1, "el broker simulado registra la apertura");

   BasketPosition first = broker.PositionAt(0);
   AssertEqualDouble(first.openPrice, 1.10002, 1e-9,
                     "la primera orden se abre en el ask del snapshot");
   AssertEqualDouble(first.volume, 0.10, 1e-9,
                     "la primera orden respeta el tope por orden");
   AssertEqualDouble(first.sl, 1.09602, 1e-9,
                     "la primera orden lleva stop loss de canasta");
   AssertEqualDouble(first.tp, 1.10082, 1e-9,
                     "la primera orden lleva take profit de canasta");

   //--- Diez ticks de la misma barra no generan otra evaluacion.
   for(int i = 0; i < 10; i++)
     {
      market.RefreshFromTick(1.10000, 1.10002, bar1 + i);
      runtime.ProcessTick(bar1 + i, 10000.0, 10000.0);
     }

   AssertEqualInt(runtime.Evaluations(), 1,
                  "los ticks de la misma barra no reevaluan la senal");
   AssertEqualInt(runtime.OrdersSent(), 1,
                  "la misma barra no duplica la primera orden");

   //--- El precio cae 22 pips: se agrega un paso de grid.
   datetime bar2 = bar1 + 3600;
   bars.Set(bar2, 1.0978, 1.0980);
   broker.SetQuote(1.09780, 1.09782);
   market.RefreshFromTick(1.09780, 1.09782, bar2);

   AssertTrue(runtime.ProcessTick(bar2, 9900.0, 10000.0),
              "el tick del grid se procesa");
   AssertEqualInt(runtime.OrdersSent(), 2, "el pipeline agrega un paso de grid");
   AssertEqualInt(broker.Count(), 2, "la canasta pasa a dos posiciones");

   double expectedAverage = 1.09892;
   double expectedSl      = expectedAverage - 0.0040;
   double expectedTp      = expectedAverage + 0.0008;

   for(int i = 0; i < broker.Count(); i++)
     {
      BasketPosition position = broker.PositionAt(i);
      AssertEqualDouble(position.sl, expectedSl, 1e-9,
                        StringFormat("la posicion %d recibe el nuevo SL", i + 1));
      AssertEqualDouble(position.tp, expectedTp, 1e-9,
                        StringFormat("la posicion %d recibe el nuevo TP", i + 1));
     }

   AssertTrue(runtime.ProtectionUpdates() >= 2,
              "el paso de grid reenvia la proteccion a la canasta");

   //--- El precio alcanza el TP: el broker cierra toda la canasta.
   broker.SetQuote(1.09975, 1.09977);
   AssertEqualInt(broker.Count(), 0, "el take profit cierra la canasta");

   market.RefreshFromTick(1.09975, 1.09977, bar2 + 60);
   runtime.ProcessTick(bar2 + 60, 10000.0, 10000.0);

   AssertEqualInt(runtime.Closures(), 1, "el runtime detecta el cierre de la canasta");
   AssertEqualInt(runtime.OrdersSent(), 2,
                  "el tick de cierre no abre una orden nueva en la misma barra");
  }

//+------------------------------------------------------------------+
//| 7.5b Riesgo vivo: validacion del setter.                         |
//+------------------------------------------------------------------+
void TestRuntimeSetRiskPct()
  {
   CLmRuntime runtime;
   AssertEqualInt((int)runtime.Config().risk.riskMode, (int)LM_RISK_AUTO,
                  "el runtime arranca en modo automatico");
   AssertEqualDouble(runtime.Config().risk.riskPct, 0.5, 1e-9,
                     "el runtime arranca con el riesgo por defecto");

   AssertTrue(runtime.SetRiskMode(LM_RISK_MANUAL),
              "la prueba del control manual fija la modalidad manual");

   AssertTrue(runtime.SetRiskPct(4.0), "el setter acepta un riesgo valido");
   AssertEqualDouble(runtime.Config().risk.riskPct, 4.0, 1e-9,
                     "el riesgo valido se lee de vuelta");

   AssertTrue(!runtime.SetRiskPct(0.0), "el setter rechaza cero");
   AssertEqualDouble(runtime.Config().risk.riskPct, 4.0, 1e-9,
                     "cero no modifica el riesgo previo");

   AssertTrue(!runtime.SetRiskPct(-1.0), "el setter rechaza negativos");
   AssertEqualDouble(runtime.Config().risk.riskPct, 4.0, 1e-9,
                     "un negativo no modifica el riesgo previo");

   double nanValue = MathLog(-1.0);
   AssertTrue(!MathIsValidNumber(nanValue), "el valor de prueba es NaN");
   AssertTrue(!runtime.SetRiskPct(nanValue), "el setter rechaza NaN");
   AssertEqualDouble(runtime.Config().risk.riskPct, 4.0, 1e-9,
                     "NaN no modifica el riesgo previo");
  }

//+------------------------------------------------------------------+
//| 7.5c El riesgo ajustado dimensiona el proximo paso de grid.      |
//+------------------------------------------------------------------+
void TestRuntimeRiskAffectsNextGrid()
  {
   CTestBrokerState broker;
   broker.m_magic  = 111;
   broker.m_symbol = "TEST5";

   CTestBrokerBackend backend(&broker);
   CTestBrokerBasketSource baskets(&broker);
   CTestBarSource bars;

   InstrumentInfo instrument = MakeFiveDigitInstrument();
   CMarketContext market;
   AssertTrue(market.InitFromInstrument(instrument, 3.0, 25.0),
              "el runtime de riesgo inicia con un instrumento de prueba");

   CTestAccountProvider accounts(1000.0, 10.0);
   CExecutor executor;
   AssertTrue(executor.Init(&backend, &accounts, MakeRuntimeLimits(),
                            MakeExecutionConfig(3, 0, 1000)),
              "el runtime de riesgo inicia con un ejecutor simulado");

   CTestDailyStore store;
   CDailyLossGuard daily;
   AssertTrue(daily.Init(&store, 123456, 4.0),
              "el runtime de riesgo inicia con una guarda diaria");

   RuntimeConfig config = MakeRuntimeConfig();
   config.risk.maxLotPerOrder       = 9.0;
   config.risk.maxVolumePerStrategy = 9.0;
   config.risk.maxBasketLossPct     = 1000.0;

   CLmRuntime runtime;
   AssertTrue(runtime.Init(&market, &baskets, &bars, &executor, &daily, config),
              "el runtime de riesgo se inicializa");

   datetime bar1 = D'2026.01.02 10:00:00';
   bars.Set(bar1, 1.1000, 1.0990);
   broker.SetQuote(1.10000, 1.10002);
   market.RefreshFromTick(1.10000, 1.10002, bar1);
   runtime.ProcessTick(bar1, 10000.0, 10000.0);

   AssertEqualInt(broker.Count(), 1, "se abre la primera orden de la canasta");
   BasketPosition first = broker.PositionAt(0);
   AssertEqualDouble(first.volume, 0.12, 1e-9,
                     "la primera orden usa el riesgo inicial");

   double firstSl = first.sl;

   //--- Duplicar el riesgo no toca la posicion ya abierta.
   AssertTrue(runtime.SetRiskPct(1.0), "el riesgo vivo se ajusta al doble");
   AssertEqualDouble(broker.PositionAt(0).volume, 0.12, 1e-9,
                     "el ajuste no redimensiona la posicion existente");
   AssertEqualDouble(broker.PositionAt(0).sl, firstSl, 1e-9,
                     "el ajuste no altera el stop loss existente");

   //--- El siguiente paso de grid se dimensiona con el riesgo ajustado.
   datetime bar2 = bar1 + 3600;
   bars.Set(bar2, 1.0978, 1.0980);
   broker.SetQuote(1.09780, 1.09782);
   market.RefreshFromTick(1.09780, 1.09782, bar2);
   runtime.ProcessTick(bar2, 10000.0, 10000.0);

   AssertEqualInt(broker.Count(), 2, "la canasta recibe el paso de grid");
   AssertEqualDouble(broker.PositionAt(0).volume, 0.12, 1e-9,
                     "la posicion anterior conserva su volumen");
   AssertEqualDouble(broker.PositionAt(1).volume, 0.37, 1e-9,
                     "el nuevo paso crece con el riesgo duplicado");
  }

//+------------------------------------------------------------------+
//| 7.4 La canasta abierta se gestiona con cada guard activo.        |
//+------------------------------------------------------------------+
void TestRuntimeGuardsKeepManaging()
  {
   CTestBrokerState broker;
   broker.m_magic  = 111;
   broker.m_symbol = "TEST5";

   CTestBrokerBackend backend(&broker);
   CTestBrokerBasketSource baskets(&broker);
   CTestBarSource bars;

   InstrumentInfo instrument = MakeFiveDigitInstrument();
   CMarketContext market;
   market.InitFromInstrument(instrument, 3.0, 25.0);

   CTestAccountProvider accounts(1000.0, 10.0);
   CExecutor executor;
   executor.Init(&backend, &accounts, MakeRuntimeLimits(),
                 MakeExecutionConfig(3, 0, 1000));

   CTestDailyStore store;
   CDailyLossGuard daily;
   daily.Init(&store, 123456, 4.0);

   RuntimeConfig config = MakeRuntimeConfig();
   config.session.enabled   = true;
   config.session.startHour = 8;
   config.session.endHour   = 17;

   CLmRuntime runtime;
   AssertTrue(runtime.Init(&market, &baskets, &bars, &executor, &daily, config),
              "el runtime de guards se inicializa");

   datetime bar1 = D'2026.01.02 10:00:00';
   bars.Set(bar1, 1.1000, 1.0990);
   broker.SetQuote(1.10000, 1.10002);
   market.RefreshFromTick(1.10000, 1.10002, bar1);
   runtime.ProcessTick(bar1, 10000.0, 10000.0);

   AssertEqualInt(runtime.OrdersSent(), 1, "se abre una canasta para las pruebas de guards");

   //--- Limite diario activo.
   int orders = runtime.OrdersSent();
   int updates = runtime.ProtectionUpdates();
   broker.ClearProtection();
   datetime barDaily = bar1 + 3600;
   bars.Set(barDaily, 1.1000, 1.0990);
   broker.SetQuote(1.10000, 1.10002);
   market.RefreshFromTick(1.10000, 1.10002, barDaily);
   runtime.ProcessTick(barDaily, 9500.0, 10000.0);

   AssertTrue(runtime.ProtectionUpdates() > updates,
              "la gestion sigue con el limite diario activo");
   AssertEqualInt(runtime.OrdersSent(), orders,
                  "el limite diario bloquea solo la apertura");

   //--- Spread fuera de rango.
   updates = runtime.ProtectionUpdates();
   broker.ClearProtection();
   datetime barSpread = bar1 + 7200;
   bars.Set(barSpread, 1.1000, 1.0990);
   broker.SetQuote(1.10000, 1.10050);
   market.RefreshFromTick(1.10000, 1.10050, barSpread);
   runtime.ProcessTick(barSpread, 9500.0, 10000.0);

   AssertTrue(runtime.ProtectionUpdates() > updates,
              "la gestion sigue con el spread bloqueado");
   AssertEqualInt(runtime.OrdersSent(), orders,
                  "el spread bloquea solo la apertura");

   //--- Volatilidad alta.
   updates = runtime.ProtectionUpdates();
   broker.ClearProtection();
   datetime barVolatility = bar1 + 10800;
   bars.Set(barVolatility, 1.1000, 1.0990);
   broker.SetQuote(1.10000, 1.10002);
   market.RefreshFromValues(1.10000, 1.10002, barVolatility, true, 50.0);
   runtime.ProcessTick(barVolatility, 9500.0, 10000.0);

   AssertTrue(runtime.ProtectionUpdates() > updates,
              "la gestion sigue con la volatilidad alta");
   AssertEqualInt(runtime.OrdersSent(), orders,
                  "la volatilidad alta bloquea solo la apertura");

   //--- Sesion cerrada.
   updates = runtime.ProtectionUpdates();
   broker.ClearProtection();
   datetime barSession = D'2026.01.02 18:00:00';
   bars.Set(barSession, 1.1000, 1.0990);
   broker.SetQuote(1.10000, 1.10002);
   market.RefreshFromValues(1.10000, 1.10002, barSession, false, 0.0);
   runtime.ProcessTick(barSession, 9500.0, 10000.0);

   AssertTrue(runtime.ProtectionUpdates() > updates,
              "la gestion sigue con la sesion cerrada");
   AssertEqualInt(runtime.OrdersSent(), orders,
                  "la sesion cerrada bloquea solo la apertura");

   AssertEqualInt(broker.Count(), 1,
                  "la canasta sigue abierta despues de los cuatro guards");
  }

//+------------------------------------------------------------------+
//| 8.3 Solo la estrategia seleccionada abre y consume presupuesto.  |
//+------------------------------------------------------------------+
void TestStrategySelectionRuntime()
  {
   //--- Con estas barras: Scalper -> BUY, Fibonacci -> SELL, Trend -> NONE.
   datetime bar = D'2026.01.02 10:00:00';

   //--- Scalper Pro seleccionada: solo se abre su BUY.
   CTestBrokerState scalperBroker;
   scalperBroker.m_magic  = 111;
   scalperBroker.m_symbol = "TEST5";

   CTestBrokerBackend scalperBackend(&scalperBroker);
   CTestBrokerBasketSource scalperBaskets(&scalperBroker);
   CTestBarSource scalperBars;
   scalperBars.Set(bar, 1.1000, 1.0990);
   scalperBars.SetRsi(80.0);

   InstrumentInfo scalperInstrument = MakeFiveDigitInstrument();
   CMarketContext scalperMarket;
   scalperMarket.InitFromInstrument(scalperInstrument, 3.0, 25.0);

   CTestAccountProvider scalperAccounts(1000.0, 10.0);
   CExecutor scalperExecutor;
   scalperExecutor.Init(&scalperBackend, &scalperAccounts, MakeRuntimeLimits(),
                        MakeExecutionConfig(3, 0, 1000));

   CTestDailyStore scalperStore;
   CDailyLossGuard scalperDaily;
   scalperDaily.Init(&scalperStore, 123456, 4.0);

   RuntimeConfig scalperConfig = MakeRuntimeConfig();
   scalperConfig.strategy = LM_STRATEGY_SCALPER_PRO;

   CLmRuntime scalperRuntime;
   AssertTrue(scalperRuntime.Init(&scalperMarket, &scalperBaskets, &scalperBars,
                                  &scalperExecutor, &scalperDaily, scalperConfig),
              "el runtime de Scalper se inicializa");
   scalperBroker.SetQuote(1.10000, 1.10002);
   scalperMarket.RefreshFromTick(1.10000, 1.10002, bar);
   scalperRuntime.ProcessTick(bar, 10000.0, 10000.0);

   AssertEqualInt(scalperRuntime.OrdersSent(), 1,
                  "Scalper abre una posicion con su propia senal");
   AssertEqualInt(scalperBroker.Count(), 1, "el broker registra la orden de Scalper");
   BasketPosition scalperPosition = scalperBroker.PositionAt(0);
   AssertEqualInt((int)scalperPosition.type, (int)POSITION_TYPE_BUY,
                  "Scalper abre la direccion que dicta su regla");

   //--- Fibonacci Focus seleccionada: solo se abre su SELL.
   CTestBrokerState fibBroker;
   fibBroker.m_magic  = 111;
   fibBroker.m_symbol = "TEST5";

   CTestBrokerBackend fibBackend(&fibBroker);
   CTestBrokerBasketSource fibBaskets(&fibBroker);
   CTestBarSource fibBars;
   fibBars.Set(bar, 1.1000, 1.0990);
   fibBars.SetRsi(80.0);

   InstrumentInfo fibInstrument = MakeFiveDigitInstrument();
   CMarketContext fibMarket;
   fibMarket.InitFromInstrument(fibInstrument, 3.0, 25.0);

   CTestAccountProvider fibAccounts(1000.0, 10.0);
   CExecutor fibExecutor;
   fibExecutor.Init(&fibBackend, &fibAccounts, MakeRuntimeLimits(),
                    MakeExecutionConfig(3, 0, 1000));

   CTestDailyStore fibStore;
   CDailyLossGuard fibDaily;
   fibDaily.Init(&fibStore, 123456, 4.0);

   RuntimeConfig fibConfig = MakeRuntimeConfig();
   fibConfig.strategy = LM_STRATEGY_FIBONACCI_FOCUS;

   CLmRuntime fibRuntime;
   AssertTrue(fibRuntime.Init(&fibMarket, &fibBaskets, &fibBars,
                              &fibExecutor, &fibDaily, fibConfig),
              "el runtime de Fibonacci se inicializa");
   fibBroker.SetQuote(1.10000, 1.10002);
   fibMarket.RefreshFromTick(1.10000, 1.10002, bar);
   fibRuntime.ProcessTick(bar, 10000.0, 10000.0);

   AssertEqualInt(fibRuntime.OrdersSent(), 1,
                  "Fibonacci abre una posicion con su propia senal");
   AssertEqualInt(fibBroker.Count(), 1, "el broker registra la orden de Fibonacci");
   BasketPosition fibPosition = fibBroker.PositionAt(0);
   AssertEqualInt((int)fibPosition.type, (int)POSITION_TYPE_SELL,
                  "Fibonacci abre SELL y no el BUY de Scalper");

   //--- TrendMaster seleccionada: su rama es NONE y no consume presupuesto.
   CTestBrokerState trendBroker;
   trendBroker.m_magic  = 111;
   trendBroker.m_symbol = "TEST5";

   CTestBrokerBackend trendBackend(&trendBroker);
   CTestBrokerBasketSource trendBaskets(&trendBroker);
   CTestBarSource trendBars;
   trendBars.Set(bar, 1.1000, 1.0990);
   trendBars.SetRsi(80.0);

   InstrumentInfo trendInstrument = MakeFiveDigitInstrument();
   CMarketContext trendMarket;
   trendMarket.InitFromInstrument(trendInstrument, 3.0, 25.0);

   CTestAccountProvider trendAccounts(1000.0, 10.0);
   CExecutor trendExecutor;
   trendExecutor.Init(&trendBackend, &trendAccounts, MakeRuntimeLimits(),
                      MakeExecutionConfig(3, 0, 1000));

   CTestDailyStore trendStore;
   CDailyLossGuard trendDaily;
   trendDaily.Init(&trendStore, 123456, 4.0);

   RuntimeConfig trendConfig = MakeRuntimeConfig();
   trendConfig.strategy = LM_STRATEGY_TREND_MASTER;

   CLmRuntime trendRuntime;
   AssertTrue(trendRuntime.Init(&trendMarket, &trendBaskets, &trendBars,
                                &trendExecutor, &trendDaily, trendConfig),
              "el runtime de TrendMaster se inicializa");
   trendBroker.SetQuote(1.10000, 1.10002);
   trendMarket.RefreshFromTick(1.10000, 1.10002, bar);
   trendRuntime.ProcessTick(bar, 10000.0, 10000.0);

   AssertEqualInt(trendRuntime.OrdersSent(), 0,
                  "TrendMaster con senal NONE no abre posiciones");
   AssertEqualInt(trendBroker.Count(), 0,
                  "el broker no recibe la senal de las otras estrategias");
   BasketState trendBasketState = trendRuntime.Basket();
   AssertEqualDouble(trendBasketState.volume, 0.0, 1e-9,
                     "TrendMaster no consume presupuesto de canasta");
  }

//+------------------------------------------------------------------+
//| 9.0 Ajuste del riesgo: rango, paso, limites y redondeo.          |
//+------------------------------------------------------------------+
void TestRiskControlSteps()
  {
   AssertTrue(LmRiskInControlRange(0.5), "0.5 esta dentro del rango");
   AssertTrue(LmRiskInControlRange(4.0), "4.0 esta dentro del rango");
   AssertTrue(LmRiskInControlRange(10.0), "10.0 esta dentro del rango");
   AssertTrue(!LmRiskInControlRange(0.08), "0.08 queda fuera del rango");
   AssertTrue(!LmRiskInControlRange(10.01), "10.01 queda fuera del rango");

   AssertEqualDouble(LmNextRiskPct(4.0, +1), 4.5, 1e-9,
                     "4.0 mas un paso da 4.5");
   AssertEqualDouble(LmNextRiskPct(4.0, -1), 3.5, 1e-9,
                     "4.0 menos un paso da 3.5");
   AssertEqualDouble(LmNextRiskPct(0.5, -1), 0.5, 1e-9,
                     "el minimo no baja");
   AssertEqualDouble(LmNextRiskPct(10.0, +1), 10.0, 1e-9,
                     "el maximo no sube");
   AssertEqualDouble(LmNextRiskPct(0.08, +1), 0.08, 1e-9,
                     "un riesgo fuera de rango no se ajusta");
   AssertEqualDouble(LmNextRiskPct(4.0, 0), 4.0, 1e-9,
                     "una direccion nula no cambia el riesgo");

   AssertTrue(LmRiskCanStep(4.0, +1), "4.0 puede subir");
   AssertTrue(LmRiskCanStep(4.0, -1), "4.0 puede bajar");
   AssertTrue(!LmRiskCanStep(0.5, -1), "0.5 no puede bajar");
   AssertTrue(!LmRiskCanStep(10.0, +1), "10.0 no puede subir");
   AssertTrue(!LmRiskCanStep(0.08, +1), "un riesgo fuera de rango no puede subir");
   AssertTrue(!LmRiskCanStep(0.08, -1), "un riesgo fuera de rango no puede bajar");

   AssertEqualInt(LmRiskButtonDirection(LMROBOT_PANEL_BTN_RISK_DOWN), -1,
                  "el boton '-' se resuelve como direccion negativa");
   AssertEqualInt(LmRiskButtonDirection(LMROBOT_PANEL_BTN_RISK_UP), +1,
                  "el boton '+' se resuelve como direccion positiva");
   AssertEqualInt(LmRiskButtonDirection("LMROBOT_PANEL_0"), 0,
                  "una etiqueta no se confunde con un boton");

   //--- Diecinueve pasos desde 0.5 llegan exactos a 10.0.
   double risk = 0.5;
   for(int i = 0; i < 19; i++)
      risk = LmNextRiskPct(risk, +1);

   AssertEqualDouble(risk, 10.0, 1e-9,
                     "el redondeo a dos decimales no acumula error");
   AssertEqualDouble(LmNextRiskPct(risk, +1), 10.0, 1e-9,
                     "tras llegar al maximo el riesgo queda estable");
  }

//+------------------------------------------------------------------+
//| Estado de panel con una canasta abierta para las pruebas.        |
//+------------------------------------------------------------------+
DashboardState MakeTestDashboardState()
  {
   BasketPosition positions[2];
   positions[0] = MakeBasketPosition(1, 111, "TEST5", POSITION_TYPE_BUY, 0.01, 1.1000,
                                     D'2026.01.02 10:00:00');
   positions[1] = MakeBasketPosition(2, 111, "TEST5", POSITION_TYPE_BUY, 0.02, 1.1010,
                                     D'2026.01.02 10:05:00');

   BasketState basket;
   LmAggregateBasket("TEST5", 111, positions, basket);

   InstrumentInfo instrument = MakeFiveDigitInstrument();
   RiskConfig risk = LmDefaultRiskConfig();
   risk.riskMode = LM_RISK_MANUAL;

   DailyLossState daily;
   LmResetDailyLossState(daily);
   daily.initialized = true;
   daily.startEquity = 10000.0;
   daily.equity      = 9950.0;

   return(LmBuildDashboardState(LM_STRATEGY_SCALPER_PRO, basket, risk,
                                daily, instrument, 10000.0, 9950.0));
  }

//+------------------------------------------------------------------+
//| 9.1 Panel con los siete campos y su actualizacion.               |
//+------------------------------------------------------------------+
void TestDashboardFields()
  {
   DashboardState state = MakeTestDashboardState();

   AssertTrue(state.valid, "el estado del panel es valido");
   AssertEqualInt((int)state.strategy, (int)LM_STRATEGY_SCALPER_PRO,
                  "el panel expone la estrategia activa");
   AssertEqualInt((int)state.direction, (int)BASKET_DIRECTION_BUY,
                  "el panel expone la direccion de la canasta");
   AssertEqualDouble(state.volume, 0.03, 1e-9, "el panel expone el volumen total");
   AssertEqualDouble(state.averagePrice, 1.1006666667, 1e-9,
                     "el panel expone el promedio ponderado");
   AssertEqualDouble(state.nextGridPrice, 1.0988, 1e-9,
                     "el panel expone el proximo nivel de grid");
   AssertEqualDouble(state.budgetUsedPct, 6.0, 1e-9,
                     "el panel expone el presupuesto de riesgo consumido");
   AssertEqualDouble(state.dailyPnl, -50.0, 1e-9,
                     "el panel expone el PnL del dia");

   string lines[];
   AssertEqualInt(LmDashboardLines(state, "TEST5", lines), 9,
                  "el panel contiene el titulo, los siete campos y el riesgo");
   AssertTrue(StringFind(lines[1], "Scalper Pro") >= 0,
              "el panel muestra la estrategia");
   AssertTrue(StringFind(lines[2], "Compra") >= 0,
              "el panel muestra la direccion");
   AssertTrue(StringFind(lines[3], "0.03") >= 0,
              "el panel muestra el volumen");
   AssertTrue(StringFind(lines[4], "1.10067") >= 0,
              "el panel muestra el promedio");
   AssertTrue(StringFind(lines[5], "1.09880") >= 0,
              "el panel muestra el proximo grid");
   AssertTrue(StringFind(lines[6], "6.0%") >= 0,
              "el panel muestra el presupuesto usado");
   AssertTrue(StringFind(lines[7], "-50.00") >= 0,
              "el panel muestra el PnL del dia");
   AssertTrue(StringFind(lines[8], "Riesgo: 0.50%") >= 0,
              "el panel muestra el riesgo vivo en la ultima linea");

   //--- La canasta se cierra y la estrategia cambia: el panel se actualiza.
   BasketPosition none[];
   BasketState flat;
   LmAggregateBasket("TEST5", 111, none, flat);

   DailyLossState daily;
   LmResetDailyLossState(daily);
   daily.initialized = true;
   daily.startEquity = 10000.0;
   daily.equity      = 10000.0;

   InstrumentInfo instrument = MakeFiveDigitInstrument();
   RiskConfig risk = LmDefaultRiskConfig();
   DashboardState updated = LmBuildDashboardState(LM_STRATEGY_TREND_MASTER, flat, risk,
                                                  daily, instrument, 10000.0, 10000.0);

   string updatedLines[];
   LmDashboardLines(updated, "TEST5", updatedLines);

   AssertTrue(StringFind(updatedLines[1], "TrendMaster") >= 0,
              "el panel actualiza la estrategia activa");
   AssertTrue(StringFind(updatedLines[2], "Plana") >= 0,
              "el panel actualiza la direccion a plana");
   AssertTrue(StringFind(updatedLines[3], "0.00") >= 0,
              "el panel actualiza el volumen a cero");
   AssertTrue(StringFind(updatedLines[6], "0.0%") >= 0,
              "el panel actualiza el presupuesto consumido a cero");
   AssertTrue(StringFind(updatedLines[7], "0.00") >= 0,
              "el panel actualiza el PnL del dia a cero");
  }

//+------------------------------------------------------------------+
//| 9.2 Dirty flag: sin cambios no se redibuja.                      |
//+------------------------------------------------------------------+
class CTestDashboardRenderer : public IDashboardRenderer
  {
private:
   int            m_renders;
   int            m_clears;
   DashboardState m_last;
   string         m_lastSymbol;

public:
   CTestDashboardRenderer()
     {
      m_renders    = 0;
      m_clears     = 0;
      m_lastSymbol = "";
      LmResetDashboardState(m_last);
     }

   virtual void Render(const DashboardState &state, const string symbol)
     {
      m_renders++;
      m_last       = state;
      m_lastSymbol = symbol;
     }

   virtual void Clear()
     {
      m_clears++;
      m_lastSymbol = "";
      LmResetDashboardState(m_last);
     }

   int Renders()       { return(m_renders); }
   int Clears()        { return(m_clears); }
   DashboardState Last() { return(m_last); }
   string LastSymbol() { return(m_lastSymbol); }
  };

void TestDashboardDirtyFlag()
  {
   CTestDashboardRenderer renderer;
   CDashboard dashboard;

   AssertTrue(dashboard.Init(&renderer), "el panel se inicializa con un renderer");
   AssertEqualInt(dashboard.RenderCount(), 0, "el panel arranca sin redibujos");

   DashboardState state = MakeTestDashboardState();

   AssertTrue(dashboard.Update(state, "TEST5"), "el primer estado dibuja el panel");
   AssertEqualInt(renderer.Renders(), 1, "el renderer recibe el primer dibujo");
   AssertEqualInt(dashboard.RenderCount(), 1, "el contador de redibujos arranca en uno");

   AssertTrue(!dashboard.Update(state, "TEST5"), "un estado sin cambios no redibuja");
   AssertEqualInt(dashboard.SkippedCount(), 1, "el tick sin cambios se omite");
   AssertEqualInt(renderer.Renders(), 1, "el renderer no recibe un dibujo extra");

   for(int i = 0; i < 10; i++)
      dashboard.Update(state, "TEST5");

   AssertEqualInt(dashboard.RenderCount(), 1,
                  "diez ticks sin cambios no incrementan redibujos");
   AssertEqualInt(renderer.Renders(), 1,
                  "diez ticks sin cambios no llegan al renderer");
   AssertEqualInt(dashboard.SkippedCount(), 11,
                  "los once ticks sin cambios se contabilizan como omitidos");

   state.dailyPnl = state.dailyPnl - 1.0;
   AssertTrue(dashboard.Update(state, "TEST5"), "un cambio de PnL redibuja el panel");
   AssertEqualInt(renderer.Renders(), 2, "el renderer recibe el dibujo actualizado");
   AssertEqualDouble(renderer.Last().dailyPnl, -51.0, 1e-9,
                     "el renderer recibe el estado actualizado");

   //--- Un cambio solo de riesgo debe forzar el redibujo.
   state.riskPct     = 4.5;
   state.riskInRange = true;
   state.canIncrease = true;
   AssertTrue(dashboard.Update(state, "TEST5"),
              "un cambio solo de riesgo redibuja el panel");
   AssertEqualInt(renderer.Renders(), 3,
                  "el renderer recibe el dibujo con el riesgo actualizado");
   AssertEqualDouble(renderer.Last().riskPct, 4.5, 1e-9,
                     "el renderer recibe el riesgo actualizado");

   dashboard.Clear();
   AssertEqualInt(renderer.Clears(), 1, "la desinicializacion limpia el panel");
   AssertTrue(!dashboard.HasState(), "tras limpiar no queda estado dibujado");
  }

//+------------------------------------------------------------------+
//| 9.3 Limpieza de objetos y comentario en la desinicializacion.    |
//+------------------------------------------------------------------+
void TestDashboardCleanup()
  {
   DashboardState state = MakeTestDashboardState();
   CChartDashboardRenderer renderer;

   Comment("LMROBOT_TEST_COMMENT");
   renderer.Render(state, "TEST5");
   AssertEqualInt(renderer.ObjectCount(), 12,
                  "el panel crea nueve etiquetas y tres botones");

   AssertTrue(ObjectFind(0, LMROBOT_PANEL_BTN_RISK_DOWN) >= 0,
              "el panel crea el boton de bajar riesgo");
   AssertTrue(ObjectFind(0, LMROBOT_PANEL_BTN_RISK_MODE) >= 0,
              "el panel crea el boton de modo");
   AssertTrue(ObjectFind(0, LMROBOT_PANEL_BTN_RISK_UP) >= 0,
              "el panel crea el boton de subir riesgo");

   renderer.Clear();
   AssertEqualInt(renderer.ObjectCount(), 0,
                  "la desinicializacion elimina todos los objetos del EA");
   AssertTrue(ObjectFind(0, LMROBOT_PANEL_BTN_RISK_DOWN) < 0,
              "la limpieza elimina el boton de bajar riesgo");
   AssertTrue(ObjectFind(0, LMROBOT_PANEL_BTN_RISK_MODE) < 0,
              "la limpieza elimina el boton de modo");
   AssertTrue(ObjectFind(0, LMROBOT_PANEL_BTN_RISK_UP) < 0,
              "la limpieza elimina el boton de subir riesgo");

   string comment = ChartGetString(0, CHART_COMMENT);
   AssertTrue(StringLen(comment) == 0 && comment != "LMROBOT_TEST_COMMENT",
              "la desinicializacion deja el comentario del grafico limpio");
  }

//+------------------------------------------------------------------+
//| 10.4 El panel no crea objetos nuevos en ticks posteriores.       |
//+------------------------------------------------------------------+
void TestDashboardNoObjectsPerTick()
  {
   DashboardState state = MakeTestDashboardState();
   CChartDashboardRenderer renderer;

   renderer.Render(state, "TEST5");
   AssertEqualInt(renderer.CreatedCount(), 12,
                  "el primer render crea nueve etiquetas y tres botones");
   AssertEqualInt(renderer.ObjectCount(), 12,
                  "el panel queda con doce objetos");

   //--- El boton deshabilitado usa color atenuado y el habilitado no.
   AssertTrue(ObjectGetInteger(0, LMROBOT_PANEL_BTN_RISK_DOWN,
                               OBJPROP_BGCOLOR) == (long)clrDimGray,
              "el boton '-' arranca atenuado en el minimo");
   AssertTrue(ObjectGetInteger(0, LMROBOT_PANEL_BTN_RISK_UP,
                               OBJPROP_BGCOLOR) == (long)clrSlateGray,
              "el boton '+' arranca habilitado");
   AssertTrue(ObjectGetInteger(0, LMROBOT_PANEL_BTN_RISK_MODE,
                               OBJPROP_BGCOLOR) == (long)clrSlateGray,
              "el boton de modo arranca habilitado");

   for(int i = 0; i < 10; i++)
     {
      state.dailyPnl = state.dailyPnl - 1.0;
      renderer.Render(state, "TEST5");
     }

   AssertEqualInt(renderer.CreatedCount(), 12,
                  "diez ticks con cambios no crean objetos nuevos");
   AssertEqualInt(renderer.ObjectCount(), 12,
                  "diez ticks con cambios mantienen doce objetos");

   //--- Un render posterior reutiliza los botones y actualiza su estado.
   state.riskPct     = 4.5;
   state.riskInRange = true;
   state.canDecrease = true;
   state.canIncrease = true;
   renderer.Render(state, "TEST5");

   AssertEqualInt(renderer.CreatedCount(), 12,
                  "el cambio de riesgo reutiliza los botones existentes");
   AssertTrue(ObjectGetInteger(0, LMROBOT_PANEL_BTN_RISK_DOWN,
                               OBJPROP_BGCOLOR) == (long)clrSlateGray,
              "el boton '-' se actualiza a habilitado");
   AssertTrue(ObjectGetInteger(0, LMROBOT_PANEL_BTN_RISK_DOWN,
                               OBJPROP_STATE) == 0,
              "los botones quedan sin seleccion");

   renderer.Clear();
   AssertEqualInt(renderer.ObjectCount(), 0,
                  "la prueba deja el grafico sin objetos del EA");
  }

//+------------------------------------------------------------------+
//| 11.1 Seleccion ALL: enum, lista de estrategias y magic.          |
//+------------------------------------------------------------------+
void TestStrategyAllSelection()
  {
   AssertTrue(LmStrategyIsValid(LM_STRATEGY_ALL),
              "ALL es una estrategia valida");

   AssertTrue(LmStrategyName(LM_STRATEGY_ALL) == "Portafolio ALL",
              "ALL tiene un nombre estable");

   ENUM_LM_STRATEGY list[];
   AssertEqualInt(LmResolveStrategyList(LM_STRATEGY_ALL, list), 3,
                  "ALL resuelve las tres estrategias");
   AssertEqualInt((int)list[0], (int)LM_STRATEGY_SCALPER_PRO,
                  "ALL incluye Scalper Pro");
   AssertEqualInt((int)list[1], (int)LM_STRATEGY_FIBONACCI_FOCUS,
                  "ALL incluye Fibonacci Focus");
   AssertEqualInt((int)list[2], (int)LM_STRATEGY_TREND_MASTER,
                  "ALL incluye TrendMaster");

   AssertEqualInt(LmResolveStrategyList(LM_STRATEGY_SCALPER_PRO, list), 1,
                  "una estrategia resuelve una sola");
   AssertEqualInt((int)list[0], (int)LM_STRATEGY_SCALPER_PRO,
                  "la lista unica conserva la estrategia elegida");

   AssertTrue(LmStrategyMagic(202611030, LM_STRATEGY_ALL, 2) == 202611032,
              "ALL asigna MagicNumber + indice");
   AssertTrue(LmStrategyMagic(202611030, LM_STRATEGY_SCALPER_PRO, 2) == 202611030,
              "modo unico conserva el magic base");

   AssertEqualInt((int)LmEvaluateStrategy(LM_STRATEGY_ALL, 1.1000, 1.0990,
                                          1.1010, 1.0980, true, 50.0),
                  (int)SIGNAL_NONE,
                  "ALL no es una senal: el runtime itera las estrategias");
  }

//+------------------------------------------------------------------+
//| 11.4 Presupuesto agregado de la instancia.                       |
//+------------------------------------------------------------------+
void TestAggregateRiskCaps()
  {
   AssertEqualDouble(LmAggregateLossBudget(10000.0, 6.0), 600.0, 1e-9,
                     "el presupuesto agregado es 6% del balance");

   AssertTrue(LmFitsAggregateBudget(600.0, 10000.0, 6.0),
              "la perdida agregada en el limite se acepta");
   AssertTrue(!LmFitsAggregateBudget(601.0, 10000.0, 6.0),
              "la perdida agregada por encima del limite se rechaza");

   AssertTrue(LmFitsAggregateVolume(0.90, 0.90),
              "el volumen agregado en el limite se acepta");
   AssertTrue(!LmFitsAggregateVolume(0.91, 0.90),
              "el volumen agregado por encima del limite se rechaza");
  }

//+------------------------------------------------------------------+
//| 11.5 Panel de portafolio: una fila por estrategia + agregado.    |
//+------------------------------------------------------------------+
void TestPortfolioDashboard()
  {
   StrategyView views[LM_MAX_ACTIVE_STRATEGIES];

   views[0].strategy = LM_STRATEGY_SCALPER_PRO;
   LmResetBasket(views[0].basket, "TEST5", 111);
   views[0].basket.count        = 1;
   views[0].basket.volume       = 0.10;
   views[0].basket.averagePrice = 1.10000;
   views[0].basket.direction    = BASKET_DIRECTION_BUY;

   views[1].strategy = LM_STRATEGY_FIBONACCI_FOCUS;
   LmResetBasket(views[1].basket, "TEST5", 112);
   views[1].basket.count        = 1;
   views[1].basket.volume       = 0.20;
   views[1].basket.averagePrice = 1.10500;
   views[1].basket.direction    = BASKET_DIRECTION_SELL;

   RiskConfig risk = LmDefaultRiskConfig();
   DailyLossState daily;
   LmResetDailyLossState(daily);
   daily.initialized = true;
   daily.startEquity = 10000.0;

   DashboardState state = LmBuildPortfolioDashboardState(views, 2, risk, daily,
                                                          MakeFiveDigitInstrument(),
                                                          10000.0, 9900.0);

   AssertTrue(state.portfolio, "el panel detecta el modo portafolio");
   AssertEqualInt(state.rowCount, 2, "el panel muestra una fila por estrategia");
   AssertEqualDouble(state.aggregate.volume, 0.30, 1e-9,
                     "la fila agregada suma el volumen de las estrategias");
   AssertTrue(state.aggregate.mixed,
              "el agregado marca canastas de direcciones opuestas");
   AssertEqualDouble(state.dailyPnl, -100.0, 1e-9,
                     "el panel conserva el PnL del dia");

   string lines[];
   AssertEqualInt(LmDashboardLines(state, "TEST5", lines), 6,
                  "portafolio de dos estrategias ocupa seis lineas");
   AssertTrue(StringFind(lines[5], "Riesgo: 0.50%") >= 0,
              "el portafolio muestra el riesgo vivo al final");

   CChartDashboardRenderer renderer;
   renderer.Render(state, "TEST5");
   AssertEqualInt(renderer.ObjectCount(), 9,
                  "portafolio de dos estrategias usa seis lineas y tres botones");
   renderer.Clear();
  }

//+------------------------------------------------------------------+
//| 11.2/11.3 Canastas independientes y rechazo agregado.            |
//+------------------------------------------------------------------+
void TestRuntimePortfolio()
  {
   CTestBrokerState broker;
   broker.m_magic  = 111;
   broker.m_symbol = "TEST5";

   CTestBrokerBackend backend(&broker);
   CTestBrokerBasketSource baskets(&broker);
   CTestBarSource bars;

   InstrumentInfo instrument = MakeFiveDigitInstrument();
   CMarketContext market;
   AssertTrue(market.InitFromInstrument(instrument, 3.0, 25.0),
              "el portafolio inicia con un instrumento de prueba");

   CTestAccountProvider accounts(1000.0, 10.0);
   CExecutor executor;
   AssertTrue(executor.Init(&backend, &accounts, MakeRuntimeLimits(),
                            MakeExecutionConfig(3, 0, 1000)),
              "el portafolio inicia con un ejecutor simulado");

   CTestDailyStore store;
   CDailyLossGuard daily;
   AssertTrue(daily.Init(&store, 123456, 4.0),
              "el portafolio inicia con una guarda diaria de prueba");

   RuntimeConfig config = MakeRuntimeConfig();
   config.strategy = LM_STRATEGY_ALL;

   //--- El tope agregado deja pasar solo dos de las tres canastas.
   config.risk.maxAggregateVolume = 0.25;

   CLmRuntime runtime;
   AssertTrue(runtime.Init(&market, &baskets, &bars, &executor, &daily, config),
              "el runtime de portafolio se inicializa");
   AssertEqualInt(runtime.StrategyCount(), 3,
                  "ALL mantiene tres estrategias activas");

   datetime bar1 = D'2026.01.02 10:00:00';
   bars.Set(bar1, 1.1000, 1.0990);
   bars.SetRsi(50.0);
   broker.SetQuote(1.10000, 1.10002);
   market.RefreshFromTick(1.10000, 1.10002, bar1);

   AssertTrue(runtime.ProcessTick(bar1, 10000.0, 10000.0),
              "el primer tick del portafolio se procesa");

   AssertEqualInt(runtime.Evaluations(), 3,
                  "las tres estrategias evaluan una vez por barra");
   AssertEqualInt(runtime.OrdersSent(), 2,
                  "el tope agregado rechaza la tercera apertura");
   AssertEqualInt(broker.Count(), 2,
                  "solo dos canastas quedan abiertas");

   int scalper = 0;
   int fibonacci = 0;
   int trend = 0;

   for(int i = 0; i < broker.Count(); i++)
     {
      long magic = broker.PositionAt(i).magic;
      if(magic == 111)
         scalper++;
      else if(magic == 112)
         fibonacci++;
      else if(magic == 113)
         trend++;
     }

   AssertEqualInt(scalper, 1, "Scalper usa MagicNumber + 0");
   AssertEqualInt(fibonacci, 1, "Fibonacci usa MagicNumber + 1");
   AssertEqualInt(trend, 0, "Trend no abre por el tope agregado");

   RuntimeResult result = runtime.Result();
   AssertEqualInt(result.strategyCount, 3,
                  "el resultado expone las tres estrategias");
   AssertEqualDouble(result.maxAggregateVolume, 0.20, 1e-9,
                     "la exposicion agregada observada es dos canastas");

   //--- Un rechazo agregado no debe bloquear la gestion existente.
   broker.ClearProtection();
   market.RefreshFromTick(1.10000, 1.10002, bar1 + 1);
   runtime.ProcessTick(bar1 + 1, 10000.0, 10000.0);

   for(int i = 0; i < broker.Count(); i++)
     {
      AssertTrue(broker.PositionAt(i).sl > 0.0,
                 "la canasta abierta conserva su stop loss");
      AssertTrue(broker.PositionAt(i).tp > 0.0,
                 "la canasta abierta conserva su take profit");
     }

   AssertEqualInt(runtime.Evaluations(), 3,
                  "la misma barra no reevalua las tres senales");
   AssertEqualInt(runtime.OrdersSent(), 2,
                  "la misma barra no duplica las aperturas");
  }

//+------------------------------------------------------------------+
//| 11.2 Canastas independientes por magic en modo ALL.              |
//+------------------------------------------------------------------+
void TestRuntimePortfolioIndependence()
  {
   CTestBrokerState broker;
   broker.m_magic  = 111;
   broker.m_symbol = "TEST5";

   CTestBrokerBackend backend(&broker);
   CTestBrokerBasketSource baskets(&broker);
   CTestBarSource bars;

   InstrumentInfo instrument = MakeFiveDigitInstrument();
   CMarketContext market;
   AssertTrue(market.InitFromInstrument(instrument, 3.0, 25.0),
              "la independencia inicia con un instrumento de prueba");

   CTestAccountProvider accounts(10000.0, 10.0);
   CExecutor executor;
   AssertTrue(executor.Init(&backend, &accounts, MakeRuntimeLimits(),
                            MakeExecutionConfig(3, 0, 1000)),
              "la independencia inicia con un ejecutor simulado");

   CTestDailyStore store;
   CDailyLossGuard daily;
   AssertTrue(daily.Init(&store, 123456, 4.0),
              "la independencia inicia con una guarda diaria de prueba");

   RuntimeConfig config = MakeRuntimeConfig();
   config.strategy = LM_STRATEGY_ALL;

   CLmRuntime runtime;
   AssertTrue(runtime.Init(&market, &baskets, &bars, &executor, &daily, config),
              "ALL inicializa con las tres estrategias");

   //--- Un valor fuera de rango no debe inicializar el runtime.
   RuntimeConfig invalid = config;
   invalid.strategy = (ENUM_LM_STRATEGY)99;
   CLmRuntime invalidRuntime;
   AssertTrue(!invalidRuntime.Init(&market, &baskets, &bars, &executor, &daily, invalid),
              "un valor de Strategy fuera de rango no inicializa");

   datetime bar1 = D'2026.01.02 10:00:00';
   bars.Set(bar1, 1.1000, 1.0990);
   bars.SetRsi(50.0);
   broker.SetQuote(1.10000, 1.10002);
   market.RefreshFromTick(1.10000, 1.10002, bar1);

   AssertTrue(runtime.ProcessTick(bar1, 10000.0, 10000.0),
              "el tick con presupuesto suficiente se procesa");
   AssertEqualInt(runtime.OrdersSent(), 3,
                  "las tres estrategias abren su propia canasta");
   AssertEqualInt(broker.Count(), 3,
                  "el broker registra tres canastas separadas");

   for(int i = 0; i < 3; i++)
     {
      ENUM_LM_STRATEGY strategy = LM_STRATEGY_SCALPER_PRO;
      BasketState basket;
      long magic = 0;

      AssertTrue(runtime.StrategyAt(i, strategy, basket, magic),
                 "la estrategia activa es legible por indice");
      AssertTrue(magic == (long)(config.magic + i),
                 "cada estrategia conserva su MagicNumber + indice");
      AssertEqualInt(basket.count, 1,
                     "cada canasta contiene solo sus propias posiciones");
      AssertEqualDouble(basket.volume, 0.10, 1e-9,
                        "cada canasta conserva su propio volumen");
     }

   RuntimeResult result = runtime.Result();
   AssertEqualDouble(result.maxAggregateVolume, 0.30, 1e-9,
                     "el agregado suma las tres canastas independientes");
  }

//+------------------------------------------------------------------+
//| 12.0 Configuracion por defecto de la modalidad de riesgo.        |
//+------------------------------------------------------------------+
void TestRiskModeConfig()
  {
   RiskConfig config = LmDefaultRiskConfig();

   AssertEqualInt((int)config.riskMode, (int)LM_RISK_AUTO,
                  "la configuracion por defecto arranca en modo automatico");
   AssertEqualDouble(config.riskBasePct, config.riskPct, 1e-9,
                     "la base automatica arranca igual al riesgo configurado");
   AssertEqualDouble(config.autoRiskMaxPct, 6.0, 1e-9,
                     "el tope automatico por defecto es 6.0%");

   config.riskMode = LM_RISK_MANUAL;
   AssertEqualInt((int)config.riskMode, (int)LM_RISK_MANUAL,
                  "el control manual se fija explicitamente en los tests");

   DashboardState panel = MakeTestDashboardState();
   AssertEqualInt((int)panel.riskMode, (int)LM_RISK_MANUAL,
                  "el panel de prueba usa la modalidad manual explicita");
   AssertEqualInt((int)MakeRuntimeConfig().risk.riskMode, (int)LM_RISK_MANUAL,
                  "el runtime de prueba usa la modalidad manual explicita");
  }

//+------------------------------------------------------------------+
//| 12.1 Riesgo automatico: volatilidad, tope, redondeo y sin ATR.   |
//+------------------------------------------------------------------+
void TestAutoRiskPct()
  {
   //--- Volatilidad actual por encima de la media: factor 0.5.
   AssertEqualDouble(LmAutoRiskPct(4.0, 20.0, 10.0, 0.3, 2.0, 6.0),
                     2.0, 1e-9,
                     "con ATR actual alto el riesgo automatico baja");

   //--- Volatilidad actual por debajo de la media: factor 2.0, tope 6.
   AssertEqualDouble(LmAutoRiskPct(4.0, 10.0, 20.0, 0.3, 2.0, 6.0),
                     6.0, 1e-9,
                     "con ATR actual bajo el riesgo sube hasta el tope 6.0");

   //--- Tope personalizado.
   AssertEqualDouble(LmAutoRiskPct(4.0, 10.0, 20.0, 0.3, 2.0, 3.0),
                     3.0, 1e-9,
                     "el tope personalizado 3.0 recorta el riesgo automatico");

   //--- Base por encima del tope.
   AssertEqualDouble(LmAutoRiskPct(8.0, 10.0, 10.0, 0.3, 2.0, 6.0),
                     6.0, 1e-9,
                     "una base por encima del tope queda en el tope");

   //--- Minimo fijo y redondeo a dos decimales.
   AssertEqualDouble(LmAutoRiskPct(0.1, 10.0, 10.0, 0.3, 2.0, 6.0),
                     0.5, 1e-9,
                     "el riesgo automatico no baja de 0.5");
   AssertEqualDouble(LmAutoRiskPct(2.345, 0.0, 0.0, 0.3, 2.0, 6.0),
                     2.35, 1e-9,
                     "el riesgo automatico se redondea a dos decimales");

   //--- Sin lectura valida de ATR el factor es 1.0.
   AssertEqualDouble(LmAutoRiskPct(4.0, 0.0, 0.0, 0.3, 2.0, 6.0),
                     4.0, 1e-9,
                     "sin ATR el riesgo automatico queda en la base");

   //--- El tope se sanea a 0.5-10.0 dentro de la funcion pura.
   AssertEqualDouble(LmAutoRiskPct(12.0, 10.0, 10.0, 0.3, 2.0, 20.0),
                     10.0, 1e-9,
                     "un tope por encima de 10 se sanea a 10");
   AssertEqualDouble(LmAutoRiskPct(4.0, 10.0, 10.0, 0.3, 2.0, 0.1),
                     0.5, 1e-9,
                     "un tope por debajo de 0.5 se sanea a 0.5");
  }

//+------------------------------------------------------------------+
//| 12.2 El runtime automatico sigue al ATR y rechaza el ajuste      |
//| manual.                                                          |
//+------------------------------------------------------------------+
void TestRuntimeAutoRisk()
  {
   CTestBrokerState broker;
   broker.m_magic  = 111;
   broker.m_symbol = "TEST5";

   CTestBrokerBackend backend(&broker);
   CTestBrokerBasketSource baskets(&broker);
   CTestBarSource bars;

   InstrumentInfo instrument = MakeFiveDigitInstrument();
   CMarketContext market;
   AssertTrue(market.InitFromInstrument(instrument, 3.0, 25.0),
              "el runtime automatico inicia con un instrumento de prueba");

   CTestAccountProvider accounts(1000.0, 10.0);
   CExecutor executor;
   AssertTrue(executor.Init(&backend, &accounts, MakeRuntimeLimits(),
                            MakeExecutionConfig(3, 0, 1000)),
              "el runtime automatico inicia con un ejecutor simulado");

   CTestDailyStore store;
   CDailyLossGuard daily;
   AssertTrue(daily.Init(&store, 123456, 4.0),
              "el runtime automatico inicia con una guarda diaria");

   RuntimeConfig config = MakeRuntimeConfig();
   config.risk.riskMode       = LM_RISK_AUTO;
   config.risk.riskPct        = 4.0;
   config.risk.riskBasePct    = 4.0;
   config.risk.autoRiskMaxPct = 6.0;

   CLmRuntime runtime;
   AssertTrue(runtime.Init(&market, &baskets, &bars, &executor, &daily, config),
              "el runtime automatico se inicializa");

   datetime bar = D'2026.01.02 10:00:00';
   market.RefreshFromValues(1.10000, 1.10002, bar, true, 20.0, 10.0);
   runtime.ProcessTick(bar, 10000.0, 10000.0);
   AssertEqualDouble(runtime.Config().risk.riskPct, 2.0, 1e-9,
                     "el riesgo automatico baja cuando el ATR actual supera la media");

   AssertTrue(!runtime.SetRiskPct(9.0),
              "el ajuste manual no pisa el riesgo en modo automatico");
   AssertEqualDouble(runtime.Config().risk.riskPct, 2.0, 1e-9,
                     "el riesgo automatico conserva su valor tras el intento manual");

   market.RefreshFromValues(1.10000, 1.10002, bar + 1, true, 10.0, 20.0);
   runtime.ProcessTick(bar + 1, 10000.0, 10000.0);
   AssertEqualDouble(runtime.Config().risk.riskPct, 6.0, 1e-9,
                     "el riesgo automatico sube hasta el tope configurado");

   market.RefreshFromValues(1.10000, 1.10002, bar + 2, false, 0.0, 0.0);
   runtime.ProcessTick(bar + 2, 10000.0, 10000.0);
   AssertEqualDouble(runtime.Config().risk.riskPct, 4.0, 1e-9,
                     "sin ATR el riesgo automatico vuelve a la base");
  }

//+------------------------------------------------------------------+
//| 12.3 Conmutacion de modalidad con continuidad del riesgo.        |
//+------------------------------------------------------------------+
void TestRuntimeRiskModeSwitch()
  {
   CTestBrokerState broker;
   broker.m_magic  = 111;
   broker.m_symbol = "TEST5";

   CTestBrokerBackend backend(&broker);
   CTestBrokerBasketSource baskets(&broker);
   CTestBarSource bars;

   InstrumentInfo instrument = MakeFiveDigitInstrument();
   CMarketContext market;
   AssertTrue(market.InitFromInstrument(instrument, 3.0, 25.0),
              "el runtime de conmutacion inicia con un instrumento de prueba");

   CTestAccountProvider accounts(1000.0, 10.0);
   CExecutor executor;
   AssertTrue(executor.Init(&backend, &accounts, MakeRuntimeLimits(),
                            MakeExecutionConfig(3, 0, 1000)),
              "el runtime de conmutacion inicia con un ejecutor simulado");

   CTestDailyStore store;
   CDailyLossGuard daily;
   AssertTrue(daily.Init(&store, 123456, 4.0),
              "el runtime de conmutacion inicia con una guarda diaria");

   RuntimeConfig config = MakeRuntimeConfig();
   config.risk.riskMode       = LM_RISK_AUTO;
   config.risk.riskPct        = 4.0;
   config.risk.riskBasePct    = 4.0;
   config.risk.autoRiskMaxPct = 6.0;

   CLmRuntime runtime;
   AssertTrue(runtime.Init(&market, &baskets, &bars, &executor, &daily, config),
              "el runtime de conmutacion se inicializa");

   datetime bar = D'2026.01.02 10:00:00';
   market.RefreshFromValues(1.10000, 1.10002, bar, true, 10.0, 10.0);
   runtime.ProcessTick(bar, 10000.0, 10000.0);

   AssertTrue(runtime.SetRiskMode(LM_RISK_MANUAL),
              "se puede pasar a manual en caliente");
   AssertEqualDouble(runtime.Config().risk.riskPct, 4.0, 1e-9,
                     "auto -> manual conserva el ultimo riesgo automatico");

   AssertTrue(runtime.SetRiskPct(5.0), "en manual se ajusta el riesgo vivo");
   AssertEqualDouble(runtime.Config().risk.riskPct, 5.0, 1e-9,
                     "el ajuste manual queda como riesgo vivo");

   market.RefreshFromValues(1.10000, 1.10002, bar + 1, true, 20.0, 10.0);
   AssertTrue(runtime.SetRiskMode(LM_RISK_AUTO),
              "se puede volver a automatico en caliente");
   AssertEqualDouble(runtime.Config().risk.riskBasePct, 5.0, 1e-9,
                     "manual -> auto captura el riesgo vivo como base");
   AssertEqualDouble(runtime.Config().risk.riskPct, 2.5, 1e-9,
                     "la base se ajusta con el ATR vigente al conmutar");

   market.RefreshFromValues(1.10000, 1.10002, bar + 2, true, 20.0, 10.0);
   runtime.ProcessTick(bar + 2, 10000.0, 10000.0);
   AssertEqualDouble(runtime.Config().risk.riskPct, 2.5, 1e-9,
                     "los ticks sucesivos no recomponen la base automatica");

   AssertTrue(runtime.SetRiskMode(LM_RISK_MANUAL),
              "auto -> manual vuelve a habilitar el control");
   AssertEqualDouble(runtime.Config().risk.riskPct, 2.5, 1e-9,
                     "manual parte del ultimo valor automatico");

   AssertTrue(runtime.SetRiskPct(3.0), "el riesgo manual se puede reajustar");
   market.RefreshFromValues(1.10000, 1.10002, bar + 3, true, 10.0, 10.0);
   AssertTrue(runtime.SetRiskMode(LM_RISK_AUTO),
              "una segunda conmutacion a automatico funciona");
   AssertEqualDouble(runtime.Config().risk.riskBasePct, 3.0, 1e-9,
                     "la base se recaptura en cada entrada a automatico");
   AssertEqualDouble(runtime.Config().risk.riskPct, 3.0, 1e-9,
                     "las conmutaciones repetidas conservan la continuidad");

   AssertTrue(!runtime.SetRiskMode((ENUM_LM_RISK_MODE)99),
              "una modalidad desconocida se rechaza");
  }

//+------------------------------------------------------------------+
//| 12.4 En automatico el lote no repite el factor de volatilidad.   |
//+------------------------------------------------------------------+
void TestAutoLotIgnoresVolatility()
  {
   RiskConfig manual = LmDefaultRiskConfig();
   manual.riskMode       = LM_RISK_MANUAL;
   manual.riskPct        = 1.0;
   manual.maxLotPerOrder = 9.0;
   manual.maxVolumePerStrategy = 9.0;
   manual.maxBasketLossPct = 1000.0;

   RiskConfig automatic = manual;
   automatic.riskMode = LM_RISK_AUTO;

   double atrA = 10.0;
   double atrB = 20.0;
   double avgA = 20.0;
   double avgB = 5.0;

   RiskStepPlan manualHigh;
   RiskStepPlan manualLow;
   AssertTrue(LmPlanInitialOrder(manual, 10000.0, 10.0, 0.01, 0.01, 100.0,
                                 manualHigh, atrA, avgA),
              "el plan manual con ATR medio alto se calcula");
   AssertTrue(LmPlanInitialOrder(manual, 10000.0, 10.0, 0.01, 0.01, 100.0,
                                 manualLow, atrB, avgB),
              "el plan manual con ATR medio bajo se calcula");
   AssertTrue(MathAbs(manualHigh.volume - manualLow.volume) > 1e-9,
              "en manual el lote cambia con la volatilidad relativa");

   double autoAvgA = (automatic.riskMode == LM_RISK_AUTO ? atrA : avgA);
   double autoAvgB = (automatic.riskMode == LM_RISK_AUTO ? atrB : avgB);

   RiskStepPlan autoHigh;
   RiskStepPlan autoLow;
   AssertTrue(LmPlanInitialOrder(automatic, 10000.0, 10.0, 0.01, 0.01, 100.0,
                                 autoHigh, atrA, autoAvgA),
              "el plan automatico con el primer ATR se calcula");
   AssertTrue(LmPlanInitialOrder(automatic, 10000.0, 10.0, 0.01, 0.01, 100.0,
                                 autoLow, atrB, autoAvgB),
              "el plan automatico con el segundo ATR se calcula");
   AssertEqualDouble(autoHigh.volume, autoLow.volume, 1e-9,
                     "en automatico el lote no repite el ajuste por volatilidad");
  }

//+------------------------------------------------------------------+
//| 12.5 Panel: modalidad, linea y habitabilidad de los botones.     |
//+------------------------------------------------------------------+
void TestDashboardRiskMode()
  {
   DashboardState manual = MakeTestDashboardState();
   AssertEqualInt((int)manual.riskMode, (int)LM_RISK_MANUAL,
                  "el panel expone la modalidad manual");

   string lines[];
   LmDashboardLines(manual, "TEST5", lines);
   AssertTrue(StringFind(lines[8], "Riesgo: 0.50% (manual)") >= 0,
              "la linea de riesgo incluye la modalidad manual");

   InstrumentInfo instrument = MakeFiveDigitInstrument();
   BasketState flat;
   LmResetBasket(flat, "TEST5", 111);
   DailyLossState daily;
   LmResetDailyLossState(daily);

   RiskConfig automatic = LmDefaultRiskConfig();
   automatic.riskPct = 4.0;

   DashboardState autoState = LmBuildDashboardState(LM_STRATEGY_SCALPER_PRO,
                                                    flat, automatic, daily,
                                                    instrument, 10000.0, 10000.0);
   AssertEqualInt((int)autoState.riskMode, (int)LM_RISK_AUTO,
                  "el panel expone la modalidad automatica");
   AssertTrue(autoState.riskInRange,
              "el riesgo automatico siempre esta en el rango operable");
   AssertTrue(!autoState.canDecrease && !autoState.canIncrease,
              "en automatico los botones +/- quedan deshabilitados");

   LmDashboardLines(autoState, "TEST5", lines);
   AssertTrue(StringFind(lines[8], "Riesgo: 4.00% (auto)") >= 0,
              "la linea de riesgo incluye la modalidad automatica");
   AssertTrue(StringFind(lines[8], "fuera de 0.5-10") < 0,
              "la leyenda de fuera de rango no aplica en automatico");

   RiskConfig outside = LmDefaultRiskConfig();
   outside.riskMode = LM_RISK_MANUAL;
   outside.riskPct  = 0.08;

   DashboardState outsideState = LmBuildDashboardState(LM_STRATEGY_SCALPER_PRO,
                                                       flat, outside, daily,
                                                       instrument, 10000.0, 10000.0);
   AssertTrue(!outsideState.riskInRange,
              "un riesgo manual fuera de rango se reporta");
   AssertTrue(!outsideState.canDecrease && !outsideState.canIncrease,
              "fuera de rango manual los botones quedan deshabilitados");

   LmDashboardLines(outsideState, "TEST5", lines);
   AssertTrue(StringFind(lines[8], "Riesgo: 0.08% (manual)") >= 0,
              "el panel muestra el riesgo manual fuera de rango");
   AssertTrue(StringFind(lines[8], "fuera de 0.5-10") >= 0,
              "la leyenda de fuera de rango aparece solo en manual");

   AssertTrue(LmRiskModeButton(LMROBOT_PANEL_BTN_RISK_MODE),
              "el boton de modo se reconoce por su nombre");
   AssertTrue(!LmRiskModeButton(LMROBOT_PANEL_BTN_RISK_UP),
              "el boton '+' no se confunde con el de modo");
   AssertTrue(LmRiskModeButtonText(LM_RISK_MANUAL) == "Modo: Manual",
              "el boton de modo rotula la modalidad manual");
   AssertTrue(LmRiskModeButtonText(LM_RISK_AUTO) == "Modo: Auto",
              "el boton de modo rotula la modalidad automatica");
  }

//+------------------------------------------------------------------+
//| Casos de prueba. Crece con cada modulo del motor.                |
//+------------------------------------------------------------------+
void RunTests()
  {
   AssertTrue(true, "assert true pasa");
   AssertTrue(!false, "assert negado pasa");
   AssertEqualInt(2 + 2, 4, "aritmetica entera");
   AssertEqualDouble(0.1 + 0.2, 0.3, 0.0000001, "aritmetica de punto flotante");

   TestPipDetection();
   TestPipValuePerLot();
   TestMarketSnapshot();
   TestMarketFlags();
   TestMarketHandles();
   TestBasketScanFiltering();
   TestBasketAverageAndPnl();
   TestBasketLifecycle();
   TestBasketGridStep();
   TestExecutorVolumeNormalization();
   TestExecutorStopLossValidation();
   TestExecutorRetryLimits();
   TestExecutorBasketProtection();
   TestExecutorMarginCheck();
   TestRiskInitialLot();
   TestRiskProjectedLoss();
   TestRiskVolumeAndStepCaps();
   TestRiskVolatilityScaling();
   TestDailyLossGuard();
   TestRiskManagementPriority();
   TestScalperSignal();
   TestFibonacciSignal();
   TestTrendMasterSignal();
   TestSignalCsvExport();
   TestSignalCsvComparator();
   TestAccountAndStrategySelection();
   TestBarGate();
   TestSessionGuard();
   TestRuntimePipeline();
   TestRuntimeSetRiskPct();
   TestRuntimeRiskAffectsNextGrid();
   TestRuntimeGuardsKeepManaging();
   TestStrategySelectionRuntime();
   TestRiskControlSteps();
   TestRiskModeConfig();
   TestAutoRiskPct();
   TestRuntimeAutoRisk();
   TestRuntimeRiskModeSwitch();
   TestAutoLotIgnoresVolatility();
   TestDashboardRiskMode();
   TestDashboardFields();
   TestDashboardDirtyFlag();
   TestDashboardCleanup();
   TestDashboardNoObjectsPerTick();
   TestStrategyAllSelection();
   TestAggregateRiskCaps();
   TestPortfolioDashboard();
   TestRuntimePortfolio();
   TestRuntimePortfolioIndependence();

   if(InjectFailure)
      AssertTrue(false, "fallo inyectado a proposito");
  }

//+------------------------------------------------------------------+
//| Resultado                                                        |
//+------------------------------------------------------------------+
bool Report()
  {
   int total = g_passed + g_failed;
   PrintFormat("----------------------------------------");
   PrintFormat("RESULT: %s  (%d/%d aserciones, %d fallidas)",
               (g_failed == 0 ? "PASS" : "FAIL"), g_passed, total, g_failed);
   PrintFormat("----------------------------------------");
   return (g_failed == 0);
  }

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_passed = 0;
   g_failed = 0;

   RunTests();

   if(!Report())
      return (INIT_FAILED);

   return (INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
  }
//+------------------------------------------------------------------+
