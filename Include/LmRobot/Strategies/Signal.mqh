//+------------------------------------------------------------------+
//|                                                      Signal.mqh  |
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#ifndef LMROBOT_STRATEGIES_SIGNAL_MQH
#define LMROBOT_STRATEGIES_SIGNAL_MQH

//+------------------------------------------------------------------+
//| Direccion de una senal. Solo existen tres resultados posibles.   |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_DIRECTION
  {
   SIGNAL_NONE = 0,
   SIGNAL_BUY  = 1,
   SIGNAL_SELL = 2
  };

//+------------------------------------------------------------------+
//| Nombre estable para CSV y reportes.                              |
//+------------------------------------------------------------------+
string LmSignalDirectionName(const ENUM_SIGNAL_DIRECTION direction)
  {
   if(direction == SIGNAL_BUY)
      return("BUY");

   if(direction == SIGNAL_SELL)
      return("SELL");

   return("NONE");
  }

//+------------------------------------------------------------------+
//| Convierte el nombre del CSV a la direccion.                      |
//+------------------------------------------------------------------+
ENUM_SIGNAL_DIRECTION LmSignalDirectionFromName(const string name)
  {
   if(StringCompare(name, "BUY", false) == 0)
      return(SIGNAL_BUY);

   if(StringCompare(name, "SELL", false) == 0)
      return(SIGNAL_SELL);

   return(SIGNAL_NONE);
  }

//+------------------------------------------------------------------+
//| Nombre corto del timeframe, por ejemplo H1 o M15.                |
//+------------------------------------------------------------------+
string LmTimeframeName(const ENUM_TIMEFRAMES timeframe)
  {
   string name = EnumToString(timeframe);

   if(StringFind(name, "PERIOD_") == 0)
      name = StringSubstr(name, 7);

   return(name);
  }

#endif // LMROBOT_STRATEGIES_SIGNAL_MQH
