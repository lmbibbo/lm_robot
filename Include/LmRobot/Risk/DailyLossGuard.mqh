//+------------------------------------------------------------------+
//|                                                 DailyLossGuard.mqh|
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#ifndef LMROBOT_RISK_DAILYLOSSGUARD_MQH
#define LMROBOT_RISK_DAILYLOSSGUARD_MQH

//+------------------------------------------------------------------+
//| Estado del limite diario para una cuenta y un dia del servidor.  |
//+------------------------------------------------------------------+
struct DailyLossState
  {
   long     account;
   string   dayKey;
   double   startEquity;
   double   equity;
   double   dropPct;
   bool     blocked;
   bool     initialized;
   string   reason;
  };

//+------------------------------------------------------------------+
//| Almacen abstracto: produccion usa variables globales, tests usan |
//| un doble en memoria que puede simular un reinicio.               |
//+------------------------------------------------------------------+
class IDailyStateStore
  {
public:
   virtual bool Load(const string key, double &value)
     {
      value = 0.0;
      return(false);
     }

   virtual bool Save(const string key, const double value)
     {
      return(false);
     }
  };

//+------------------------------------------------------------------+
//| Store real: variables globales del terminal, persistentes entre  |
//| reinicios y aisladas por cuenta y dia.                           |
//+------------------------------------------------------------------+
class CGlobalVariableDailyStore : public IDailyStateStore
  {
public:
   virtual bool Load(const string key, double &value)
     {
      value = 0.0;

      if(!GlobalVariableCheck(key))
         return(false);

      value = GlobalVariableGet(key);
      return(true);
     }

   virtual bool Save(const string key, const double value)
     {
      return(GlobalVariableSet(key, value) != 0);
     }
  };

//+------------------------------------------------------------------+
//| Store en memoria para el Strategy Tester y pruebas aisladas.     |
//| Cada corrida empieza sin estado persistido de corridas previas.  |
//+------------------------------------------------------------------+
class CMemoryDailyStore : public IDailyStateStore
  {
private:
   string m_keys[];
   double m_values[];

public:
   virtual bool Load(const string key, double &value)
     {
      value = 0.0;

      for(int i = 0; i < ArraySize(m_keys); i++)
        {
         if(m_keys[i] == key)
           {
            value = m_values[i];
            return(true);
           }
        }

      return(false);
     }

   virtual bool Save(const string key, const double value)
     {
      for(int i = 0; i < ArraySize(m_keys); i++)
        {
         if(m_keys[i] == key)
           {
            m_values[i] = value;
            return(true);
           }
        }

      int index = ArraySize(m_keys);
      ArrayResize(m_keys, index + 1);
      ArrayResize(m_values, index + 1);

      m_keys[index]   = key;
      m_values[index] = value;
      return(true);
     }
  };

//+------------------------------------------------------------------+
//| Deja el estado en neutro.                                        |
//+------------------------------------------------------------------+
void LmResetDailyLossState(DailyLossState &state)
  {
   state.account     = 0;
   state.dayKey      = "";
   state.startEquity = 0.0;
   state.equity      = 0.0;
   state.dropPct     = 0.0;
   state.blocked     = false;
   state.initialized = false;
   state.reason      = "";
  }

//+------------------------------------------------------------------+
//| Clave de dia del servidor en formato YYYYMMDD.                   |
//+------------------------------------------------------------------+
string LmServerDayKey(const datetime serverTime)
  {
   MqlDateTime parts;
   TimeToStruct(serverTime, parts);

   return(StringFormat("%04d%02d%02d", parts.year, parts.mon, parts.day));
  }

//+------------------------------------------------------------------+
//| Claves persistentes por cuenta y dia.                            |
//+------------------------------------------------------------------+
string LmDailyStartKey(const long account, const datetime serverTime)
  {
   return("LM_DAILY_START_" + IntegerToString(account) + "_" + LmServerDayKey(serverTime));
  }

string LmDailyBlockedKey(const long account, const datetime serverTime)
  {
   return("LM_DAILY_BLOCKED_" + IntegerToString(account) + "_" + LmServerDayKey(serverTime));
  }

//+------------------------------------------------------------------+
//| Caida porcentual desde la equidad de inicio del dia.             |
//+------------------------------------------------------------------+
double LmDailyDropPct(const double startEquity, const double currentEquity)
  {
   if(startEquity <= 0.0)
      return(0.0);

   double drop = (startEquity - currentEquity) / startEquity * 100.0;

   return(drop > 0.0 ? drop : 0.0);
  }

//+------------------------------------------------------------------+
//| El limite se alcanza cuando la caida llega al porcentaje.        |
//+------------------------------------------------------------------+
bool LmDailyLimitReached(const double dropPct, const double limitPct)
  {
   if(limitPct <= 0.0)
      return(false);

   return(dropPct + 1e-9 >= limitPct);
  }

//+------------------------------------------------------------------+
//| Guarda el limite diario y decide si las aperturas se bloquean.   |
//+------------------------------------------------------------------+
class CDailyLossGuard
  {
private:
   IDailyStateStore *m_store;
   long              m_account;
   double            m_limitPct;
   DailyLossState    m_state;

public:
   CDailyLossGuard()
     {
      m_store    = NULL;
      m_account  = 0;
      m_limitPct = 0.0;
      LmResetDailyLossState(m_state);
     }

   bool Init(IDailyStateStore *store, const long account, const double limitPct)
     {
      if(store == NULL || account == 0 || limitPct <= 0.0)
         return(false);

      m_store    = store;
      m_account  = account;
      m_limitPct = limitPct;
      LmResetDailyLossState(m_state);
      return(true);
     }

   //--- Registra la equidad del primer tick del dia y evalua la caida.
   bool Evaluate(const datetime serverTime, const double equity, DailyLossState &state)
     {
      LmResetDailyLossState(state);
      state.account = m_account;
      state.dayKey  = LmServerDayKey(serverTime);
      state.equity  = equity;

      if(m_store == NULL || m_account == 0 || m_limitPct <= 0.0)
        {
         state.reason = "guarda diaria sin store, cuenta o limite valido";
         m_state = state;
         return(false);
        }

      if(equity <= 0.0)
        {
         state.reason = "equidad invalida";
         m_state = state;
         return(false);
        }

      string startKey = LmDailyStartKey(m_account, serverTime);
      double startEquity = 0.0;

      if(!m_store.Load(startKey, startEquity) || startEquity <= 0.0)
        {
         startEquity = equity;

         if(!m_store.Save(startKey, startEquity))
           {
            state.reason = "no se pudo persistir la equidad de inicio del dia";
            m_state = state;
            return(false);
           }
        }

      state.startEquity = startEquity;
      state.dropPct     = LmDailyDropPct(startEquity, equity);

      string blockedKey = LmDailyBlockedKey(m_account, serverTime);
      double blockedFlag = 0.0;
      m_store.Load(blockedKey, blockedFlag);

      bool blocked = (blockedFlag >= 0.5) ||
                     LmDailyLimitReached(state.dropPct, m_limitPct);

      if(blocked && blockedFlag < 0.5)
        {
         if(!m_store.Save(blockedKey, 1.0))
           {
            state.blocked = true;
            state.reason  = "no se pudo persistir el bloqueo diario";
            m_state = state;
            return(false);
           }
        }

      state.blocked     = blocked;
      state.initialized = true;
      m_state = state;

      return(true);
     }

   bool IsBlocked()          { return(m_state.blocked); }
   bool Initialized()        { return(m_state.initialized); }
   double StartEquity()      { return(m_state.startEquity); }
   double DropPct()          { return(m_state.dropPct); }
   double LimitPct()         { return(m_limitPct); }
   DailyLossState State()    { return(m_state); }
  };

#endif // LMROBOT_RISK_DAILYLOSSGUARD_MQH
