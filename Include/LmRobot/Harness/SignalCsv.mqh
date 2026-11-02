//+------------------------------------------------------------------+
//|                                                   SignalCsv.mqh  |
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#ifndef LMROBOT_HARNESS_SIGNALCSV_MQH
#define LMROBOT_HARNESS_SIGNALCSV_MQH

#include "../Strategies/Signal.mqh"

//+------------------------------------------------------------------+
//| Una fila del CSV de senales.                                     |
//+------------------------------------------------------------------+
struct SignalRow
  {
   datetime             time;
   string               strategy;
   ENUM_SIGNAL_DIRECTION direction;
   string               timeframe;
  };

//+------------------------------------------------------------------+
//| Escritor CSV con cabecera fija.                                  |
//+------------------------------------------------------------------+
class CSignalCsvWriter
  {
private:
   int  m_handle;
   int  m_count;
   bool m_open;

public:
   CSignalCsvWriter()
     {
      m_handle = INVALID_HANDLE;
      m_count  = 0;
      m_open   = false;
     }

   ~CSignalCsvWriter()
     {
      Close();
     }

   bool Open(const string filename)
     {
      Close();

      m_handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
      if(m_handle == INVALID_HANDLE)
         return(false);

      m_open  = true;
      m_count = 0;
      FileWrite(m_handle, "time", "strategy", "direction", "timeframe");
      return(true);
     }

   bool Write(const SignalRow &row)
     {
      if(!m_open || m_handle == INVALID_HANDLE)
         return(false);

      FileWrite(m_handle,
                TimeToString(row.time, TIME_DATE|TIME_SECONDS),
                row.strategy,
                LmSignalDirectionName(row.direction),
                row.timeframe);
      m_count++;
      return(true);
     }

   bool WriteRow(const datetime time, const string strategy,
                 const ENUM_SIGNAL_DIRECTION direction, const string timeframe)
     {
      SignalRow row;
      row.time      = time;
      row.strategy  = strategy;
      row.direction = direction;
      row.timeframe = timeframe;
      return(Write(row));
     }

   void Close()
     {
      if(m_open && m_handle != INVALID_HANDLE)
         FileClose(m_handle);

      m_open   = false;
      m_handle = INVALID_HANDLE;
     }

   int Count()       { return(m_count); }
   bool IsOpen()     { return(m_open); }
  };

//+------------------------------------------------------------------+
//| Lector CSV. Acepta con o sin cabecera.                           |
//+------------------------------------------------------------------+
class CSignalCsvReader
  {
private:
   SignalRow m_rows[];
   int       m_count;
   string    m_error;

   bool ParseRow(const int handle, const string timeText)
     {
      string strategy  = FileReadString(handle);
      string direction = FileReadString(handle);
      string timeframe = FileReadString(handle);

      SignalRow row;
      row.time      = StringToTime(timeText);
      row.strategy  = strategy;
      row.direction = LmSignalDirectionFromName(direction);
      row.timeframe = timeframe;

      int index = m_count;
      ArrayResize(m_rows, index + 1);
      m_rows[index] = row;
      m_count++;
      return(true);
     }

public:
   CSignalCsvReader()
     {
      m_count = 0;
      m_error = "";
     }

   bool Load(const string filename)
     {
      ArrayResize(m_rows, 0);
      m_count = 0;
      m_error = "";

      int handle = FileOpen(filename, FILE_READ|FILE_CSV|FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
        {
         m_error = "no se pudo abrir " + filename;
         return(false);
        }

      string first = FileReadString(handle);
      if(first == "time")
        {
         FileReadString(handle);
         FileReadString(handle);
         FileReadString(handle);
        }
      else
        {
         if(first != "")
            ParseRow(handle, first);
        }

      while(!FileIsEnding(handle))
        {
         string timeText = FileReadString(handle);
         if(timeText == "")
            break;

         ParseRow(handle, timeText);
        }

      FileClose(handle);
      return(true);
     }

   int Count() { return(m_count); }
   string Error() { return(m_error); }

   bool RowAt(const int index, SignalRow &row)
     {
      if(index < 0 || index >= m_count)
         return(false);

      row = m_rows[index];
      return(true);
     }
  };

//+------------------------------------------------------------------+
//| Resultado de comparar dos CSV de senales.                        |
//+------------------------------------------------------------------+
class CSignalComparison
  {
public:
   int    referenceCount;
   int    actualCount;
   int    matches;
   int    missing;
   int    extra;
   int    mismatched;
   bool   parity;
   string reason;
   string details[];

   CSignalComparison()
     {
      Reset();
     }

   void Reset()
     {
      referenceCount = 0;
      actualCount    = 0;
      matches        = 0;
      missing        = 0;
      extra          = 0;
      mismatched     = 0;
      parity         = false;
      reason         = "";
      ArrayResize(details, 0);
     }

   void AddDetail(const string text)
     {
      int index = ArraySize(details);
      ArrayResize(details, index + 1);
      details[index] = text;
     }
  };

//+------------------------------------------------------------------+
//| Compara dos archivos por fecha y direccion.                      |
//+------------------------------------------------------------------+
bool LmCompareSignalCsvFiles(const string referenceFile,
                             const string actualFile,
                             CSignalComparison &result)
  {
   result.Reset();

   CSignalCsvReader reference;
   CSignalCsvReader actual;

   if(!reference.Load(referenceFile))
     {
      result.reason = reference.Error();
      return(false);
     }

   if(!actual.Load(actualFile))
     {
      result.reason = actual.Error();
      return(false);
     }

   result.referenceCount = reference.Count();
   result.actualCount    = actual.Count();

   int i = 0;
   int j = 0;

   while(i < reference.Count() && j < actual.Count())
     {
      SignalRow refRow;
      SignalRow actRow;

      if(!reference.RowAt(i, refRow) || !actual.RowAt(j, actRow))
         break;

      if(refRow.time < actRow.time)
        {
         result.missing++;
         result.AddDetail("FALTANTE  " + TimeToString(refRow.time, TIME_DATE|TIME_SECONDS) +
                          "  " + LmSignalDirectionName(refRow.direction));
         i++;
        }
      else if(refRow.time > actRow.time)
        {
         result.extra++;
         result.AddDetail("SOBRANTE  " + TimeToString(actRow.time, TIME_DATE|TIME_SECONDS) +
                          "  " + LmSignalDirectionName(actRow.direction));
         j++;
        }
      else
        {
         if(refRow.direction != actRow.direction)
           {
            result.mismatched++;
            result.AddDetail("DIFERENTE " + TimeToString(refRow.time, TIME_DATE|TIME_SECONDS) +
                             "  ref=" + LmSignalDirectionName(refRow.direction) +
                             " actual=" + LmSignalDirectionName(actRow.direction));
           }
         else
            result.matches++;

         i++;
         j++;
        }
     }

   while(i < reference.Count())
     {
      SignalRow refRow;
      if(reference.RowAt(i, refRow))
        {
         result.missing++;
         result.AddDetail("FALTANTE  " + TimeToString(refRow.time, TIME_DATE|TIME_SECONDS) +
                          "  " + LmSignalDirectionName(refRow.direction));
        }
      i++;
     }

   while(j < actual.Count())
     {
      SignalRow actRow;
      if(actual.RowAt(j, actRow))
        {
         result.extra++;
         result.AddDetail("SOBRANTE  " + TimeToString(actRow.time, TIME_DATE|TIME_SECONDS) +
                          "  " + LmSignalDirectionName(actRow.direction));
        }
      j++;
     }

   result.parity = (result.missing == 0 && result.extra == 0 && result.mismatched == 0);
   return(true);
  }

//+------------------------------------------------------------------+
//| Exporta una serie de senales ya calculadas.                      |
//+------------------------------------------------------------------+
bool LmExportSignalSeries(const datetime &times[],
                          const ENUM_SIGNAL_DIRECTION &directions[],
                          const int startIndex,
                          const int count,
                          const string strategy,
                          const string timeframe,
                          const string filename,
                          int &written)
  {
   written = 0;

   int total = ArraySize(times);
   if(total != ArraySize(directions) || startIndex < 0 || count <= 0 ||
      startIndex + count > total)
      return(false);

   CSignalCsvWriter writer;
   if(!writer.Open(filename))
      return(false);

   for(int i = startIndex; i < startIndex + count; i++)
     {
      if(!writer.WriteRow(times[i], strategy, directions[i], timeframe))
        {
         writer.Close();
         return(false);
        }

      written++;
     }

   writer.Close();
   return(true);
  }

#endif // LMROBOT_HARNESS_SIGNALCSV_MQH
