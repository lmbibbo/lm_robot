//+------------------------------------------------------------------+
//|                                                     LmRobot.mq5 |
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#property copyright "lm_robot"
#property version   "1.00"
#property description "Motor de trading MQL5 con una estrategia por instancia o portafolio Strategy=ALL."

#include "../Include/LmRobot/Core/Account.mqh"
#include "../Include/LmRobot/Core/Runtime.mqh"
#include "../Include/LmRobot/Harness/BacktestMetrics.mqh"
#include "../Include/LmRobot/UI/Dashboard.mqh"

//--- Estrategia y ejecucion
input ENUM_LM_STRATEGY Strategy = LM_STRATEGY_SCALPER_PRO; // Estrategia activa
input int             MagicNumber = 20261103;              // Magic number de la instancia
input int             MaxAttempts = 3;                     // Intentos maximos por orden
input int             RetryDelayMs = 250;                  // Espera entre intentos (ms)
input int             DeadlineMs = 3000;                   // Deadline total por operacion (ms)

//--- Contexto de mercado
input ENUM_TIMEFRAMES AtrTimeframe = PERIOD_CURRENT; // Timeframe del ATR
input int             AtrPeriod    = 14;             // Periodo del ATR
input double          MaxSpreadPips = 3.0;           // Spread maximo para entradas (pips)
input double          MaxAtrPips    = 30.0;          // ATR maximo para entradas (pips)

//--- Riesgo
input double RiskPct               = 0.5;  // Riesgo de la primera orden (% del balance)
input double MaxBasketLossPct      = 2.0;  // Perdida maxima proyectada de la canasta (%)
input double DailyLossLimitPct     = 4.0;  // Caida diaria maxima de equidad (%)
input int    MaxGridSteps          = 4;    // Pasos de grid maximos
input double LotMultiplier         = 1.5;  // Multiplicador de volumen entre pasos
input double MaxLotPerOrder        = 0.10; // Volumen maximo por orden
input double MaxVolumePerStrategy  = 0.30; // Volumen maximo de la canasta
input double SlPips                = 40.0; // Distancia del SL de canasta (pips)
input double TpPips                = 8.0;  // Distancia del TP de canasta (pips)
input double GridStepPips          = 22.0; // Distancia para el siguiente paso (pips)

//--- Presupuesto agregado de la instancia (modo Strategy=ALL)
input double MaxAggregateLossPct   = 6.0;  // Perdida agregada de la instancia (%)
input double MaxAggregateVolume    = 0.90; // Volumen concurrente agregado (lotes)

//--- Sesion
input bool UseSessionFilter = false; // Habilita el filtro de sesion
input int  SessionStartHour = 8;     // Hora de inicio (servidor)
input int  SessionEndHour   = 17;    // Hora de fin (servidor, 24 = medianoche)

//--- Periodo fijo del RSI usado por las estrategias
#define LM_RSI_PERIOD 14

//--- Modulos del motor
CMarketContext            g_market;
CLiveBarSource            g_bars;
CLiveBasketSource         g_baskets;
CLiveExecutionBackend     g_backend;
CLiveAccountInfoProvider  g_accounts;
CGlobalVariableDailyStore g_globalDailyStore;
CMemoryDailyStore         g_memoryDailyStore;
IDailyStateStore         *g_dailyStore = NULL;
CDailyLossGuard           g_daily;
CExecutor                 g_executor;
CLmRuntime                g_runtime;
CChartDashboardRenderer   g_dashboardRenderer;
CDashboard                g_dashboard;
CBacktestMetrics          g_metrics;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- 1. La cuenta debe ser hedging.
   ENUM_ACCOUNT_MARGIN_MODE marginMode =
      (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   string accountError = LmAccountModeError(marginMode);
   if(accountError != "")
     {
      PrintFormat("LmRobot: %s", accountError);
      return(INIT_FAILED);
     }

   //--- 2. La estrategia debe ser valida.
   if(!LmStrategyIsValid(Strategy))
     {
      PrintFormat("LmRobot: estrategia invalida (%d)", (int)Strategy);
      return(INIT_FAILED);
     }

   //--- 3. Parametros de sesion y riesgo.
   SessionConfig session;
   session.enabled   = UseSessionFilter;
   session.startHour = SessionStartHour;
   session.endHour   = SessionEndHour;

   if(!LmSessionConfigValid(session))
     {
      PrintFormat("LmRobot: sesion invalida (%d-%d)", SessionStartHour, SessionEndHour);
      return(INIT_FAILED);
     }

   if(RiskPct <= 0.0 || MaxBasketLossPct <= 0.0 || DailyLossLimitPct <= 0.0 ||
      MaxGridSteps < 0 || LotMultiplier <= 0.0 || MaxLotPerOrder <= 0.0 ||
      MaxVolumePerStrategy <= 0.0 || SlPips <= 0.0 || TpPips <= 0.0 ||
      GridStepPips <= 0.0 || MaxSpreadPips <= 0.0 || MaxAtrPips <= 0.0 ||
      MaxAggregateLossPct <= 0.0 || MaxAggregateVolume <= 0.0)
     {
      Print("LmRobot: parametros de riesgo invalidos");
      return(INIT_FAILED);
     }

   //--- 4. Contexto de mercado: handles RSI/ATR una sola vez.
   ENUM_TIMEFRAMES atrTimeframe = (AtrTimeframe == PERIOD_CURRENT ? _Period : AtrTimeframe);

   if(!g_market.Init(_Symbol, _Period, LM_RSI_PERIOD, atrTimeframe, AtrPeriod,
                     MaxSpreadPips, MaxAtrPips))
     {
      Print("LmRobot: inicializacion fallida: no se pudieron crear los handles de RSI/ATR o el instrumento no es valido");
      return(INIT_FAILED);
     }

   //--- 5. Limite diario: persistente en produccion, aislado en el tester.
   long account = (long)AccountInfoInteger(ACCOUNT_LOGIN);
   if(account == 0)
      account = 1;

   if(MQLInfoInteger(MQL_TESTER))
      g_dailyStore = &g_memoryDailyStore;
   else
      g_dailyStore = &g_globalDailyStore;

   if(!g_daily.Init(g_dailyStore, account, DailyLossLimitPct))
     {
      Print("LmRobot: no se pudo inicializar el limite de perdida diaria");
      return(INIT_FAILED);
     }

   //--- 6. Ejecucion acotada.
   SymbolLimits limits;
   if(!LmLoadSymbolLimits(_Symbol, limits))
     {
      PrintFormat("LmRobot: limites de simbolo invalidos para %s", _Symbol);
      return(INIT_FAILED);
     }

   ExecutorConfig execution;
   execution.maxAttempts  = (MaxAttempts > 0 ? MaxAttempts : 1);
   execution.retryDelayMs = MathMax(0, RetryDelayMs);
   execution.deadlineMs   = MathMax(0, DeadlineMs);
   execution.magic        = (long)MagicNumber;

   g_backend.SetMagic(execution.magic);

   if(!g_executor.Init(&g_backend, &g_accounts, limits, execution))
     {
      Print("LmRobot: no se pudo inicializar el ejecutor");
      return(INIT_FAILED);
     }

   //--- 7. Runtime.
   RuntimeConfig config;
   config.magic    = execution.magic;
   config.strategy = Strategy;
   config.risk     = LmDefaultRiskConfig();
   config.session  = session;

   config.risk.riskPct             = RiskPct;
   config.risk.maxBasketLossPct    = MaxBasketLossPct;
   config.risk.dailyLossLimitPct   = DailyLossLimitPct;
   config.risk.maxGridSteps        = MaxGridSteps;
   config.risk.lotMultiplier       = LotMultiplier;
   config.risk.maxLotPerOrder      = MaxLotPerOrder;
   config.risk.maxVolumePerStrategy = MaxVolumePerStrategy;
   config.risk.slPips              = SlPips;
   config.risk.tpPips              = TpPips;
   config.risk.gridStepPips        = GridStepPips;
   config.risk.maxSpreadPips       = MaxSpreadPips;
   config.risk.maxAggregateLossPct = MaxAggregateLossPct;
   config.risk.maxAggregateVolume  = MaxAggregateVolume;

   g_bars.Init(_Symbol, _Period, g_market.RsiHandle());
   g_baskets.Init(_Symbol);
   g_metrics.Reset(_Symbol, _Period, Strategy);

   if(!g_runtime.Init(&g_market, &g_baskets, &g_bars, &g_executor,
                      &g_daily, config))
     {
      Print("LmRobot: no se pudo inicializar el runtime");
      return(INIT_FAILED);
     }

   //--- 8. Panel de estado con dirty flag.
   if(!g_dashboard.Init(&g_dashboardRenderer))
     {
      Print("LmRobot: no se pudo inicializar el panel");
      return(INIT_FAILED);
     }

   InstrumentInfo instrument = g_market.Instrument();
   PrintFormat("LmRobot: runtime inicializado en %s (estrategia=%s, digits=%d, pip=%s, valor_pip_lote=%s, cuenta=%s)",
               _Symbol, LmStrategyName(Strategy), instrument.digits,
               DoubleToString(instrument.pipSize, instrument.digits),
               DoubleToString(instrument.pipValuePerLot, 2),
               LmAccountModeName(marginMode));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   //--- El panel elimina sus objetos y limpia el comentario del grafico.
   g_dashboard.Clear();
   g_market.ReleaseHandles();
  }

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- Un solo refresco por tick; los consumidores leen el snapshot.
   if(!g_market.Refresh())
      return;

   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   datetime serverTime = TimeTradeServer();

   g_runtime.ProcessTick(serverTime, equity, balance);

   //--- Metricas de la corrida: drawdown observado y limite diario.
   g_metrics.ObserveEquity(serverTime, equity);
   g_metrics.ObserveDaily(g_runtime.DailyState());

   //--- El panel solo se redibuja cuando cambio un campo relevante.
   RuntimeConfig config = g_runtime.Config();
   StrategyView views[LM_MAX_ACTIVE_STRATEGIES];
   int viewCount = g_runtime.StrategyCount();

   for(int i = 0; i < viewCount; i++)
     {
      long magic = 0;
      ENUM_LM_STRATEGY strategy = LM_STRATEGY_SCALPER_PRO;
      g_runtime.StrategyAt(i, strategy, views[i].basket, magic);
      views[i].strategy = strategy;
     }

   DashboardState panel = LmBuildPortfolioDashboardState(views, viewCount,
                                                          config.risk,
                                                          g_runtime.DailyState(),
                                                          g_market.Instrument(),
                                                          balance,
                                                          equity);

   g_dashboard.Update(panel, _Symbol);
  }

//+------------------------------------------------------------------+
//| Metricas de la corrida y artefacto por backtest.                 |
//+------------------------------------------------------------------+
double OnTester()
  {
   double finalBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double finalEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double testerDd     = TesterStatistics(STAT_EQUITYDD_PERCENT);

   BacktestSummary summary = g_metrics.Build(g_runtime.Result(),
                                             g_runtime.Config(),
                                             finalBalance,
                                             finalEquity,
                                             testerDd);

   string filename = g_metrics.UniqueFilename("lm_robot_run");
   string auditFilename = StringSubstr(filename, 0, StringLen(filename) - 4) + "_daily.csv";
   double dailyLimit = g_runtime.Config().risk.dailyLossLimitPct;

   if(g_metrics.Write(summary, filename, true))
      g_metrics.Log(summary, filename);
   else
      PrintFormat("LM_BACKTEST ERROR no se pudo escribir %s", filename);

   if(g_metrics.WriteDailyAudit(auditFilename, true, dailyLimit))
     {
      int auditHits = g_metrics.AuditHits(dailyLimit);
      PrintFormat("LM_DAILY_AUDIT guard=%d audit=%d ok=%s file=%s",
                  summary.dailyLimitHits, auditHits,
                  (auditHits == summary.dailyLimitHits ? "SI" : "NO"),
                  auditFilename);
     }
   else
      PrintFormat("LM_DAILY_AUDIT ERROR no se pudo escribir %s", auditFilename);

   return(TesterStatistics(STAT_PROFIT));
  }
//+------------------------------------------------------------------+
