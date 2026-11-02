//+------------------------------------------------------------------+
//|                                                   Instrument.mqh |
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#ifndef LMROBOT_CORE_INSTRUMENT_MQH
#define LMROBOT_CORE_INSTRUMENT_MQH

//+------------------------------------------------------------------+
//| Propiedades del instrumento normalizadas a pips.                 |
//+------------------------------------------------------------------+
struct InstrumentInfo
  {
   string            symbol;
   int               digits;
   double            point;
   double            pipSize;
   double            tickSize;
   double            tickValue;
   double            pipValuePerLot;
   int               stopsLevel;
   int               freezeLevel;
   bool              valid;
  };

//+------------------------------------------------------------------+
//| Tamano del pip en precio.                                        |
//| Los simbolos de 3 y 5 digitos usan 10 puntos por pip; los de 2   |
//| y 4 digitos usan 1 punto por pip.                                |
//+------------------------------------------------------------------+
double LmPipSize(const int digits, const double point)
  {
   if(point <= 0.0)
      return(0.0);

   if(digits == 3 || digits == 5)
      return(point * 10.0);

   return(point);
  }

//+------------------------------------------------------------------+
//| Valor del pip por 1 lote: tick_value / (tick_size / pip_size).   |
//+------------------------------------------------------------------+
double LmPipValuePerLot(const double tickValue, const double tickSize, const double pipSize)
  {
   if(tickSize <= 0.0 || pipSize <= 0.0)
      return(0.0);

   return(tickValue / (tickSize / pipSize));
  }

//+------------------------------------------------------------------+
//| Convierte una distancia en pips a puntos.                        |
//+------------------------------------------------------------------+
double LmPipsToPoints(const double pips, const double pipSize, const double point)
  {
   if(point <= 0.0 || pipSize <= 0.0)
      return(0.0);

   return(pips * pipSize / point);
  }

//+------------------------------------------------------------------+
//| Convierte una distancia en puntos a pips.                        |
//+------------------------------------------------------------------+
double LmPointsToPips(const double points, const double pipSize, const double point)
  {
   if(point <= 0.0 || pipSize <= 0.0)
      return(0.0);

   return(points * point / pipSize);
  }

//+------------------------------------------------------------------+
//| Lee y normaliza las propiedades del simbolo.                     |
//+------------------------------------------------------------------+
bool LmLoadInstrument(const string symbol, InstrumentInfo &info)
  {
   info.symbol         = symbol;
   info.digits         = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   info.point          = SymbolInfoDouble(symbol, SYMBOL_POINT);
   info.tickSize       = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   info.tickValue      = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   info.stopsLevel     = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   info.freezeLevel    = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   info.pipSize        = LmPipSize(info.digits, info.point);
   info.pipValuePerLot = LmPipValuePerLot(info.tickValue, info.tickSize, info.pipSize);
   info.valid          = (info.digits > 0 && info.point > 0.0 && info.pipSize > 0.0 && info.tickSize > 0.0);

   return(info.valid);
  }

#endif // LMROBOT_CORE_INSTRUMENT_MQH
