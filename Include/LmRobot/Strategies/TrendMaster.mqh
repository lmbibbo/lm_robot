//+------------------------------------------------------------------+
//|                                                  TrendMaster.mqh |
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#ifndef LMROBOT_STRATEGIES_TRENDMASTER_MQH
#define LMROBOT_STRATEGIES_TRENDMASTER_MQH

#include "Signal.mqh"

//+------------------------------------------------------------------+
//| Senal pura de TrendMaster.                                       |
//| Regla MT4: close[2] > close[1] -> SELL si RSI > 30; en caso      |
//| contrario -> BUY si RSI < 70. Fuera de esas condiciones NONE.    |
//| No calcula volumen, SL, TP ni decide si la orden se envia.       |
//+------------------------------------------------------------------+
ENUM_SIGNAL_DIRECTION LmTrendMasterSignal(const double close2, const double close1,
                                          const bool hasRsi, const double rsi)
  {
   //--- Sin lectura de RSI no se puede confirmar ninguna rama.
   if(!hasRsi)
      return(SIGNAL_NONE);

   if(close2 > close1)
     {
      if(rsi > 30.0)
         return(SIGNAL_SELL);

      return(SIGNAL_NONE);
     }

   if(rsi < 70.0)
      return(SIGNAL_BUY);

   return(SIGNAL_NONE);
  }

#endif // LMROBOT_STRATEGIES_TRENDMASTER_MQH
