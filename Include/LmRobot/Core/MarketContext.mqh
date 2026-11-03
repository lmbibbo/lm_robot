//+------------------------------------------------------------------+
//|                                               MarketContext.mqh  |
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#ifndef LMROBOT_CORE_MARKETCONTEXT_MQH
#define LMROBOT_CORE_MARKETCONTEXT_MQH

#include "Instrument.mqh"

//+------------------------------------------------------------------+
//| Estado de mercado de un tick.                                    |
//+------------------------------------------------------------------+
struct MarketSnapshot
  {
   string            symbol;
   datetime          time;
   double            bid;
   double            ask;
   double            spreadPoints;
   double            spreadPips;
   int               stopsLevel;
   int               freezeLevel;
   double            atrPips;
   bool              hasAtr;
   bool              highVolatility;
   bool              spreadBlocked;
   bool              valid;
  };

//+------------------------------------------------------------------+
//| Un spread estrictamente mayor al maximo bloquea entradas.        |
//+------------------------------------------------------------------+
bool LmSpreadBlocked(const double spreadPips, const double maxSpreadPips)
  {
   return(spreadPips > maxSpreadPips);
  }

//+------------------------------------------------------------------+
//| La volatilidad alta exige una lectura valida de ATR.             |
//+------------------------------------------------------------------+
bool LmHighVolatility(const bool hasAtr, const double atrPips, const double maxAtrPips)
  {
   return(hasAtr && atrPips > maxAtrPips);
  }

//+------------------------------------------------------------------+
//| Construye el snapshot a partir de valores ya leidos.             |
//+------------------------------------------------------------------+
MarketSnapshot LmBuildSnapshot(const string symbol, const datetime time,
                               const double bid, const double ask,
                               const int stopsLevel, const int freezeLevel,
                               const InstrumentInfo &instrument,
                               const bool hasAtr, const double atrPips,
                               const double maxSpreadPips, const double maxAtrPips)
  {
   MarketSnapshot snapshot;

   snapshot.symbol       = symbol;
   snapshot.time         = time;
   snapshot.bid          = bid;
   snapshot.ask          = ask;
   snapshot.spreadPoints = 0.0;
   snapshot.spreadPips   = 0.0;
   snapshot.stopsLevel   = stopsLevel;
   snapshot.freezeLevel  = freezeLevel;
   snapshot.atrPips      = atrPips;
   snapshot.hasAtr       = hasAtr;
   snapshot.highVolatility = LmHighVolatility(hasAtr, atrPips, maxAtrPips);
   snapshot.spreadBlocked  = false;
   snapshot.valid        = false;

   if(instrument.point <= 0.0 || instrument.pipSize <= 0.0)
      return(snapshot);

   if(bid <= 0.0 || ask <= 0.0 || ask < bid)
      return(snapshot);

   snapshot.spreadPoints = (ask - bid) / instrument.point;
   snapshot.spreadPips   = LmPointsToPips(snapshot.spreadPoints,
                                          instrument.pipSize,
                                          instrument.point);
   snapshot.spreadBlocked = LmSpreadBlocked(snapshot.spreadPips, maxSpreadPips);
   snapshot.valid         = true;

   return(snapshot);
  }

//+------------------------------------------------------------------+
//| Contexto de mercado: lee el tick una vez y reutiliza el estado.  |
//+------------------------------------------------------------------+
class CMarketContext
  {
private:
   string            m_symbol;
   InstrumentInfo    m_instrument;
   MarketSnapshot    m_snapshot;
   int               m_rsiHandle;
   int               m_atrHandle;
   ENUM_TIMEFRAMES   m_rsiTimeframe;
   ENUM_TIMEFRAMES   m_atrTimeframe;
   int               m_rsiPeriod;
   int               m_atrPeriod;
   double            m_maxSpreadPips;
   double            m_maxAtrPips;
   int               m_handleCreations;
   int               m_refreshes;
   bool              m_ready;

   //--- Deja el snapshot en estado invalido sin tocar los handles.
   void ResetSnapshot()
     {
      m_snapshot.symbol         = m_symbol;
      m_snapshot.time           = 0;
      m_snapshot.bid            = 0.0;
      m_snapshot.ask            = 0.0;
      m_snapshot.spreadPoints   = 0.0;
      m_snapshot.spreadPips     = 0.0;
      m_snapshot.stopsLevel     = 0;
      m_snapshot.freezeLevel    = 0;
      m_snapshot.atrPips        = 0.0;
      m_snapshot.hasAtr         = false;
      m_snapshot.highVolatility = false;
      m_snapshot.spreadBlocked  = false;
      m_snapshot.valid          = false;
     }

   //--- Lee el stops/freeze level una sola vez por refresco.
   void ReadLevels(int &stopsLevel, int &freezeLevel)
     {
      stopsLevel  = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      freezeLevel = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      m_instrument.stopsLevel  = stopsLevel;
      m_instrument.freezeLevel = freezeLevel;
     }

   //--- Lee el ATR de la ultima barra cerrada (shift 1).
   bool ReadAtr(double &atrPips)
     {
      atrPips = 0.0;

      if(m_atrHandle == INVALID_HANDLE || m_instrument.pipSize <= 0.0)
         return(false);

      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(m_atrHandle, 0, 1, 1, buffer) <= 0)
         return(false);

      atrPips = buffer[0] / m_instrument.pipSize;
      return(atrPips > 0.0);
     }

public:
   CMarketContext()
     {
      m_symbol           = "";
      m_rsiHandle        = INVALID_HANDLE;
      m_atrHandle        = INVALID_HANDLE;
      m_rsiTimeframe     = PERIOD_CURRENT;
      m_atrTimeframe     = PERIOD_CURRENT;
      m_rsiPeriod        = 14;
      m_atrPeriod        = 14;
      m_maxSpreadPips    = 0.0;
      m_maxAtrPips       = 0.0;
      m_handleCreations  = 0;
      m_refreshes        = 0;
      m_ready            = false;
      ResetSnapshot();
     }

   ~CMarketContext()
     {
      ReleaseHandles();
     }

   //--- Crea los handles una unica vez. No se llama desde OnTick.
   bool CreateHandles(const ENUM_TIMEFRAMES rsiTimeframe, const int rsiPeriod,
                      const ENUM_TIMEFRAMES atrTimeframe, const int atrPeriod)
     {
      if(rsiPeriod <= 0 || atrPeriod <= 0)
         return(false);

      m_rsiTimeframe = rsiTimeframe;
      m_atrTimeframe = atrTimeframe;
      m_rsiPeriod    = rsiPeriod;
      m_atrPeriod    = atrPeriod;

      m_rsiHandle = iRSI(m_symbol, rsiTimeframe, rsiPeriod, PRICE_CLOSE);
      m_atrHandle = iATR(m_symbol, atrTimeframe, atrPeriod);
      m_handleCreations++;

      if(m_rsiHandle == INVALID_HANDLE || m_atrHandle == INVALID_HANDLE)
        {
         PrintFormat("LmRobot: no se pudieron crear los handles (RSI=%d, ATR=%d)",
                     m_rsiHandle, m_atrHandle);
         ReleaseHandles();
         return(false);
        }

      return(true);
     }

   //--- Libera los handles. Es idempotente.
   void ReleaseHandles()
     {
      if(m_rsiHandle != INVALID_HANDLE)
        {
         IndicatorRelease(m_rsiHandle);
         m_rsiHandle = INVALID_HANDLE;
        }

      if(m_atrHandle != INVALID_HANDLE)
        {
         IndicatorRelease(m_atrHandle);
         m_atrHandle = INVALID_HANDLE;
        }
     }

   //--- Inicializacion completa para el EA.
   bool Init(const string symbol,
             const ENUM_TIMEFRAMES rsiTimeframe, const int rsiPeriod,
             const ENUM_TIMEFRAMES atrTimeframe, const int atrPeriod,
             const double maxSpreadPips, const double maxAtrPips)
     {
      ReleaseHandles();
      m_symbol        = symbol;
      m_maxSpreadPips = maxSpreadPips;
      m_maxAtrPips    = maxAtrPips;
      m_ready         = false;
      ResetSnapshot();

      if(!LmLoadInstrument(symbol, m_instrument))
        {
         PrintFormat("LmRobot: instrumento invalido '%s'", symbol);
         return(false);
        }

      if(!CreateHandles(rsiTimeframe, rsiPeriod, atrTimeframe, atrPeriod))
         return(false);

      m_ready = true;
      return(true);
     }

   //--- Inicializacion sin indicadores (simulacion / pruebas).
   bool InitFromInstrument(const InstrumentInfo &instrument,
                           const double maxSpreadPips, const double maxAtrPips)
     {
      ReleaseHandles();
      m_symbol        = instrument.symbol;
      m_instrument    = instrument;
      m_maxSpreadPips = maxSpreadPips;
      m_maxAtrPips    = maxAtrPips;
      m_ready         = instrument.valid;
      ResetSnapshot();
      return(m_ready);
     }

   //--- Refresco de produccion: un solo SymbolInfoTick por tick.
   bool Refresh()
     {
      if(!m_ready)
         return(false);

      MqlTick tick;
      if(!SymbolInfoTick(m_symbol, tick))
        {
         ResetSnapshot();
         return(false);
        }

      return(RefreshFromTick(tick.bid, tick.ask, tick.time));
     }

   //--- Refresco con valores inyectados (pruebas / simulacion).
   bool RefreshFromTick(const double bid, const double ask, const datetime time)
     {
      double atrPips = 0.0;
      bool hasAtr    = ReadAtr(atrPips);
      return(RefreshFromValues(bid, ask, time, hasAtr, atrPips));
     }

   //--- Refresco con ATR inyectado (pruebas / simulacion).
   bool RefreshFromValues(const double bid, const double ask, const datetime time,
                          const bool hasAtr, const double atrPips)
     {
      m_refreshes++;
      ResetSnapshot();

      if(!m_ready)
         return(false);

      int stopsLevel  = 0;
      int freezeLevel = 0;
      ReadLevels(stopsLevel, freezeLevel);

      m_snapshot = LmBuildSnapshot(m_symbol, time, bid, ask,
                                   stopsLevel, freezeLevel, m_instrument,
                                   hasAtr, atrPips,
                                   m_maxSpreadPips, m_maxAtrPips);
      return(m_snapshot.valid);
     }

   //--- Lecturas del ultimo snapshot (no vuelven a consultar el mercado).
   MarketSnapshot Snapshot()        { return(m_snapshot); }
   double         Bid()             { return(m_snapshot.bid); }
   double         Ask()             { return(m_snapshot.ask); }
   double         SpreadPips()      { return(m_snapshot.spreadPips); }
   double         AtrPips()         { return(m_snapshot.atrPips); }
   bool           HasAtr()          { return(m_snapshot.hasAtr); }
   bool           SpreadBlocked()   { return(m_snapshot.spreadBlocked); }
   bool           HighVolatility()  { return(m_snapshot.highVolatility); }
   bool           IsValid()         { return(m_snapshot.valid); }
   bool           IsReady()         { return(m_ready); }

   InstrumentInfo Instrument()      { return(m_instrument); }
   int            RsiHandle()       { return(m_rsiHandle); }
   int            AtrHandle()       { return(m_atrHandle); }
   int            HandleCreations() { return(m_handleCreations); }
   int            Refreshes()       { return(m_refreshes); }
  };

#endif // LMROBOT_CORE_MARKETCONTEXT_MQH
