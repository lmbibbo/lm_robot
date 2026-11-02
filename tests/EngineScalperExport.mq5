//+------------------------------------------------------------------+
//|                                           EngineScalperExport.mq5|
//|                              lm_robot - exportacion del motor    |
//+------------------------------------------------------------------+
#property copyright "lm_robot"
#property version   "1.00"
#property description "Exporta la senal Scalper del motor nuevo, una fila por barra cerrada."

#include "../Include/LmRobot/Strategies/Scalper.mqh"
#include "../Include/LmRobot/Harness/SignalCsv.mqh"

input datetime StartDate  = D'2026.01.01 00:00:00';
input datetime EndDate    = D'2026.06.30 23:59:59';
input string   OutputFile = "lm_robot_engine_scalper_AUDCAD_H1.csv";

//+------------------------------------------------------------------+
//| Exporta una fila por barra cerrada evaluada.                     |
//+------------------------------------------------------------------+
int OnInit()
  {
   MqlRates rates[];
   int copied = CopyRates(_Symbol, _Period, StartDate, EndDate, rates);

   if(copied <= 1)
     {
      PrintFormat("ENGINE_EXPORT ERROR copied=%d error=%d", copied, GetLastError());
      return(INIT_FAILED);
     }

   ArraySetAsSeries(rates, false);

   int last = copied - 1;
   if(rates[last].time + PeriodSeconds(_Period) > TimeCurrent())
      last--;

   if(last < 1)
     {
      PrintFormat("ENGINE_EXPORT ERROR no hay barras cerradas en el rango");
      return(INIT_FAILED);
     }

   CSignalCsvWriter writer;
   if(!writer.Open(OutputFile))
     {
      PrintFormat("ENGINE_EXPORT ERROR no se pudo abrir %s", OutputFile);
      return(INIT_FAILED);
     }

   string timeframe = LmTimeframeName(_Period);
   int rows = 0;

   for(int i = 1; i <= last; i++)
     {
      ENUM_SIGNAL_DIRECTION direction =
         LmScalperSignal(rates[i].close, rates[i - 1].close);

      if(!writer.WriteRow(rates[i].time, "Scalper", direction, timeframe))
        {
         writer.Close();
         PrintFormat("ENGINE_EXPORT ERROR escribiendo la fila %d", i);
         return(INIT_FAILED);
        }

      rows++;
     }

   writer.Close();

   PrintFormat("ENGINE_EXPORT OK bars=%d rows=%d first=%s last=%s file=%s timeframe=%s",
               copied, rows,
               TimeToString(rates[1].time, TIME_DATE|TIME_SECONDS),
               TimeToString(rates[last].time, TIME_DATE|TIME_SECONDS),
               OutputFile, timeframe);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Sin operaciones: la exportacion ocurre en OnInit.                |
//+------------------------------------------------------------------+
void OnTick()
  {
  }
