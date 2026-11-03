//+------------------------------------------------------------------+
//|                                                    Strategy.mqh  |
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#ifndef LMROBOT_STRATEGIES_STRATEGY_MQH
#define LMROBOT_STRATEGIES_STRATEGY_MQH

#include "Scalper.mqh"
#include "Fibonacci.mqh"
#include "TrendMaster.mqh"

//+------------------------------------------------------------------+
//| Estrategia activa de la instancia.                               |
//+------------------------------------------------------------------+
enum ENUM_LM_STRATEGY
  {
   LM_STRATEGY_SCALPER_PRO     = 0,
   LM_STRATEGY_FIBONACCI_FOCUS = 1,
   LM_STRATEGY_TREND_MASTER    = 2
  };

//+------------------------------------------------------------------+
//| Valida el valor recibido por input.                              |
//+------------------------------------------------------------------+
bool LmStrategyIsValid(const ENUM_LM_STRATEGY strategy)
  {
   return(strategy == LM_STRATEGY_SCALPER_PRO ||
          strategy == LM_STRATEGY_FIBONACCI_FOCUS ||
          strategy == LM_STRATEGY_TREND_MASTER);
  }

//+------------------------------------------------------------------+
//| Nombre estable para el log y el panel.                           |
//+------------------------------------------------------------------+
string LmStrategyName(const ENUM_LM_STRATEGY strategy)
  {
   if(strategy == LM_STRATEGY_SCALPER_PRO)
      return("Scalper Pro");

   if(strategy == LM_STRATEGY_FIBONACCI_FOCUS)
      return("Fibonacci Focus");

   if(strategy == LM_STRATEGY_TREND_MASTER)
      return("TrendMaster");

   return("Desconocida");
  }

//+------------------------------------------------------------------+
//| Evalua la estrategia seleccionada.                               |
//| close1/high1 son la barra cerrada (shift 1); close2/low2 la      |
//| anterior (shift 2). Todas las estrategias comparten el mismo     |
//| contrato: solo devuelven BUY, SELL o NONE.                       |
//+------------------------------------------------------------------+
ENUM_SIGNAL_DIRECTION LmEvaluateStrategy(const ENUM_LM_STRATEGY strategy,
                                         const double close1, const double close2,
                                         const double high1, const double low2,
                                         const bool hasRsi, const double rsi)
  {
   if(strategy == LM_STRATEGY_SCALPER_PRO)
      return(LmScalperSignal(close2, close1));

   if(strategy == LM_STRATEGY_FIBONACCI_FOCUS)
      return(LmFibonacciSignal(high1, low2, hasRsi, rsi));

   if(strategy == LM_STRATEGY_TREND_MASTER)
      return(LmTrendMasterSignal(close2, close1, hasRsi, rsi));

   return(SIGNAL_NONE);
  }

#endif // LMROBOT_STRATEGIES_STRATEGY_MQH
