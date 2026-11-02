//+------------------------------------------------------------------+
//|                                                     LmRobot.mq5 |
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#property copyright "lm_robot"
#property version   "1.00"
#property description "Motor de trading MQL5. Scaffold inicial del proyecto."

#include "../Include/LmRobot/Core/MarketContext.mqh"

//--- Contexto de mercado
input ENUM_TIMEFRAMES AtrTimeframe = PERIOD_CURRENT; // Timeframe del ATR
input int             AtrPeriod    = 14;             // Periodo del ATR
input double          MaxSpreadPips = 3.0;           // Spread maximo para entradas (pips)
input double          MaxAtrPips    = 30.0;          // ATR maximo para entradas (pips)

//--- Periodo fijo del RSI usado por las estrategias
#define LM_RSI_PERIOD 14

CMarketContext g_market;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   ENUM_TIMEFRAMES atrTimeframe = (AtrTimeframe == PERIOD_CURRENT ? _Period : AtrTimeframe);

   if(!g_market.Init(_Symbol, _Period, LM_RSI_PERIOD, atrTimeframe, AtrPeriod,
                     MaxSpreadPips, MaxAtrPips))
     {
      Print("LmRobot: inicializacion fallida: no se pudieron crear los handles de RSI/ATR o el instrumento no es valido");
      return(INIT_FAILED);
     }

   InstrumentInfo instrument = g_market.Instrument();
   PrintFormat("LmRobot: contexto inicializado en %s (digits=%d, pip=%s, valor_pip_lote=%s)",
               _Symbol, instrument.digits,
               DoubleToString(instrument.pipSize, instrument.digits),
               DoubleToString(instrument.pipValuePerLot, 2));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_market.ReleaseHandles();
  }

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- Un solo refresco por tick; los consumidores leen el snapshot.
   g_market.Refresh();
  }
//+------------------------------------------------------------------+
