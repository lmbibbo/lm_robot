//+------------------------------------------------------------------+
//|                                                ParityCompare.mq5 |
//|                              lm_robot - comparador de paridad    |
//+------------------------------------------------------------------+
#property copyright "lm_robot"
#property version   "1.00"
#property description "Compara el CSV de referencia contra el CSV del motor nuevo."

#include "../Include/LmRobot/Harness/SignalCsv.mqh"

input string ReferenceFile = "lm_robot_reference_scalper_AUDCAD_H1.csv";
input string ActualFile    = "lm_robot_engine_scalper_AUDCAD_H1.csv";
input string ReportFile    = "lm_robot_parity_scalper.md";

//+------------------------------------------------------------------+
//| Compara, escribe el reporte y deja el resultado en el log.       |
//+------------------------------------------------------------------+
int OnInit()
  {
   CSignalComparison comparison;

   if(!LmCompareSignalCsvFiles(ReferenceFile, ActualFile, comparison))
     {
      PrintFormat("PARITY ERROR %s", comparison.reason);
      return(INIT_FAILED);
     }

   int handle = FileOpen(ReportFile, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("PARITY ERROR no se pudo abrir el reporte %s", ReportFile);
      return(INIT_FAILED);
     }

   FileWrite(handle, "# Reporte de paridad Scalper");
   FileWrite(handle, "");
   FileWrite(handle, StringFormat("- Referencia: `%s` (%d filas)",
                                  ReferenceFile, comparison.referenceCount));
   FileWrite(handle, StringFormat("- Motor nuevo: `%s` (%d filas)",
                                  ActualFile, comparison.actualCount));
   FileWrite(handle, "");
   FileWrite(handle, "## Resultado");
   FileWrite(handle, "");
   FileWrite(handle, StringFormat("- Coincidencias: %d", comparison.matches));
   FileWrite(handle, StringFormat("- Faltantes: %d", comparison.missing));
   FileWrite(handle, StringFormat("- Sobrantes: %d", comparison.extra));
   FileWrite(handle, StringFormat("- Direcciones diferentes: %d", comparison.mismatched));
   FileWrite(handle, StringFormat("- Paridad: %s", comparison.parity ? "SI" : "NO"));

   if(ArraySize(comparison.details) > 0)
     {
      FileWrite(handle, "");
      FileWrite(handle, "## Diferencias");
      FileWrite(handle, "");

      for(int i = 0; i < ArraySize(comparison.details); i++)
         FileWrite(handle, "- " + comparison.details[i]);
     }
   else
     {
      FileWrite(handle, "");
      FileWrite(handle, "## Diferencias");
      FileWrite(handle, "");
      FileWrite(handle, "- Ninguna.");
     }

   FileClose(handle);

   PrintFormat("PARITY OK ref=%d actual=%d matches=%d missing=%d extra=%d mismatched=%d parity=%s report=%s",
               comparison.referenceCount, comparison.actualCount, comparison.matches,
               comparison.missing, comparison.extra, comparison.mismatched,
               (comparison.parity ? "SI" : "NO"), ReportFile);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Sin operaciones.                                                 |
//+------------------------------------------------------------------+
void OnTick()
  {
  }
