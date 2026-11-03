//+------------------------------------------------------------------+
//|                                                      Runtime.mqh |
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#ifndef LMROBOT_CORE_RUNTIME_MQH
#define LMROBOT_CORE_RUNTIME_MQH

#include "MarketContext.mqh"
#include "BasketState.mqh"
#include "../Execution/Executor.mqh"
#include "../Risk/RiskPolicy.mqh"
#include "../Risk/DailyLossGuard.mqh"
#include "../Risk/SessionGuard.mqh"
#include "../Strategies/Strategy.mqh"

//+------------------------------------------------------------------+
//| Fuente de barras cerradas para la senal.                         |
//+------------------------------------------------------------------+
class ILmBarSource
  {
public:
   virtual bool BarTime(datetime &barTime)                 { barTime = 0; return(false); }
   virtual bool Close(const int shift, double &value)      { value = 0.0; return(false); }
   virtual bool High(const int shift, double &value)       { value = 0.0; return(false); }
   virtual bool Low(const int shift, double &value)        { value = 0.0; return(false); }
   virtual bool Rsi(const int shift, double &value)        { value = 0.0; return(false); }
  };

//+------------------------------------------------------------------+
//| Fuente real de barras e indicadores.                             |
//+------------------------------------------------------------------+
class CLiveBarSource : public ILmBarSource
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_rsiHandle;

   bool ReadRate(const int shift, MqlRates &rate)
     {
      MqlRates rates[];
      if(CopyRates(m_symbol, m_timeframe, shift, 1, rates) <= 0)
         return(false);

      rate = rates[0];
      return(true);
     }

public:
   CLiveBarSource()
     {
      m_symbol    = "";
      m_timeframe = PERIOD_CURRENT;
      m_rsiHandle = INVALID_HANDLE;
     }

   void Init(const string symbol, const ENUM_TIMEFRAMES timeframe, const int rsiHandle)
     {
      m_symbol    = symbol;
      m_timeframe = timeframe;
      m_rsiHandle = rsiHandle;
     }

   virtual bool BarTime(datetime &barTime)
     {
      barTime = iTime(m_symbol, m_timeframe, 0);
      return(barTime > 0);
     }

   virtual bool Close(const int shift, double &value)
     {
      MqlRates rate;
      if(!ReadRate(shift, rate))
         return(false);

      value = rate.close;
      return(true);
     }

   virtual bool High(const int shift, double &value)
     {
      MqlRates rate;
      if(!ReadRate(shift, rate))
         return(false);

      value = rate.high;
      return(true);
     }

   virtual bool Low(const int shift, double &value)
     {
      MqlRates rate;
      if(!ReadRate(shift, rate))
         return(false);

      value = rate.low;
      return(true);
     }

   virtual bool Rsi(const int shift, double &value)
     {
      value = 0.0;

      if(m_rsiHandle == INVALID_HANDLE)
         return(false);

      double buffer[];
      if(CopyBuffer(m_rsiHandle, 0, shift, 1, buffer) <= 0)
         return(false);

      value = buffer[0];
      return(true);
     }
  };

//+------------------------------------------------------------------+
//| Fuente de posiciones de la canasta.                              |
//+------------------------------------------------------------------+
class ILmBasketSource
  {
public:
   virtual bool Scan(const long magic, BasketState &basket)
     {
      LmResetBasket(basket, "", magic);
      return(false);
     }

   virtual int Positions(const long magic, BasketPosition &positions[])
     {
      ArrayResize(positions, 0);
      return(0);
     }
  };

//+------------------------------------------------------------------+
//| Fuente real: posiciones del terminal filtradas por simbolo/magic.|
//+------------------------------------------------------------------+
class CLiveBasketSource : public ILmBasketSource
  {
private:
   string m_symbol;

public:
   CLiveBasketSource()
     {
      m_symbol = "";
     }

   void Init(const string symbol)
     {
      m_symbol = symbol;
     }

   virtual bool Scan(const long magic, BasketState &basket)
     {
      CBasketScanner scanner(m_symbol);
      return(scanner.Scan(magic, basket));
     }

   virtual int Positions(const long magic, BasketPosition &positions[])
     {
      return(LmCollectBasketPositions(m_symbol, magic, positions));
     }
  };

//+------------------------------------------------------------------+
//| Gate de barra cerrada: una evaluacion por barra, sin repintado.  |
//+------------------------------------------------------------------+
class CLmBarGate
  {
private:
   datetime m_lastBar;
   bool     m_hasBar;
   int      m_evaluations;

public:
   CLmBarGate()
     {
      Reset();
     }

   void Reset()
     {
      m_lastBar     = 0;
      m_hasBar      = false;
      m_evaluations = 0;
     }

   bool ShouldEvaluate(const datetime barTime)
     {
      if(barTime <= 0)
         return(false);

      if(m_hasBar && barTime <= m_lastBar)
         return(false);

      m_lastBar = barTime;
      m_hasBar  = true;
      m_evaluations++;
      return(true);
     }

   int Evaluations() { return(m_evaluations); }
  };

//+------------------------------------------------------------------+
//| Configuracion del runtime.                                       |
//+------------------------------------------------------------------+
struct RuntimeConfig
  {
   long                magic;
   ENUM_LM_STRATEGY    strategy;
   RiskConfig          risk;
   SessionConfig       session;
  };

//+------------------------------------------------------------------+
//| Contadores observables para pruebas y diagnostico.               |
//+------------------------------------------------------------------+
struct RuntimeResult
  {
   int        ticks;
   int        signalEvaluations;
   int        managementTicks;
   int        ordersSent;
   int        protectionUpdates;
   int        closures;
   string     lastReason;
  };

//+------------------------------------------------------------------+
//| Orquesta el ciclo del EA: gestion por tick y senal por barra.    |
//+------------------------------------------------------------------+
class CLmRuntime
  {
private:
   CMarketContext   *m_market;
   ILmBasketSource  *m_baskets;
   ILmBarSource     *m_bars;
   CExecutor        *m_executor;
   CDailyLossGuard  *m_daily;
   RuntimeConfig     m_config;
   CBasketTracker    m_tracker;
   CLmBarGate        m_barGate;
   RuntimeResult     m_result;
   BasketState       m_basket;
   DailyLossState    m_dailyState;
   bool              m_ready;

   //--- Proteccion de entrada de una orden nueva.
   bool EntryProtection(const ENUM_ORDER_TYPE type, const double price,
                        double &sl, double &tp)
     {
      sl = 0.0;
      tp = 0.0;

      InstrumentInfo instrument = m_market.Instrument();
      if(price <= 0.0 || instrument.pipSize <= 0.0)
         return(false);

      double slDistance = m_config.risk.slPips * instrument.pipSize;
      double tpDistance = m_config.risk.tpPips * instrument.pipSize;

      if(type == ORDER_TYPE_BUY)
        {
         sl = price - slDistance;
         tp = price + tpDistance;
        }
      else if(type == ORDER_TYPE_SELL)
        {
         sl = price + slDistance;
         tp = price - tpDistance;
        }
      else
         return(false);

      sl = NormalizeDouble(sl, instrument.digits);
      tp = NormalizeDouble(tp, instrument.digits);
      return(sl > 0.0 && tp > 0.0);
     }

   //--- Acerca el SL de canasta al minimo que admite el broker.
   double BrokerValidStop(const ENUM_BASKET_DIRECTION direction,
                          double sl)
     {
      MarketSnapshot snapshot = m_market.Snapshot();
      InstrumentInfo instrument = m_market.Instrument();

      if(sl <= 0.0 || instrument.point <= 0.0 || !snapshot.valid)
         return(sl);

      double minDistance = (double)snapshot.stopsLevel * instrument.point;

      if(direction == BASKET_DIRECTION_BUY)
        {
         double maxStop = snapshot.bid - minDistance;
         if(sl > maxStop)
            sl = maxStop;
        }
      else if(direction == BASKET_DIRECTION_SELL)
        {
         double minStop = snapshot.ask + minDistance;
         if(sl < minStop)
            sl = minStop;
        }

      return(NormalizeDouble(sl, instrument.digits));
     }

   //--- Reenvia SL/TP a toda la canasta si difieren del objetivo.
   void ManageBasket()
     {
      if(m_basket.count <= 0)
         return;

      BasketPosition positions[];
      int total = m_baskets.Positions(m_config.magic, positions);
      if(total <= 0)
         return;

      InstrumentInfo instrument = m_market.Instrument();
      double sl = 0.0;
      double tp = 0.0;

      if(!LmBasketProtectionPrices(m_basket, m_config.risk.slPips,
                                   m_config.risk.tpPips, instrument.pipSize,
                                   instrument.digits, sl, tp))
         return;

      sl = BrokerValidStop(m_basket.direction, sl);
      if(sl <= 0.0 || tp <= 0.0)
         return;

      double tolerance = MathMax(instrument.point * 0.5, 1e-10);
      bool needsUpdate = false;

      for(int i = 0; i < total; i++)
        {
         if(MathAbs(positions[i].sl - sl) > tolerance ||
            MathAbs(positions[i].tp - tp) > tolerance)
           {
            needsUpdate = true;
            break;
           }
        }

      if(!needsUpdate)
         return;

      ExecutionReport report;
      m_executor.ModifyBasket(positions, sl, tp, report);

      m_result.protectionUpdates += report.modifiedCount;
      m_result.lastReason = report.reason;

      if(report.modifiedCount > 0)
         PrintFormat("LM_RUNTIME PROTECT positions=%d sl=%s tp=%s",
                     report.modifiedCount,
                     DoubleToString(sl, instrument.digits),
                     DoubleToString(tp, instrument.digits));
     }

   //--- Lee las barras cerradas y evalua la estrategia activa.
   bool ReadSignal(ENUM_SIGNAL_DIRECTION &signal)
     {
      signal = SIGNAL_NONE;

      double close1 = 0.0;
      double close2 = 0.0;
      double high1  = 0.0;
      double low2   = 0.0;
      double rsi    = 0.0;

      if(!m_bars.Close(1, close1) || !m_bars.Close(2, close2))
         return(false);

      bool hasHigh = m_bars.High(1, high1);
      bool hasLow  = m_bars.Low(2, low2);
      bool hasRsi  = m_bars.Rsi(1, rsi);

      //--- Fibonacci necesita las dos barras completas para decidir.
      if(m_config.strategy == LM_STRATEGY_FIBONACCI_FOCUS && (!hasHigh || !hasLow))
         return(false);

      signal = LmEvaluateStrategy(m_config.strategy, close1, close2,
                                  high1, low2, hasRsi, rsi);
      return(true);
     }

   //--- Envia una orden y actualiza los contadores.
   bool SendOrder(const ENUM_ORDER_TYPE type, const double volume,
                  const double price, const double sl, const double tp,
                  const string comment)
     {
      if(volume <= 0.0 || price <= 0.0)
         return(false);

      InstrumentInfo instrument = m_market.Instrument();

      OrderRequest request;
      request.symbol  = instrument.symbol;
      request.type    = type;
      request.volume  = volume;
      request.price   = price;
      request.sl      = sl;
      request.tp      = tp;
      request.comment = comment;

      ExecutionReport report;
      ENUM_EXECUTION_STATUS status = m_executor.Send(request, report);

      if(status == EXECUTION_STATUS_OK)
        {
         m_result.ordersSent++;
         m_result.lastReason = "";
         PrintFormat("LM_RUNTIME %s volume=%s price=%s sl=%s tp=%s",
                     comment,
                     DoubleToString(report.normalizedVolume, 2),
                     DoubleToString(price, instrument.digits),
                     DoubleToString(sl, instrument.digits),
                     DoubleToString(tp, instrument.digits));
         return(true);
        }

      m_result.lastReason = report.reason;
      return(false);
     }

   //--- Primera orden de una canasta nueva.
   bool OpenFirst(const double balance)
     {
      ENUM_SIGNAL_DIRECTION signal = SIGNAL_NONE;
      if(!ReadSignal(signal))
        {
         m_result.lastReason = "no se pudieron leer las barras de la senal";
         return(false);
        }

      if(signal == SIGNAL_NONE)
        {
         m_result.lastReason = "senal NONE";
         return(false);
        }

      if(!m_tracker.CanOpenFirst())
         return(false);

      SymbolLimits limits = m_executor.Limits();
      InstrumentInfo instrument = m_market.Instrument();

      RiskStepPlan plan;
      if(!LmPlanInitialOrder(m_config.risk, balance, instrument.pipValuePerLot,
                             limits.volumeStep, limits.volumeMin,
                             limits.volumeMax, plan))
        {
         m_result.lastReason = plan.reason;
         return(false);
        }

      ENUM_ORDER_TYPE type = (signal == SIGNAL_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      double price = (type == ORDER_TYPE_BUY ? m_market.Ask() : m_market.Bid());

      double sl = 0.0;
      double tp = 0.0;
      if(!EntryProtection(type, price, sl, tp))
        {
         m_result.lastReason = "no se pudo calcular la proteccion de entrada";
         return(false);
        }

      return(SendOrder(type, plan.volume, price, sl, tp,
                       "OPEN_FIRST " + LmStrategyName(m_config.strategy)));
     }

   //--- Paso de grid en la direccion de la canasta abierta.
   bool OpenGrid(const double balance)
     {
      if(m_basket.count <= 0 ||
         m_basket.direction == BASKET_DIRECTION_NONE)
         return(false);

      SymbolLimits limits = m_executor.Limits();
      InstrumentInfo instrument = m_market.Instrument();

      ENUM_ORDER_TYPE type = (m_basket.direction == BASKET_DIRECTION_BUY
                              ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      double price = (type == ORDER_TYPE_BUY ? m_market.Ask() : m_market.Bid());

      if(!LmGridStepReached(m_basket, price, m_config.risk.gridStepPips,
                            instrument.pipSize))
         return(false);

      if(m_tracker.StepCount() >= m_config.risk.maxGridSteps)
        {
         m_result.lastReason = "tope de pasos de grid alcanzado";
         return(false);
        }

      RiskStepPlan initialPlan;
      if(!LmPlanInitialOrder(m_config.risk, balance, instrument.pipValuePerLot,
                             limits.volumeStep, limits.volumeMin,
                             limits.volumeMax, initialPlan))
        {
         m_result.lastReason = initialPlan.reason;
         return(false);
        }

      int stepNumber  = m_tracker.StepCount() + 1;
      double requested = LmGridLot(initialPlan.volume, m_config.risk.lotMultiplier,
                                   stepNumber);

      RiskStepPlan plan;
      if(!LmPlanGridOrder(m_config.risk, balance, instrument.pipValuePerLot,
                          m_basket.volume, m_tracker.StepCount(), requested,
                          limits.volumeStep, limits.volumeMin, limits.volumeMax,
                          plan))
        {
         m_result.lastReason = plan.reason;
         return(false);
        }

      //--- Nuevo promedio proyectado con el volumen y precio del paso.
      double newVolume = m_basket.volume + plan.volume;
      double newAverage = 0.0;
      if(newVolume > 0.0)
         newAverage = (m_basket.averagePrice * m_basket.volume +
                       price * plan.volume) / newVolume;

      BasketState projected = m_basket;
      projected.volume       = newVolume;
      projected.averagePrice = newAverage;

      double sl = 0.0;
      double tp = 0.0;
      if(!LmBasketProtectionPrices(projected, m_config.risk.slPips,
                                   m_config.risk.tpPips, instrument.pipSize,
                                   instrument.digits, sl, tp))
        {
         m_result.lastReason = "no se pudo calcular la proteccion del grid";
         return(false);
        }

      if(!SendOrder(type, plan.volume, price, sl, tp,
                    StringFormat("OPEN_GRID step=%d", stepNumber)))
         return(false);

      //--- Relee la canasta para reenviar la nueva proteccion a todos.
      m_baskets.Scan(m_config.magic, m_basket);
      m_tracker.Update(m_basket);
      ManageBasket();
      return(true);
     }

public:
   CLmRuntime()
     {
      m_market  = NULL;
      m_baskets = NULL;
      m_bars    = NULL;
      m_executor = NULL;
      m_daily   = NULL;
      m_ready   = false;
      m_config.magic    = 0;
      m_config.strategy = LM_STRATEGY_SCALPER_PRO;
      m_config.risk     = LmDefaultRiskConfig();
      m_config.session  = LmDefaultSessionConfig();
      LmResetBasket(m_basket, "", 0);
      LmResetDailyLossState(m_dailyState);
     }

   bool Init(CMarketContext *market, ILmBasketSource *baskets,
             ILmBarSource *bars, CExecutor *executor,
             CDailyLossGuard *daily, const RuntimeConfig &config)
     {
      if(market == NULL || baskets == NULL || bars == NULL ||
         executor == NULL || !LmStrategyIsValid(config.strategy))
         return(false);

      if(!LmSessionConfigValid(config.session))
         return(false);

      m_market   = market;
      m_baskets  = baskets;
      m_bars     = bars;
      m_executor = executor;
      m_daily    = daily;
      m_config   = config;
      m_ready    = true;

      m_barGate.Reset();
      m_tracker.Reset();
      LmResetBasket(m_basket, market.Instrument().symbol, config.magic);
      LmResetDailyLossState(m_dailyState);

      m_result.ticks             = 0;
      m_result.signalEvaluations = 0;
      m_result.managementTicks   = 0;
      m_result.ordersSent        = 0;
      m_result.protectionUpdates = 0;
      m_result.closures          = 0;
      m_result.lastReason        = "";

      return(true);
     }

   //--- Procesa un tick ya refrescado en MarketContext.
   bool ProcessTick(const datetime serverTime, const double equity,
                    const double balance)
     {
      m_result.ticks++;

      if(!m_ready)
        {
         m_result.lastReason = "runtime no inicializado";
         return(false);
        }

      //--- 1. Estado de la canasta.
      m_baskets.Scan(m_config.magic, m_basket);
      m_tracker.Update(m_basket);

      if(m_tracker.JustClosed())
        {
         m_result.closures++;
         PrintFormat("LM_RUNTIME CLOSED");
        }

      //--- 2. Gestion en cada tick, antes de cualquier guard.
      m_result.managementTicks++;
      ManageBasket();

      //--- 3. Limite diario: se evalua siempre, pero solo bloquea entradas.
      bool dailyBlocked = false;
      if(m_daily != NULL)
        {
         if(!m_daily.Evaluate(serverTime, equity, m_dailyState))
           {
            dailyBlocked = true;
            m_result.lastReason = "guarda diaria no disponible";
           }
         else
            dailyBlocked = m_dailyState.blocked;
        }

      //--- 4. La senal solo se evalua al cerrar una barra.
      datetime barTime = 0;
      if(!m_bars.BarTime(barTime))
        {
         m_result.lastReason = "no se pudo leer la barra actual";
         return(true);
        }

      if(!m_barGate.ShouldEvaluate(barTime))
         return(true);

      m_result.signalEvaluations++;

      //--- 5. Guards de entrada, nunca de gestion.
      bool sessionOpen = LmSessionOpen(serverTime, m_config.session);
      bool canOpen = LmCanOpenNew(dailyBlocked, m_market.SpreadBlocked(),
                                  m_market.HighVolatility(), sessionOpen);

      if(!canOpen)
        {
         m_result.lastReason = "entradas bloqueadas por guards";
         return(true);
        }

      if(!m_market.IsValid())
        {
         m_result.lastReason = "snapshot de mercado invalido";
         return(false);
        }

      //--- 6. Primera orden o paso de grid.
      if(m_basket.count > 0)
         OpenGrid(balance);
      else
         OpenFirst(balance);

      return(true);
     }

   RuntimeResult Result()      { return(m_result); }
   int          OrdersSent()   { return(m_result.ordersSent); }
   int          Evaluations()  { return(m_result.signalEvaluations); }
   int          Closures()     { return(m_result.closures); }
   int          ProtectionUpdates() { return(m_result.protectionUpdates); }
   BasketState  Basket()       { return(m_basket); }
   bool         IsReady()      { return(m_ready); }
  };

#endif // LMROBOT_CORE_RUNTIME_MQH
