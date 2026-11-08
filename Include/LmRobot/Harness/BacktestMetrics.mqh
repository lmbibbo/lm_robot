//+------------------------------------------------------------------+
//|                                              BacktestMetrics.mqh |
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#ifndef LMROBOT_HARNESS_BACKTESTMETRICS_MQH
#define LMROBOT_HARNESS_BACKTESTMETRICS_MQH

#include "../Core/Runtime.mqh"

//+------------------------------------------------------------------+
//| Resumen de una corrida de backtest.                              |
//+------------------------------------------------------------------+
struct BacktestSummary
  {
   string strategy;
   string symbol;
   string timeframe;
   int    ticks;
   int    signalEvaluations;
   int    ordersSent;
   int    protectionUpdates;
   int    closures;
   double maxOrderVolume;
   double maxBasketVolume;
   int    maxGridSteps;
   double maxProjectedLoss;
   double maxProjectedLossPct;
   double maxDrawdownPct;
   int    dailyLimitHits;
   string dailyLimitDays;
   double finalBalance;
   double finalEquity;
   double maxLotPerOrder;
   double maxVolumePerStrategy;
   int    maxGridStepsLimit;
   double maxBasketLossPct;
   bool   limitsRespected;
   bool   portfolio;
   int    strategyCount;
   string strategyNames[LM_MAX_ACTIVE_STRATEGIES];
   long   strategyMagics[LM_MAX_ACTIVE_STRATEGIES];
   double strategyNet[LM_MAX_ACTIVE_STRATEGIES];
   double strategyMaxDrawdown[LM_MAX_ACTIVE_STRATEGIES];
   double strategyMaxVolume[LM_MAX_ACTIVE_STRATEGIES];
   double strategyMaxProjectedLossPct[LM_MAX_ACTIVE_STRATEGIES];
   int    strategyOrders[LM_MAX_ACTIVE_STRATEGIES];
   double portfolioNet;
   double maxAggregateVolume;
   double maxAggregateProjectedLossPct;
   double aggregateVolumeLimit;
   double aggregateLossPctLimit;
   bool   aggregateRespected;
  };

//+------------------------------------------------------------------+
//| Nombre corto de timeframe: PERIOD_H1 -> H1.                      |
//+------------------------------------------------------------------+
string LmBacktestTimeframeName(const ENUM_TIMEFRAMES timeframe)
  {
   string text = EnumToString(timeframe);

   if(StringFind(text, "PERIOD_") == 0)
      return(StringSubstr(text, 7));

   return(text);
  }

//+------------------------------------------------------------------+
//| Nombre de estrategia apto para un nombre de archivo.             |
//+------------------------------------------------------------------+
string LmStrategySlug(const ENUM_LM_STRATEGY strategy)
  {
   string name = LmStrategyName(strategy);
   StringReplace(name, " ", "_");
   return(name);
  }

//+------------------------------------------------------------------+
//| Net realizado de un magic segun el historial de deals.           |
//| Suma profit + swap + commission de los deals de cierre.          |
//| Los cierres forzados al final del test llegan con magic 0; en    |
//| ese caso el magic se recupera del deal de apertura de la misma   |
//| posicion (DEAL_POSITION_ID).                                     |
//+------------------------------------------------------------------+
double LmHistoryNetByMagic(const long magic)
  {
   if(!HistorySelect(0, TimeCurrent() + 86400))
      return(0.0);

   int total = HistoryDealsTotal();

   //--- Primera pasada: magic de cada posicion segun su deal de entrada.
   ulong positionIds[];
   long  positionMagics[];
   ArrayResize(positionIds, 0);
   ArrayResize(positionMagics, 0);

   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_IN)
         continue;

      long positionId = (long)HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
      if(positionId == 0)
         continue;

      int index = ArraySize(positionIds);
      ArrayResize(positionIds, index + 1);
      ArrayResize(positionMagics, index + 1);
      positionIds[index]    = (ulong)positionId;
      positionMagics[index] = (long)HistoryDealGetInteger(ticket, DEAL_MAGIC);
     }

   //--- Segunda pasada: neto de los deals de cierre del magic pedido.
   double net = 0.0;

   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);

      //--- El deal de apertura no tiene resultado economico.
      if(entry == DEAL_ENTRY_IN)
         continue;

      //--- Depositos y retiros no pertenecen a ninguna estrategia.
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) == "")
         continue;

      long dealMagic = (long)HistoryDealGetInteger(ticket, DEAL_MAGIC);
      if(dealMagic == 0)
        {
         long positionId = (long)HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
         for(int j = 0; j < ArraySize(positionIds); j++)
            if((long)positionIds[j] == positionId)
              {
               dealMagic = positionMagics[j];
               break;
              }
        }

      if(dealMagic != magic)
         continue;

      net += HistoryDealGetDouble(ticket, DEAL_PROFIT);
      net += HistoryDealGetDouble(ticket, DEAL_SWAP);
      net += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
     }

   return(net);
  }

//+------------------------------------------------------------------+
//| Acumula las metricas que no se pueden derivar de un solo scan.   |
//+------------------------------------------------------------------+
class CBacktestMetrics
  {
private:
   string             m_symbol;
   string             m_timeframe;
   ENUM_LM_STRATEGY   m_strategy;
   double             m_peakEquity;
   double             m_maxDrawdownPct;
   int                m_dailyLimitHits;
   string             m_dailyLimitDays;
   string             m_lastBlockedDay;
   string             m_auditDay;
   double             m_auditStart;
   double             m_auditMin;
   string             m_auditDays[];
   double             m_auditStarts[];
   double             m_auditMins[];
   bool               m_initialized;

   //--- Cierra el dia en curso y lo agrega a la auditoria.
   void FinalizeAuditDay()
     {
      if(m_auditDay == "")
         return;

      int index = ArraySize(m_auditDays);
      ArrayResize(m_auditDays, index + 1);
      ArrayResize(m_auditStarts, index + 1);
      ArrayResize(m_auditMins, index + 1);

      m_auditDays[index]   = m_auditDay;
      m_auditStarts[index] = m_auditStart;
      m_auditMins[index]   = m_auditMin;
      m_auditDay           = "";
     }

public:
   CBacktestMetrics()
     {
      Reset("", PERIOD_CURRENT, LM_STRATEGY_SCALPER_PRO);
     }

   void Reset(const string symbol, const ENUM_TIMEFRAMES timeframe,
              const ENUM_LM_STRATEGY strategy)
     {
      m_symbol          = symbol;
      m_timeframe       = LmBacktestTimeframeName(timeframe);
      m_strategy        = strategy;
      m_peakEquity      = 0.0;
      m_maxDrawdownPct  = 0.0;
      m_dailyLimitHits  = 0;
      m_dailyLimitDays  = "";
      m_lastBlockedDay  = "";
      m_auditDay        = "";
      m_auditStart      = 0.0;
      m_auditMin        = 0.0;
      ArrayResize(m_auditDays, 0);
      ArrayResize(m_auditStarts, 0);
      ArrayResize(m_auditMins, 0);
      m_initialized     = true;
     }

   //--- Sigue la equidad para el drawdown maximo observado y audita
   //--- el minimo de cada dia del servidor.
   void ObserveEquity(const datetime serverTime, const double equity)
     {
      if(!m_initialized || equity <= 0.0)
         return;

      string day = LmServerDayKey(serverTime);

      if(m_auditDay == "")
        {
         m_auditDay   = day;
         m_auditStart = equity;
         m_auditMin   = equity;
        }
      else if(day != m_auditDay)
        {
         FinalizeAuditDay();
         m_auditDay   = day;
         m_auditStart = equity;
         m_auditMin   = equity;
        }
      else if(equity < m_auditMin)
         m_auditMin = equity;

      if(equity > m_peakEquity)
         m_peakEquity = equity;

      if(m_peakEquity <= 0.0)
         return;

      double drawdown = (m_peakEquity - equity) / m_peakEquity * 100.0;
      if(drawdown > m_maxDrawdownPct)
         m_maxDrawdownPct = drawdown;
     }

   //--- Cuenta una activacion por dia del servidor, no por tick.
   void ObserveDaily(const DailyLossState &daily)
     {
      if(!m_initialized || !daily.initialized || !daily.blocked)
         return;

      if(daily.dayKey == m_lastBlockedDay)
         return;

      m_lastBlockedDay = daily.dayKey;
      m_dailyLimitHits++;

      if(m_dailyLimitDays != "")
         m_dailyLimitDays += ";";

      m_dailyLimitDays += daily.dayKey;

      PrintFormat("LM_DAILY_LIMIT day=%s equity=%s start=%s drop_pct=%s hits=%d",
                  daily.dayKey,
                  DoubleToString(daily.equity, 2),
                  DoubleToString(daily.startEquity, 2),
                  DoubleToString(daily.dropPct, 4),
                  m_dailyLimitHits);
     }

   double MaxDrawdownPct() { return(m_maxDrawdownPct); }
   int    DailyLimitHits() { return(m_dailyLimitHits); }

   //--- Dias auditados cuyo minimo de equidad alcanzo el limite.
   int AuditHits(const double limitPct)
     {
      int hits = 0;

      for(int i = 0; i < ArraySize(m_auditDays); i++)
        {
         if(LmDailyLimitReached(LmDailyDropPct(m_auditStarts[i],
                                              m_auditMins[i]), limitPct))
            hits++;
        }

      if(m_auditDay != "" &&
         LmDailyLimitReached(LmDailyDropPct(m_auditStart, m_auditMin), limitPct))
         hits++;

      return(hits);
     }

   //--- Detalle diario para verificar el conteo del guard.
   bool WriteDailyAudit(const string filename, const bool common,
                        const double limitPct)
     {
      FinalizeAuditDay();

      int flags = FILE_WRITE|FILE_CSV|FILE_ANSI;
      if(common)
         flags |= FILE_COMMON;

      int handle = FileOpen(filename, flags, ',');
      if(handle == INVALID_HANDLE)
         return(false);

      FileWrite(handle, "day", "start_equity", "min_equity", "drop_pct", "limit_hit");

      for(int i = 0; i < ArraySize(m_auditDays); i++)
        {
         double drop = LmDailyDropPct(m_auditStarts[i], m_auditMins[i]);
         bool hit = LmDailyLimitReached(drop, limitPct);

         FileWrite(handle, m_auditDays[i],
                   DoubleToString(m_auditStarts[i], 2),
                   DoubleToString(m_auditMins[i], 2),
                   DoubleToString(drop, 4),
                   hit ? "SI" : "NO");
        }

      FileClose(handle);
      return(true);
     }

   //--- Construye el resumen final de la corrida.
   BacktestSummary Build(const RuntimeResult &result, const RuntimeConfig &config,
                         const double finalBalance, const double finalEquity,
                         const double testerDrawdownPct)
     {
      BacktestSummary summary;

      summary.strategy           = LmStrategyName(m_strategy);
      summary.symbol             = m_symbol;
      summary.timeframe          = m_timeframe;
      summary.ticks              = result.ticks;
      summary.signalEvaluations  = result.signalEvaluations;
      summary.ordersSent         = result.ordersSent;
      summary.protectionUpdates  = result.protectionUpdates;
      summary.closures           = result.closures;
      summary.maxOrderVolume     = result.maxOrderVolume;
      summary.maxBasketVolume    = result.maxBasketVolume;
      summary.maxGridSteps       = result.maxGridSteps;
      summary.maxProjectedLoss   = result.maxProjectedLoss;
      summary.maxProjectedLossPct = result.maxProjectedLossPct;
      summary.maxDrawdownPct     = MathMax(m_maxDrawdownPct, testerDrawdownPct);
      summary.dailyLimitHits     = m_dailyLimitHits;
      summary.dailyLimitDays     = m_dailyLimitDays;
      summary.finalBalance       = finalBalance;
      summary.finalEquity        = finalEquity;
      summary.maxLotPerOrder     = config.risk.maxLotPerOrder;
      summary.maxVolumePerStrategy = config.risk.maxVolumePerStrategy;
      summary.maxGridStepsLimit  = config.risk.maxGridSteps;
      summary.maxBasketLossPct   = config.risk.maxBasketLossPct;

      //--- Atribucion por estrategia (modo portafolio ALL).
      summary.strategyCount = MathMin(MathMax(result.strategyCount, 0),
                                     LM_MAX_ACTIVE_STRATEGIES);
      summary.portfolio     = (summary.strategyCount > 1);
      summary.portfolioNet  = 0.0;

      for(int i = 0; i < LM_MAX_ACTIVE_STRATEGIES; i++)
        {
         summary.strategyNames[i]   = "";
         summary.strategyMagics[i]  = 0;
         summary.strategyNet[i]     = 0.0;
         summary.strategyMaxDrawdown[i] = 0.0;
         summary.strategyMaxVolume[i] = 0.0;
         summary.strategyMaxProjectedLossPct[i] = 0.0;
         summary.strategyOrders[i]  = 0;
        }

      for(int i = 0; i < summary.strategyCount; i++)
        {
         summary.strategyNames[i]  = result.strategyNames[i];
         summary.strategyMagics[i] = result.strategyMagics[i];
         summary.strategyOrders[i] = result.strategyOrders[i];
         summary.strategyMaxVolume[i] = result.strategyMaxVolume[i];
         summary.strategyMaxProjectedLossPct[i] = result.strategyMaxProjectedLossPct[i];
         summary.strategyMaxDrawdown[i] = result.strategyMaxDrawdown[i];
         summary.strategyNet[i] = LmHistoryNetByMagic(result.strategyMagics[i]);
         summary.portfolioNet += summary.strategyNet[i];
        }

      summary.maxAggregateVolume = result.maxAggregateVolume;
      summary.maxAggregateProjectedLossPct = result.maxAggregateProjectedLossPct;
      summary.aggregateVolumeLimit = config.risk.maxAggregateVolume;
      summary.aggregateLossPctLimit = config.risk.maxAggregateLossPct;
      summary.aggregateRespected =
         result.maxAggregateVolume <= config.risk.maxAggregateVolume + 1e-9 &&
         result.maxAggregateProjectedLossPct <= config.risk.maxAggregateLossPct + 1e-6;

      double eps = 1e-9;
      summary.limitsRespected =
         result.maxOrderVolume <= config.risk.maxLotPerOrder + eps &&
         result.maxBasketVolume <= config.risk.maxVolumePerStrategy + eps &&
         result.maxGridSteps <= config.risk.maxGridSteps &&
         result.maxProjectedLossPct <= config.risk.maxBasketLossPct + 1e-6 &&
         (!summary.portfolio || summary.aggregateRespected);

      return(summary);
     }

   //--- Nombre unico por corrida, sin depender del reloj del servidor.
   string UniqueFilename(const string prefix)
     {
      string stamp = TimeToString(TimeLocal(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      StringReplace(stamp, ".", "");
      StringReplace(stamp, ":", "");
      StringReplace(stamp, " ", "_");

      return(prefix + "_" + LmStrategySlug(m_strategy) + "_" + m_symbol + "_" +
             m_timeframe + "_" + stamp + "_" +
             IntegerToString((int)(GetTickCount() % 100000)) + ".csv");
     }

   //--- Escribe el resumen como CSV clave/valor.
   bool Write(const BacktestSummary &summary, const string filename,
              const bool common)
     {
      int flags = FILE_WRITE|FILE_CSV|FILE_ANSI;
      if(common)
         flags |= FILE_COMMON;

      int handle = FileOpen(filename, flags, ',');
      if(handle == INVALID_HANDLE)
         return(false);

      FileWrite(handle, "metric", "value");
      FileWrite(handle, "strategy", summary.strategy);
      FileWrite(handle, "symbol", summary.symbol);
      FileWrite(handle, "timeframe", summary.timeframe);
      FileWrite(handle, "ticks", IntegerToString(summary.ticks));
      FileWrite(handle, "signal_evaluations", IntegerToString(summary.signalEvaluations));
      FileWrite(handle, "orders_sent", IntegerToString(summary.ordersSent));
      FileWrite(handle, "protection_updates", IntegerToString(summary.protectionUpdates));
      FileWrite(handle, "closures", IntegerToString(summary.closures));
      FileWrite(handle, "max_order_volume", DoubleToString(summary.maxOrderVolume, 2));
      FileWrite(handle, "max_basket_volume", DoubleToString(summary.maxBasketVolume, 2));
      FileWrite(handle, "max_grid_steps", IntegerToString(summary.maxGridSteps));
      FileWrite(handle, "max_projected_loss", DoubleToString(summary.maxProjectedLoss, 2));
      FileWrite(handle, "max_projected_loss_pct", DoubleToString(summary.maxProjectedLossPct, 4));
      FileWrite(handle, "max_drawdown_pct", DoubleToString(summary.maxDrawdownPct, 4));
      FileWrite(handle, "daily_limit_hits", IntegerToString(summary.dailyLimitHits));
      FileWrite(handle, "daily_limit_days", summary.dailyLimitDays);
      FileWrite(handle, "final_balance", DoubleToString(summary.finalBalance, 2));
      FileWrite(handle, "final_equity", DoubleToString(summary.finalEquity, 2));
      FileWrite(handle, "max_lot_per_order_limit", DoubleToString(summary.maxLotPerOrder, 2));
      FileWrite(handle, "max_volume_per_strategy_limit", DoubleToString(summary.maxVolumePerStrategy, 2));
      FileWrite(handle, "max_grid_steps_limit", IntegerToString(summary.maxGridStepsLimit));
      FileWrite(handle, "max_basket_loss_pct_limit", DoubleToString(summary.maxBasketLossPct, 2));
      FileWrite(handle, "limits_respected", summary.limitsRespected ? "SI" : "NO");
      FileWrite(handle, "portfolio_mode", summary.portfolio ? "SI" : "NO");
      FileWrite(handle, "strategy_count", IntegerToString(summary.strategyCount));
      FileWrite(handle, "portfolio_net", DoubleToString(summary.portfolioNet, 2));
      FileWrite(handle, "max_aggregate_volume", DoubleToString(summary.maxAggregateVolume, 2));
      FileWrite(handle, "max_aggregate_loss_pct", DoubleToString(summary.maxAggregateProjectedLossPct, 4));
      FileWrite(handle, "max_aggregate_volume_limit", DoubleToString(summary.aggregateVolumeLimit, 2));
      FileWrite(handle, "max_aggregate_loss_pct_limit", DoubleToString(summary.aggregateLossPctLimit, 2));
      FileWrite(handle, "aggregate_respected", summary.aggregateRespected ? "SI" : "NO");

      for(int i = 0; i < summary.strategyCount; i++)
        {
         string prefix = "attr_" + IntegerToString(i) + "_";
         FileWrite(handle, prefix + "strategy", summary.strategyNames[i]);
         FileWrite(handle, prefix + "magic", IntegerToString((int)summary.strategyMagics[i]));
         FileWrite(handle, prefix + "net", DoubleToString(summary.strategyNet[i], 2));
         FileWrite(handle, prefix + "max_drawdown", DoubleToString(summary.strategyMaxDrawdown[i], 2));
         FileWrite(handle, prefix + "max_volume", DoubleToString(summary.strategyMaxVolume[i], 2));
         FileWrite(handle, prefix + "max_projected_loss_pct", DoubleToString(summary.strategyMaxProjectedLossPct[i], 4));
         FileWrite(handle, prefix + "orders", IntegerToString(summary.strategyOrders[i]));
        }

      FileClose(handle);
      return(true);
     }

   void Log(const BacktestSummary &summary, const string filename)
     {
      PrintFormat("LM_BACKTEST strategy=%s symbol=%s tf=%s ticks=%d signals=%d orders=%d " +
                  "max_order=%s max_basket=%s max_steps=%d max_loss_pct=%s max_dd_pct=%s " +
                  "daily_hits=%d daily_days=%s limits_ok=%s file=%s",
                  summary.strategy, summary.symbol, summary.timeframe,
                  summary.ticks, summary.signalEvaluations, summary.ordersSent,
                  DoubleToString(summary.maxOrderVolume, 2),
                  DoubleToString(summary.maxBasketVolume, 2),
                  summary.maxGridSteps,
                  DoubleToString(summary.maxProjectedLossPct, 4),
                  DoubleToString(summary.maxDrawdownPct, 4),
                  summary.dailyLimitHits, summary.dailyLimitDays,
                  summary.limitsRespected ? "SI" : "NO", filename);

      if(!summary.portfolio)
         return;

      PrintFormat("LM_BACKTEST PORTFOLIO net=%s max_agg_volume=%s max_agg_loss_pct=%s " +
                  "agg_ok=%s strategies=%d",
                  DoubleToString(summary.portfolioNet, 2),
                  DoubleToString(summary.maxAggregateVolume, 2),
                  DoubleToString(summary.maxAggregateProjectedLossPct, 4),
                  summary.aggregateRespected ? "SI" : "NO",
                  summary.strategyCount);

      for(int i = 0; i < summary.strategyCount; i++)
         PrintFormat("LM_BACKTEST ATTR strategy=%s magic=%I64d net=%s dd=%s " +
                     "max_volume=%s loss_pct=%s orders=%d",
                     summary.strategyNames[i], summary.strategyMagics[i],
                     DoubleToString(summary.strategyNet[i], 2),
                     DoubleToString(summary.strategyMaxDrawdown[i], 2),
                     DoubleToString(summary.strategyMaxVolume[i], 2),
                     DoubleToString(summary.strategyMaxProjectedLossPct[i], 4),
                     summary.strategyOrders[i]);
     }
  };

#endif // LMROBOT_HARNESS_BACKTESTMETRICS_MQH
