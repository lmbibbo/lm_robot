//+------------------------------------------------------------------+
//|                                                     Scalper.mqh  |
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#ifndef LMROBOT_STRATEGIES_SCALPER_MQH
#define LMROBOT_STRATEGIES_SCALPER_MQH

#include "Signal.mqh"

//+------------------------------------------------------------------+
//| Senal pura de Scalper Pro.                                       |
//| Regla MT4: close[2] > close[1] -> SELL; en caso contrario BUY.   |
//| No calcula volumen, SL, TP ni decide si la orden se envia.       |
//+------------------------------------------------------------------+
ENUM_SIGNAL_DIRECTION LmScalperSignal(const double close2, const double close1)
  {
   if(close2 > close1)
      return(SIGNAL_SELL);

   return(SIGNAL_BUY);
  }

#endif // LMROBOT_STRATEGIES_SCALPER_MQH
