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
//| Espera minima tras el cierre de una canasta antes de reabrir.    |
//| Un cooldown de 0 replica el comportamiento sin espera (H1).      |
//+------------------------------------------------------------------+
bool LmEntryCooldownElapsed(const datetime lastCloseTime, const datetime now,
                            const int cooldownSeconds)
  {
   if(cooldownSeconds <= 0 || lastCloseTime <= 0)
      return(true);

   //--- Reloj hacia atras (reinicios, cambios de servidor): no bloquear.
   if(now < lastCloseTime)
      return(true);

   return((long)(now - lastCloseTime) >= (long)cooldownSeconds);
  }

//+------------------------------------------------------------------+
//| Configuracion del runtime.                                       |
//+------------------------------------------------------------------+
struct RuntimeConfig
  {
   long                magic;
   ENUM_LM_STRATEGY    strategy;
   RiskConfig          risk;
   SessionConfig       session;
   int                 entryCooldownSeconds; // 0 = sin espera tras cierre
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
   double     maxOrderVolume;
   double     maxBasketVolume;
   int        maxGridSteps;
   double     maxProjectedLoss;
   double     maxProjectedLossPct;
   int        strategyCount;
   string     strategyNames[LM_MAX_ACTIVE_STRATEGIES];
   long       strategyMagics[LM_MAX_ACTIVE_STRATEGIES];
   int        strategyOrders[LM_MAX_ACTIVE_STRATEGIES];
   double     strategyMaxVolume[LM_MAX_ACTIVE_STRATEGIES];
   double     strategyMaxProjectedLossPct[LM_MAX_ACTIVE_STRATEGIES];
   double     strategyMaxDrawdown[LM_MAX_ACTIVE_STRATEGIES];
   double     maxAggregateVolume;
   double     maxAggregateProjectedLoss;
   double     maxAggregateProjectedLossPct;
   string     lastReason;
  };

//+------------------------------------------------------------------+
//| Una estrategia activa con su propia canasta, magic y metricas.   |
//+------------------------------------------------------------------+
class CStrategySlot
  {
public:
   ENUM_LM_STRATEGY strategy;
   long             magic;
   BasketState      basket;
   CBasketTracker   tracker;
   int              ordersSent;
   int              protectionUpdates;
   int              closures;
   double           maxOrderVolume;
   double           maxBasketVolume;
   int              maxGridSteps;
   double           maxProjectedLoss;
   double           maxProjectedLossPct;
   double           slPips;
   double           lastOpenPnl;
   double           realizedPnl;
   double           pnlPeak;
   double           maxDrawdownMoney;
   datetime         lastCloseTime; // cierre mas reciente; base del cooldown

   CStrategySlot()
     {
      Reset(LM_STRATEGY_SCALPER_PRO, 0);
     }

   void Reset(const ENUM_LM_STRATEGY value, const long magicValue)
     {
      strategy          = value;
      magic             = magicValue;
      LmResetBasket(basket, "", magicValue);
      tracker.Reset();
      ordersSent        = 0;
      protectionUpdates = 0;
      closures          = 0;
      maxOrderVolume    = 0.0;
      maxBasketVolume   = 0.0;
      maxGridSteps      = 0;
      maxProjectedLoss  = 0.0;
      maxProjectedLossPct = 0.0;
      slPips            = 0.0;
      lastOpenPnl       = 0.0;
      realizedPnl       = 0.0;
      pnlPeak           = 0.0;
      maxDrawdownMoney  = 0.0;
      lastCloseTime     = 0;
     }

   //--- Actualiza el estado y la serie de PnL usada para el DD.
   void Observe(const BasketState &scanned)
     {
      bool hadPositions = (basket.count > 0);
      if(hadPositions)
         lastOpenPnl = basket.pnl;

      basket = scanned;
      tracker.Update(basket);

      if(basket.count > 0)
         lastOpenPnl = basket.pnl;

      if(tracker.JustClosed())
        {
         //--- Ultimo PnL flotante observado antes del cierre.
         realizedPnl += lastOpenPnl;
         lastOpenPnl  = 0.0;
        }

      double series = realizedPnl + (basket.count > 0 ? basket.pnl : 0.0);
      if(series > pnlPeak)
         pnlPeak = series;

      double drawdown = pnlPeak - series;
      if(drawdown > maxDrawdownMoney)
         maxDrawdownMoney = drawdown;
     }

   void ObserveExposure(const double balance, const RiskConfig &risk,
                        const InstrumentInfo &instrument, const double basketSlPips)
     {
      if(basket.volume > maxBasketVolume)
         maxBasketVolume = basket.volume;

      int steps = (basket.count > 0 ? basket.count - 1 : 0);
      if(steps > maxGridSteps)
         maxGridSteps = steps;

      if(instrument.pipValuePerLot <= 0.0)
         return;

      double effectiveSl = (basketSlPips > 0.0 ? basketSlPips : risk.slPips);
      double projected = LmProjectedLoss(basket.volume, effectiveSl,
                                         instrument.pipValuePerLot);
      if(projected > maxProjectedLoss)
         maxProjectedLoss = projected;

      if(balance <= 0.0)
         return;

      double usedPct = projected / balance * 100.0;
      if(usedPct > maxProjectedLossPct)
         maxProjectedLossPct = usedPct;
     }
  };

//+------------------------------------------------------------------+
//| Orquesta el ciclo del EA: gestion por tick y senal por barra.    |
//| En modo ALL mantiene una canasta por estrategia en paralelo.     |
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
   CLmBarGate        m_barGate;
   RuntimeResult     m_result;
   CStrategySlot     m_slots[LM_MAX_ACTIVE_STRATEGIES];
   int               m_slotCount;
   DailyLossState    m_dailyState;
   bool              m_ready;

   void ResetResult()
     {
      m_result.ticks             = 0;
      m_result.signalEvaluations = 0;
      m_result.managementTicks   = 0;
      m_result.ordersSent        = 0;
      m_result.protectionUpdates = 0;
      m_result.closures          = 0;
      m_result.maxOrderVolume    = 0.0;
      m_result.maxBasketVolume   = 0.0;
      m_result.maxGridSteps      = 0;
      m_result.maxProjectedLoss  = 0.0;
      m_result.maxProjectedLossPct = 0.0;
      m_result.strategyCount     = m_slotCount;
      m_result.maxAggregateVolume = 0.0;
      m_result.maxAggregateProjectedLoss = 0.0;
      m_result.maxAggregateProjectedLossPct = 0.0;
      m_result.lastReason        = "";

      for(int i = 0; i < LM_MAX_ACTIVE_STRATEGIES; i++)
        {
         m_result.strategyNames[i]   = "";
         m_result.strategyMagics[i]  = 0;
         m_result.strategyOrders[i]  = 0;
         m_result.strategyMaxVolume[i] = 0.0;
         m_result.strategyMaxProjectedLossPct[i] = 0.0;
         m_result.strategyMaxDrawdown[i] = 0.0;
        }
     }

   //--- Copia las metricas por estrategia al resultado agregado.
   void SyncSlotResults()
     {
      m_result.strategyCount = m_slotCount;
      m_result.maxBasketVolume = 0.0;
      m_result.maxGridSteps    = 0;
      m_result.maxProjectedLoss = 0.0;
      m_result.maxProjectedLossPct = 0.0;

      for(int i = 0; i < m_slotCount; i++)
        {
         m_result.strategyNames[i]  = LmStrategyName(m_slots[i].strategy);
         m_result.strategyMagics[i] = m_slots[i].magic;
         m_result.strategyOrders[i] = m_slots[i].ordersSent;
         m_result.strategyMaxVolume[i] = m_slots[i].maxBasketVolume;
         m_result.strategyMaxProjectedLossPct[i] = m_slots[i].maxProjectedLossPct;
         m_result.strategyMaxDrawdown[i] = m_slots[i].maxDrawdownMoney;

         if(m_slots[i].maxBasketVolume > m_result.maxBasketVolume)
            m_result.maxBasketVolume = m_slots[i].maxBasketVolume;

         if(m_slots[i].maxGridSteps > m_result.maxGridSteps)
            m_result.maxGridSteps = m_slots[i].maxGridSteps;

         if(m_slots[i].maxProjectedLoss > m_result.maxProjectedLoss)
            m_result.maxProjectedLoss = m_slots[i].maxProjectedLoss;

         if(m_slots[i].maxProjectedLossPct > m_result.maxProjectedLossPct)
            m_result.maxProjectedLossPct = m_slots[i].maxProjectedLossPct;
        }
     }

   //--- Volumen y perdida proyectada de todas las canastas.
   void AggregateSnapshot(double &totalVolume, double &projectedLoss)
     {
      totalVolume   = 0.0;
      projectedLoss = 0.0;

      InstrumentInfo instrument = m_market.Instrument();

      for(int i = 0; i < m_slotCount; i++)
        {
         totalVolume += m_slots[i].basket.volume;

         if(instrument.pipValuePerLot > 0.0)
           {
            double slPips = (m_slots[i].slPips > 0.0
                             ? m_slots[i].slPips : m_config.risk.slPips);
            projectedLoss += LmProjectedLoss(m_slots[i].basket.volume,
                                             slPips,
                                             instrument.pipValuePerLot);
           }
        }
     }

   void UpdateAggregateExposure(const double balance)
     {
      double totalVolume = 0.0;
      double projected   = 0.0;
      AggregateSnapshot(totalVolume, projected);

      if(totalVolume > m_result.maxAggregateVolume)
         m_result.maxAggregateVolume = totalVolume;

      if(projected > m_result.maxAggregateProjectedLoss)
         m_result.maxAggregateProjectedLoss = projected;

      if(balance > 0.0)
        {
         double usedPct = projected / balance * 100.0;
         if(usedPct > m_result.maxAggregateProjectedLossPct)
            m_result.maxAggregateProjectedLossPct = usedPct;
        }
     }

   //--- Presupuesto agregado de la instancia, solo en modo ALL.
   bool AggregateAllows(const int slotIndex, const double newVolume,
                        const double newSlPips, const double balance)
     {
      if(m_slotCount <= 1)
         return(true);

      InstrumentInfo instrument = m_market.Instrument();
      if(instrument.pipValuePerLot <= 0.0)
        {
         m_result.lastReason = "valor del pip invalido para el presupuesto agregado";
         return(false);
        }

      double totalVolume = 0.0;
      double projected   = 0.0;

      for(int i = 0; i < m_slotCount; i++)
        {
         double volume = m_slots[i].basket.volume;
         double slPips = (m_slots[i].slPips > 0.0
                          ? m_slots[i].slPips : m_config.risk.slPips);
         if(i == slotIndex)
           {
            volume += newVolume;
            slPips  = (newSlPips > 0.0 ? newSlPips : slPips);
           }

         totalVolume += volume;
         projected += LmProjectedLoss(volume, slPips,
                                      instrument.pipValuePerLot);
        }

      if(!LmFitsAggregateVolume(totalVolume, m_config.risk.maxAggregateVolume))
        {
         m_result.lastReason = StringFormat(
            "tope de volumen agregado alcanzado (%.2f > %.2f)",
            totalVolume, m_config.risk.maxAggregateVolume);
         return(false);
        }

      if(!LmFitsAggregateBudget(projected, balance,
                                m_config.risk.maxAggregateLossPct))
        {
         m_result.lastReason = StringFormat(
            "presupuesto agregado agotado (%.2f%% > %.2f%%)",
            (balance > 0.0 ? projected / balance * 100.0 : 0.0),
            m_config.risk.maxAggregateLossPct);
         return(false);
        }

      return(true);
     }

   //--- Proteccion de entrada de una orden nueva.
   bool EntryProtection(const ENUM_ORDER_TYPE type, const double price,
                        const double slPips, double &sl, double &tp)
     {
      sl = 0.0;
      tp = 0.0;

      InstrumentInfo instrument = m_market.Instrument();
      if(price <= 0.0 || instrument.pipSize <= 0.0)
         return(false);

      double effectiveSl = (slPips > 0.0 ? slPips : m_config.risk.slPips);
      double slDistance = effectiveSl * instrument.pipSize;
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
   void ManageBasket(CStrategySlot &slot)
     {
      if(slot.basket.count <= 0)
         return;

      BasketPosition positions[];
      int total = m_baskets.Positions(slot.magic, positions);
      if(total <= 0)
         return;

      InstrumentInfo instrument = m_market.Instrument();
      double sl = 0.0;
      double tp = 0.0;

      //--- Tras un reinicio se reconstruye la distancia con el ATR actual.
      if(slot.slPips <= 0.0)
         slot.slPips = LmEffectiveSlPips(m_config.risk, m_market.AtrPips());

      if(!LmBasketProtectionPrices(slot.basket, slot.slPips,
                                   m_config.risk.tpPips, instrument.pipSize,
                                   instrument.digits, sl, tp))
         return;

      sl = BrokerValidStop(slot.basket.direction, sl);
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

      slot.protectionUpdates += report.modifiedCount;
      m_result.protectionUpdates += report.modifiedCount;
      m_result.lastReason = report.reason;

      if(report.modifiedCount > 0)
         PrintFormat("LM_RUNTIME PROTECT strategy=%s positions=%d sl=%s tp=%s",
                     LmStrategyName(slot.strategy), report.modifiedCount,
                     DoubleToString(sl, instrument.digits),
                     DoubleToString(tp, instrument.digits));
     }

   //--- Lee las barras cerradas y evalua una estrategia concreta.
   bool ReadSignal(const ENUM_LM_STRATEGY strategy,
                   ENUM_SIGNAL_DIRECTION &signal)
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
      if(strategy == LM_STRATEGY_FIBONACCI_FOCUS && (!hasHigh || !hasLow))
         return(false);

      signal = LmEvaluateStrategy(strategy, close1, close2,
                                  high1, low2, hasRsi, rsi);
      return(true);
     }

   //--- Envia una orden y actualiza los contadores de la estrategia.
   bool SendOrder(CStrategySlot &slot, const ENUM_ORDER_TYPE type,
                  const double volume, const double price,
                  const double sl, const double tp, const string comment)
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
      request.magic   = slot.magic;

      ExecutionReport report;
      ENUM_EXECUTION_STATUS status = m_executor.Send(request, report);

      if(status == EXECUTION_STATUS_OK)
        {
         m_result.ordersSent++;
         slot.ordersSent++;

         if(report.normalizedVolume > m_result.maxOrderVolume)
            m_result.maxOrderVolume = report.normalizedVolume;

         if(report.normalizedVolume > slot.maxOrderVolume)
            slot.maxOrderVolume = report.normalizedVolume;

         m_result.lastReason = "";
         PrintFormat("LM_RUNTIME %s strategy=%s magic=%I64d volume=%s price=%s sl=%s tp=%s",
                     comment, LmStrategyName(slot.strategy), slot.magic,
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
   bool OpenFirst(CStrategySlot &slot, const int slotIndex,
                  const double balance, const datetime serverTime)
     {
      //--- Tras un cierre no se reabre hasta vencer la espera configurada.
      if(!LmEntryCooldownElapsed(slot.lastCloseTime, serverTime,
                                 m_config.entryCooldownSeconds))
        {
         m_result.lastReason = "cooldown de reentrada activo";
         return(false);
        }

      ENUM_SIGNAL_DIRECTION signal = SIGNAL_NONE;
      if(!ReadSignal(slot.strategy, signal))
        {
         m_result.lastReason = "no se pudieron leer las barras de la senal";
         return(false);
        }

      if(signal == SIGNAL_NONE)
        {
         m_result.lastReason = "senal NONE";
         return(false);
        }

      if(!slot.tracker.CanOpenFirst())
         return(false);

      SymbolLimits limits = m_executor.Limits();
      InstrumentInfo instrument = m_market.Instrument();
      double atrPips    = m_market.AtrPips();
      double atrAvgPips = m_market.AtrAvgPips();

      //--- En automatico el riesgo ya expresa la volatilidad: el lote no
      //--- vuelve a aplicar el factor (avgAtr = atr -> factor 1.0).
      double planAvgAtrPips = (m_config.risk.riskMode == LM_RISK_AUTO
                               ? atrPips : atrAvgPips);

      RiskStepPlan plan;
      if(!LmPlanInitialOrder(m_config.risk, balance, instrument.pipValuePerLot,
                             limits.volumeStep, limits.volumeMin,
                             limits.volumeMax, plan, atrPips, planAvgAtrPips))
        {
         m_result.lastReason = plan.reason;
         return(false);
        }

      if(!AggregateAllows(slotIndex, plan.volume, plan.slPips, balance))
         return(false);

      ENUM_ORDER_TYPE type = (signal == SIGNAL_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      double price = (type == ORDER_TYPE_BUY ? m_market.Ask() : m_market.Bid());

      double sl = 0.0;
      double tp = 0.0;
      if(!EntryProtection(type, price, plan.slPips, sl, tp))
        {
         m_result.lastReason = "no se pudo calcular la proteccion de entrada";
         return(false);
        }

      if(!SendOrder(slot, type, plan.volume, price, sl, tp,
                    "OPEN_FIRST " + LmStrategyName(slot.strategy)))
         return(false);

      //--- Relee la canasta para registrar la exposicion inicial.
      slot.slPips = plan.slPips;
      m_baskets.Scan(slot.magic, slot.basket);
      slot.tracker.Update(slot.basket);
      slot.ObserveExposure(balance, m_config.risk, instrument, slot.slPips);
      SyncSlotResults();
      return(true);
     }

   //--- Paso de grid en la direccion de la canasta abierta.
   bool OpenGrid(CStrategySlot &slot, const int slotIndex,
                 const double balance)
     {
      if(slot.basket.count <= 0 ||
         slot.basket.direction == BASKET_DIRECTION_NONE)
         return(false);

      SymbolLimits limits = m_executor.Limits();
      InstrumentInfo instrument = m_market.Instrument();
      double atrPips    = m_market.AtrPips();
      double atrAvgPips = m_market.AtrAvgPips();

      //--- Mismo criterio que en la apertura: en automatico el lote base
      //--- no repite el ajuste por volatilidad.
      double planAvgAtrPips = (m_config.risk.riskMode == LM_RISK_AUTO
                               ? atrPips : atrAvgPips);

      ENUM_ORDER_TYPE type = (slot.basket.direction == BASKET_DIRECTION_BUY
                              ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      double price = (type == ORDER_TYPE_BUY ? m_market.Ask() : m_market.Bid());

      if(!LmGridStepReached(slot.basket, price, m_config.risk.gridStepPips,
                            instrument.pipSize))
         return(false);

      if(slot.tracker.StepCount() >= m_config.risk.maxGridSteps)
        {
         m_result.lastReason = "tope de pasos de grid alcanzado";
         return(false);
        }

      RiskStepPlan initialPlan;
      if(!LmPlanInitialOrder(m_config.risk, balance, instrument.pipValuePerLot,
                             limits.volumeStep, limits.volumeMin,
                             limits.volumeMax, initialPlan, atrPips, planAvgAtrPips))
        {
         m_result.lastReason = initialPlan.reason;
         return(false);
        }

      int stepNumber  = slot.tracker.StepCount() + 1;
      double requested = LmGridLot(initialPlan.volume, m_config.risk.lotMultiplier,
                                   stepNumber);

      RiskStepPlan plan;
      if(!LmPlanGridOrder(m_config.risk, balance, instrument.pipValuePerLot,
                          slot.basket.volume, slot.tracker.StepCount(), requested,
                          limits.volumeStep, limits.volumeMin, limits.volumeMax,
                          plan, atrPips))
        {
         m_result.lastReason = plan.reason;
         return(false);
        }

      if(!AggregateAllows(slotIndex, plan.volume, plan.slPips, balance))
         return(false);

      //--- Nuevo promedio proyectado con el volumen y precio del paso.
      double newVolume = slot.basket.volume + plan.volume;
      double newAverage = 0.0;
      if(newVolume > 0.0)
         newAverage = (slot.basket.averagePrice * slot.basket.volume +
                       price * plan.volume) / newVolume;

      BasketState projected = slot.basket;
      projected.volume       = newVolume;
      projected.averagePrice = newAverage;

      double sl = 0.0;
      double tp = 0.0;
      if(!LmBasketProtectionPrices(projected, plan.slPips,
                                   m_config.risk.tpPips, instrument.pipSize,
                                   instrument.digits, sl, tp))
        {
         m_result.lastReason = "no se pudo calcular la proteccion del grid";
         return(false);
        }

      if(!SendOrder(slot, type, plan.volume, price, sl, tp,
                    StringFormat("OPEN_GRID step=%d", stepNumber)))
         return(false);

      //--- Relee la canasta para reenviar la nueva proteccion a todos.
      slot.slPips = plan.slPips;
      m_baskets.Scan(slot.magic, slot.basket);
      slot.tracker.Update(slot.basket);
      slot.ObserveExposure(balance, m_config.risk, instrument, slot.slPips);
      SyncSlotResults();
      ManageBasket(slot);
      return(true);
     }

public:
   CLmRuntime()
     {
      m_market   = NULL;
      m_baskets  = NULL;
      m_bars     = NULL;
      m_executor = NULL;
      m_daily    = NULL;
      m_slotCount = 0;
      m_ready    = false;
      m_config.magic    = 0;
      m_config.strategy = LM_STRATEGY_SCALPER_PRO;
      m_config.risk     = LmDefaultRiskConfig();
      m_config.session  = LmDefaultSessionConfig();
      m_config.entryCooldownSeconds = 0;
      LmResetDailyLossState(m_dailyState);
      ResetResult();
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

      ENUM_LM_STRATEGY list[];
      int count = LmResolveStrategyList(config.strategy, list);
      if(count <= 0 || count > LM_MAX_ACTIVE_STRATEGIES)
         return(false);

      m_market   = market;
      m_baskets  = baskets;
      m_bars     = bars;
      m_executor = executor;
      m_daily    = daily;
      m_config   = config;
      m_slotCount = count;
      m_ready    = true;

      m_market.SetAtrLookback(config.risk.atrLookback);

      m_barGate.Reset();
      LmResetDailyLossState(m_dailyState);

      for(int i = 0; i < m_slotCount; i++)
        {
         m_slots[i].Reset(list[i], LmStrategyMagic(config.magic,
                                                   config.strategy, i));
         LmResetBasket(m_slots[i].basket, market.Instrument().symbol,
                       m_slots[i].magic);
        }

      for(int i = m_slotCount; i < LM_MAX_ACTIVE_STRATEGIES; i++)
         m_slots[i].Reset(LM_STRATEGY_SCALPER_PRO, 0);

      ResetResult();
      SyncSlotResults();
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

      //--- En automatico el riesgo vivo se recalcula en cada tick desde la
      //--- base capturada (no desde el resultado anterior).
      if(m_config.risk.riskMode == LM_RISK_AUTO)
         m_config.risk.riskPct = LmAutoRiskPct(m_config.risk.riskBasePct,
                                               m_market.AtrPips(),
                                               m_market.AtrAvgPips(),
                                               m_config.risk.volFactorMin,
                                               m_config.risk.volFactorMax,
                                               m_config.risk.autoRiskMaxPct);

      InstrumentInfo instrument = m_market.Instrument();

      //--- 1. Estado de cada canasta y gestion en cada tick.
      m_result.managementTicks++;

      for(int i = 0; i < m_slotCount; i++)
        {
         BasketState scanned;
         m_baskets.Scan(m_slots[i].magic, scanned);
         m_slots[i].Observe(scanned);
         m_slots[i].ObserveExposure(balance, m_config.risk, instrument,
                                    m_slots[i].slPips);

         if(m_slots[i].tracker.JustClosed())
           {
            m_slots[i].lastCloseTime = serverTime;
            m_slots[i].closures++;
            m_result.closures++;
            PrintFormat("LM_RUNTIME CLOSED strategy=%s magic=%I64d",
                        LmStrategyName(m_slots[i].strategy),
                        m_slots[i].magic);
           }
        }

      UpdateAggregateExposure(balance);
      SyncSlotResults();

      //--- 2. La gestion de posiciones abiertas nunca se bloquea.
      for(int i = 0; i < m_slotCount; i++)
         ManageBasket(m_slots[i]);

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

      //--- Cada estrategia activa evalua su senal una vez por barra.
      m_result.signalEvaluations += m_slotCount;

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

      //--- 6. Cada estrategia abre su propia canasta o su paso de grid.
      for(int i = 0; i < m_slotCount; i++)
        {
         if(m_slots[i].basket.count > 0)
            OpenGrid(m_slots[i], i, balance);
         else
            OpenFirst(m_slots[i], i, balance, serverTime);
        }

      //--- La exposicion agregada incluye lo abierto en esta misma barra.
      UpdateAggregateExposure(balance);
      SyncSlotResults();
      return(true);
     }

   RuntimeResult Result()      { return(m_result); }
   int          OrdersSent()   { return(m_result.ordersSent); }
   int          Evaluations()  { return(m_result.signalEvaluations); }
   int          Closures()     { return(m_result.closures); }
   int          ProtectionUpdates() { return(m_result.protectionUpdates); }
   BasketState  Basket()       { return(m_slots[0].basket); }
   RuntimeConfig Config()      { return(m_config); }
   DailyLossState DailyState() { return(m_dailyState); }
   bool         IsReady()      { return(m_ready); }
   int          StrategyCount() { return(m_slotCount); }

   //--- Riesgo vivo: valida y escribe la unica fuente de dimensionamiento.
   //--- En automatico lo calcula la politica, no el control manual.
   bool SetRiskPct(const double pct)
     {
      if(m_config.risk.riskMode == LM_RISK_AUTO)
         return(false);

      if(!MathIsValidNumber(pct) || pct <= 0.0)
         return(false);

      m_config.risk.riskPct = pct;
      return(true);
     }

   //--- Conmutacion de modalidad con continuidad del riesgo vivo.
   bool SetRiskMode(const ENUM_LM_RISK_MODE mode)
     {
      if(mode != LM_RISK_MANUAL && mode != LM_RISK_AUTO)
         return(false);

      if(mode == m_config.risk.riskMode)
         return(true);

      if(mode == LM_RISK_AUTO)
        {
         double atrPips    = (m_market != NULL ? m_market.AtrPips() : 0.0);
         double avgAtrPips = (m_market != NULL ? m_market.AtrAvgPips() : 0.0);

         m_config.risk.riskBasePct = m_config.risk.riskPct;
         m_config.risk.riskPct = LmAutoRiskPct(m_config.risk.riskBasePct,
                                               atrPips,
                                               avgAtrPips,
                                               m_config.risk.volFactorMin,
                                               m_config.risk.volFactorMax,
                                               m_config.risk.autoRiskMaxPct);
        }

      //--- Auto -> Manual conserva el ultimo riesgo automatico.
      m_config.risk.riskMode = mode;
      return(true);
     }

   bool StrategyAt(const int index, ENUM_LM_STRATEGY &strategy,
                   BasketState &basket, long &magic)
     {
      if(index < 0 || index >= m_slotCount)
         return(false);

      strategy = m_slots[index].strategy;
      basket   = m_slots[index].basket;
      magic    = m_slots[index].magic;
      return(true);
     }
  };

#endif // LMROBOT_CORE_RUNTIME_MQH
