//+------------------------------------------------------------------+
//|                                                      Account.mqh |
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#ifndef LMROBOT_CORE_ACCOUNT_MQH
#define LMROBOT_CORE_ACCOUNT_MQH

//+------------------------------------------------------------------+
//| El motor solo opera en cuentas hedging.                          |
//+------------------------------------------------------------------+
bool LmIsHedgingAccount(const ENUM_ACCOUNT_MARGIN_MODE mode)
  {
   return(mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
  }

//+------------------------------------------------------------------+
//| Nombre legible del modo de margen para el log de inicializacion. |
//+------------------------------------------------------------------+
string LmAccountModeName(const ENUM_ACCOUNT_MARGIN_MODE mode)
  {
   if(mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      return("hedging");

   if(mode == ACCOUNT_MARGIN_MODE_RETAIL_NETTING)
      return("netting");

   return("exchange");
  }

//+------------------------------------------------------------------+
//| Mensaje explicito cuando la cuenta no permite el grid.           |
//+------------------------------------------------------------------+
string LmAccountModeError(const ENUM_ACCOUNT_MARGIN_MODE mode)
  {
   if(LmIsHedgingAccount(mode))
      return("");

   return("LmRobot requiere una cuenta hedging; la cuenta actual es " +
          LmAccountModeName(mode) +
          ". En netting las ordenes del grid se netean y el motor no puede operar.");
  }

#endif // LMROBOT_CORE_ACCOUNT_MQH
