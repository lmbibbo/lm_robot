//+------------------------------------------------------------------+
//|                                                    Strategy.mqh  |
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#ifndef LMROBOT_STRATEGIES_STRATEGY_MQH
#define LMROBOT_STRATEGIES_STRATEGY_MQH

#include "Scalper.mqh"
#include "Fibonacci.mqh"
#include "TrendMaster.mqh"

//--- Maximo de estrategias que pueden correr en una instancia.
#define LM_MAX_ACTIVE_STRATEGIES 3

//+------------------------------------------------------------------+
//| Estrategia activa de la instancia.                               |
//| ALL activa las tres en una sola instancia (modo portafolio).     |
//+------------------------------------------------------------------+
enum ENUM_LM_STRATEGY
  {
   LM_STRATEGY_SCALPER_PRO     = 0,
   LM_STRATEGY_FIBONACCI_FOCUS = 1,
   LM_STRATEGY_TREND_MASTER    = 2,
   LM_STRATEGY_ALL             = 3
  };

//+------------------------------------------------------------------+
//| Valida el valor recibido por input.                              |
//+------------------------------------------------------------------+
bool LmStrategyIsValid(const ENUM_LM_STRATEGY strategy)
  {
   return(strategy == LM_STRATEGY_SCALPER_PRO ||
          strategy == LM_STRATEGY_FIBONACCI_FOCUS ||
          strategy == LM_STRATEGY_TREND_MASTER ||
          strategy == LM_STRATEGY_ALL);
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

   if(strategy == LM_STRATEGY_ALL)
      return("Portafolio ALL");

   return("Desconocida");
  }

//+------------------------------------------------------------------+
//| Resuelve la seleccion en la lista de estrategias activas.        |
//| ALL devuelve las tres; cualquier otra devuelve una sola.         |
//+------------------------------------------------------------------+
int LmResolveStrategyList(const ENUM_LM_STRATEGY selection,
                          ENUM_LM_STRATEGY &list[])
  {
   ArrayResize(list, 0);

   if(selection == LM_STRATEGY_ALL)
     {
      ArrayResize(list, LM_MAX_ACTIVE_STRATEGIES);
      list[0] = LM_STRATEGY_SCALPER_PRO;
      list[1] = LM_STRATEGY_FIBONACCI_FOCUS;
      list[2] = LM_STRATEGY_TREND_MASTER;
      return(LM_MAX_ACTIVE_STRATEGIES);
     }

   if(!LmStrategyIsValid(selection))
      return(0);

   ArrayResize(list, 1);
   list[0] = selection;
   return(1);
  }

//+------------------------------------------------------------------+
//| Magic de una estrategia activa.                                  |
//| Modo unico: el magic base. Modo ALL: MagicNumber + indice.       |
//+------------------------------------------------------------------+
long LmStrategyMagic(const long baseMagic,
                     const ENUM_LM_STRATEGY selection,
                     const int index)
  {
   if(selection != LM_STRATEGY_ALL)
      return(baseMagic);

   return(baseMagic + (long)index);
  }

//+------------------------------------------------------------------+
//| Evalua una estrategia concreta.                                  |
//| close1/high1 son la barra cerrada (shift 1); close2/low2 la      |
//| anterior (shift 2). Todas las estrategias comparten el mismo     |
//| contrato: solo devuelven BUY, SELL o NONE.                       |
//| ALL no es una senal: el runtime itera las tres por separado.     |
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
