//+------------------------------------------------------------------+
//|                                                 SessionGuard.mqh |
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#ifndef LMROBOT_RISK_SESSIONGUARD_MQH
#define LMROBOT_RISK_SESSIONGUARD_MQH

//+------------------------------------------------------------------+
//| Ventana horaria del servidor en la que se permiten aperturas.    |
//| startHour == endHour significa sesion de 24 horas.               |
//+------------------------------------------------------------------+
struct SessionConfig
  {
   bool     enabled;
   int      startHour;
   int      endHour;
  };

//+------------------------------------------------------------------+
//| Configuracion por defecto: filtro apagado.                       |
//+------------------------------------------------------------------+
SessionConfig LmDefaultSessionConfig()
  {
   SessionConfig config;

   config.enabled   = false;
   config.startHour = 0;
   config.endHour   = 0;

   return(config);
  }

//+------------------------------------------------------------------+
//| Valida las horas. El final puede ser 24 para cerrar a medianoche.|
//+------------------------------------------------------------------+
bool LmSessionConfigValid(const SessionConfig &config)
  {
   if(config.startHour < 0 || config.startHour > 23)
      return(false);

   if(config.endHour < 0 || config.endHour > 24)
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//| La sesion esta abierta para la hora del servidor indicada.       |
//| Si el filtro esta apagado, siempre esta abierta.                 |
//+------------------------------------------------------------------+
bool LmSessionOpen(const datetime serverTime, const SessionConfig &config)
  {
   if(!config.enabled)
      return(true);

   if(!LmSessionConfigValid(config))
      return(false);

   if(config.startHour == config.endHour)
      return(true);

   MqlDateTime parts;
   TimeToStruct(serverTime, parts);
   int hour = parts.hour;

   if(config.startHour < config.endHour)
      return(hour >= config.startHour && hour < config.endHour);

   //--- Ventana que cruza la medianoche, por ejemplo 22 a 06.
   return(hour >= config.startHour || hour < config.endHour);
  }

#endif // LMROBOT_RISK_SESSIONGUARD_MQH
