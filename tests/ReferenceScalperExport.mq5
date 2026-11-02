//+------------------------------------------------------------------+
//|                                        ReferenceScalperExport.mq5|
//|                         lm_robot - port "solo senales" de MT4    |
//+------------------------------------------------------------------+
#property copyright "lm_robot"
#property version   "1.00"
#property description "Exporta la senal Scalper de referencia, sin riesgo ni ejecucion."

#include "../Include/LmRobot/Harness/SignalCsv.mqh"

input datetime StartDate  = D'2026.01.01 00:00:00';
input datetime EndDate    = D'2026.06.30 23:59:59';
input string   OutputFile = "lm_robot_reference_scalper_AUDCAD_H1.csv";

//+------------------------------------------------------------------+
//| Regla MT4 de Scalper Pro, independiente del motor nuevo.         |
//+------------------------------------------------------------------+
ENUM_SIGNAL_DIRECTION ReferenceScalperSignal(const double close2, const double close1)
  {
   if(close2 > close1)
      return(SIGNAL_SELL);

   return(SIGNAL_BUY);
  }

//+------------------------------------------------------------------+
//| Exporta una fila por barra cerrada evaluada.                     |
//+------------------------------------------------------------------+
int OnInit()
  {
   MqlRates rates[];
   int copied = CopyRates(_Symbol, _Period, StartDate, EndDate, rates);

   if(copied <= 1)
     {
      PrintFormat("REFERENCE_EXPORT ERROR copied=%d error=%d", copied, GetLastError());
      return(INIT_FAILED);
     }

   ArraySetAsSeries(rates, false);

   int last = copied - 1;
   if(rates[last].time + PeriodSeconds(_Period) > TimeCurrent())
      last--;

   if(last < 1)
     {
      PrintFormat("REFERENCE_EXPORT ERROR no hay barras cerradas en el rango");
      return(INIT_FAILED);
     }

   CSignalCsvWriter writer;
   if(!writer.Open(OutputFile))
     {
      PrintFormat("REFERENCE_EXPORT ERROR no se pudo abrir %s", OutputFile);
      return(INIT_FAILED);
     }

   string timeframe = LmTimeframeName(_Period);
   int rows = 0;

   for(int i = 1; i <= last; i++)
     {
      ENUM_SIGNAL_DIRECTION direction =
         ReferenceScalperSignal(rates[i].close, rates[i - 1].close);

      if(!writer.WriteRow(rates[i].time, "Scalper", direction, timeframe))
        {
         writer.Close();
         PrintFormat("REFERENCE_EXPORT ERROR escribiendo la fila %d", i);
         return(INIT_FAILED);
        }

      rows++;
     }

   writer.Close();

   PrintFormat("REFERENCE_EXPORT OK bars=%d rows=%d first=%s last=%s file=%s timeframe=%s",
               copied, rows,
               TimeToString(rates[1].time, TIME_DATE|TIME_SECONDS),
               TimeToString(rates[last].time, TIME_DATE|TIME_SECONDS),
               OutputFile, timeframe);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Sin operaciones: el port solo exporta senales.                   |
//+------------------------------------------------------------------+
void OnTick()
  {
  }
