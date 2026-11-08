//+------------------------------------------------------------------+
//|                                                    RiskPolicy.mqh|
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#ifndef LMROBOT_RISK_RISKPOLICY_MQH
#define LMROBOT_RISK_RISKPOLICY_MQH

//+------------------------------------------------------------------+
//| Parametros de riesgo. Valores iniciales de la tabla del design.  |
//+------------------------------------------------------------------+
struct RiskConfig
  {
   double   riskPct;
   double   maxBasketLossPct;
   double   dailyLossLimitPct;
   int      maxGridSteps;
   double   lotMultiplier;
   double   maxLotPerOrder;
   double   maxVolumePerStrategy;
   double   slPips;
   double   tpPips;
   double   gridStepPips;
   double   maxSpreadPips;
   double   maxAggregateLossPct;
   double   maxAggregateVolume;
  };

//+------------------------------------------------------------------+
//| Decision de la politica de riesgo para un paso.                  |
//+------------------------------------------------------------------+
enum ENUM_RISK_DECISION
  {
   RISK_DECISION_REJECT     = 0,
   RISK_DECISION_OPEN_FIRST = 1,
   RISK_DECISION_OPEN_GRID  = 2
  };

struct RiskStepPlan
  {
   ENUM_RISK_DECISION decision;
   double             volume;
   double             projectedLoss;
   string             reason;
  };

//+------------------------------------------------------------------+
//| Valores iniciales a calibrar (design.md).                        |
//+------------------------------------------------------------------+
RiskConfig LmDefaultRiskConfig()
  {
   RiskConfig config;

   config.riskPct             = 0.5;
   config.maxBasketLossPct    = 2.0;
   config.dailyLossLimitPct   = 4.0;
   config.maxGridSteps        = 4;
   config.lotMultiplier       = 1.5;
   config.maxLotPerOrder      = 0.10;
   config.maxVolumePerStrategy = 0.30;
   config.slPips              = 40.0;
   config.tpPips              = 8.0;
   config.gridStepPips        = 22.0;
   config.maxSpreadPips       = 3.0;

   //--- Modo portafolio (ALL): tres veces el tope por canasta.
   //--- La comparacion justa los sube a 1000 % y 9 lotes.
   config.maxAggregateLossPct = 6.0;
   config.maxAggregateVolume  = 0.90;

   return(config);
  }

//+------------------------------------------------------------------+
//| Redondea un volumen hacia abajo al step del broker.              |
//+------------------------------------------------------------------+
double LmFloorVolume(const double volume, const double step)
  {
   if(volume <= 0.0 || step <= 0.0)
      return(0.0);

   return(NormalizeDouble(MathFloor((volume + 1e-9) / step) * step, 8));
  }

//+------------------------------------------------------------------+
//| Lote inicial por riesgo, acotado al minimo y maximo del broker.  |
//| Se redondea hacia abajo para no superar el riesgo configurado.   |
//+------------------------------------------------------------------+
double LmInitialLot(const double balance,
                    const double riskPct,
                    const double slPips,
                    const double pipValuePerLot,
                    const double volumeStep,
                    const double volumeMin,
                    const double volumeMax)
  {
   if(balance <= 0.0 || riskPct <= 0.0 || slPips <= 0.0 || pipValuePerLot <= 0.0)
      return(0.0);

   if(volumeStep <= 0.0 || volumeMin <= 0.0 || volumeMax < volumeMin)
      return(0.0);

   double rawLot = (riskPct / 100.0 * balance) / (slPips * pipValuePerLot);
   double maxValid = LmFloorVolume(volumeMax, volumeStep);
   double lot      = LmFloorVolume(rawLot, volumeStep);

   if(lot < volumeMin)
      lot = NormalizeDouble(MathCeil((volumeMin - 1e-9) / volumeStep) * volumeStep, 8);

   if(lot > maxValid)
      lot = maxValid;

   if(lot < volumeMin || lot <= 0.0)
      return(0.0);

   return(lot);
  }

//+------------------------------------------------------------------+
//| Volumen de un paso de grid: inicial * LotMultiplier^paso.        |
//+------------------------------------------------------------------+
double LmGridLot(const double initialLot, const double lotMultiplier, const int stepNumber)
  {
   if(initialLot <= 0.0 || lotMultiplier <= 0.0 || stepNumber < 0)
      return(0.0);

   return(initialLot * MathPow(lotMultiplier, stepNumber));
  }

//+------------------------------------------------------------------+
//| Perdida proyectada al stop loss de la canasta.                   |
//+------------------------------------------------------------------+
double LmProjectedLoss(const double totalVolume,
                       const double slPips,
                       const double pipValuePerLot)
  {
   if(totalVolume <= 0.0 || slPips <= 0.0 || pipValuePerLot <= 0.0)
      return(0.0);

   return(totalVolume * slPips * pipValuePerLot);
  }

//+------------------------------------------------------------------+
//| Presupuesto maximo de perdida para la canasta.                   |
//+------------------------------------------------------------------+
double LmBasketLossBudget(const double balance, const double maxBasketLossPct)
  {
   if(balance <= 0.0 || maxBasketLossPct <= 0.0)
      return(0.0);

   return(balance * maxBasketLossPct / 100.0);
  }

//+------------------------------------------------------------------+
//| La perdida proyectada no puede superar el presupuesto.           |
//+------------------------------------------------------------------+
bool LmFitsBasketBudget(const double projectedLoss,
                        const double balance,
                        const double maxBasketLossPct)
  {
   double budget = LmBasketLossBudget(balance, maxBasketLossPct);
   return(projectedLoss <= budget + 1e-9);
  }

//+------------------------------------------------------------------+
//| Topes independientes de volumen y de pasos.                      |
//+------------------------------------------------------------------+
double LmCapVolumePerOrder(const double volume, const double maxLotPerOrder)
  {
   if(volume <= 0.0 || maxLotPerOrder <= 0.0)
      return(0.0);

   return(MathMin(volume, maxLotPerOrder));
  }

double LmCapVolumePerBasket(const double requestedVolume,
                            const double currentVolume,
                            const double maxVolumePerStrategy)
  {
   if(requestedVolume <= 0.0 || maxVolumePerStrategy <= 0.0)
      return(0.0);

   double remaining = maxVolumePerStrategy - currentVolume;
   if(remaining <= 0.0)
      return(0.0);

   return(MathMin(requestedVolume, remaining));
  }

bool LmMaxStepsReached(const int currentSteps, const int maxGridSteps)
  {
   return(currentSteps >= maxGridSteps);
  }

//+------------------------------------------------------------------+
//| Presupuesto agregado de la instancia (modo portafolio ALL).      |
//+------------------------------------------------------------------+
double LmAggregateLossBudget(const double balance,
                             const double maxAggregateLossPct)
  {
   if(balance <= 0.0 || maxAggregateLossPct <= 0.0)
      return(0.0);

   return(balance * maxAggregateLossPct / 100.0);
  }

bool LmFitsAggregateBudget(const double projectedLoss,
                           const double balance,
                           const double maxAggregateLossPct)
  {
   double budget = LmAggregateLossBudget(balance, maxAggregateLossPct);
   return(projectedLoss <= budget + 1e-9);
  }

bool LmFitsAggregateVolume(const double totalVolume,
                           const double maxAggregateVolume)
  {
   if(totalVolume <= 0.0)
      return(true);

   if(maxAggregateVolume <= 0.0)
      return(false);

   return(totalVolume <= maxAggregateVolume + 1e-9);
  }

//+------------------------------------------------------------------+
//| Planifica la primera orden y valida su presupuesto.              |
//+------------------------------------------------------------------+
bool LmPlanInitialOrder(const RiskConfig &config,
                        const double balance,
                        const double pipValuePerLot,
                        const double volumeStep,
                        const double volumeMin,
                        const double volumeMax,
                        RiskStepPlan &plan)
  {
   plan.decision      = RISK_DECISION_REJECT;
   plan.volume        = 0.0;
   plan.projectedLoss = 0.0;
   plan.reason        = "";

   double volume = LmInitialLot(balance, config.riskPct, config.slPips,
                                pipValuePerLot, volumeStep, volumeMin, volumeMax);
   if(volume <= 0.0)
     {
      plan.reason = "no se pudo calcular el lote inicial";
      return(false);
     }

   volume = LmFloorVolume(LmCapVolumePerOrder(volume, config.maxLotPerOrder), volumeStep);
   volume = LmFloorVolume(LmCapVolumePerBasket(volume, 0.0,
                                               config.maxVolumePerStrategy), volumeStep);

   if(volume < volumeMin)
     {
      plan.reason = "el lote inicial queda debajo del minimo del broker";
      return(false);
     }

   double projected = LmProjectedLoss(volume, config.slPips, pipValuePerLot);
   plan.projectedLoss = projected;

   if(!LmFitsBasketBudget(projected, balance, config.maxBasketLossPct))
     {
      plan.reason = "la perdida proyectada supera el presupuesto de la canasta";
      return(false);
     }

   plan.volume   = volume;
   plan.decision = RISK_DECISION_OPEN_FIRST;
   return(true);
  }

//+------------------------------------------------------------------+
//| Planifica un paso de grid aplicando topes y presupuesto.         |
//+------------------------------------------------------------------+
bool LmPlanGridOrder(const RiskConfig &config,
                     const double balance,
                     const double pipValuePerLot,
                     const double currentVolume,
                     const int currentSteps,
                     const double requestedVolume,
                     const double volumeStep,
                     const double volumeMin,
                     const double volumeMax,
                     RiskStepPlan &plan)
  {
   plan.decision      = RISK_DECISION_REJECT;
   plan.volume        = 0.0;
   plan.projectedLoss = 0.0;
   plan.reason        = "";

   if(LmMaxStepsReached(currentSteps, config.maxGridSteps))
     {
      plan.reason = "tope de pasos de grid alcanzado";
      return(false);
     }

   double volume = LmFloorVolume(requestedVolume, volumeStep);
   if(volume <= 0.0)
     {
      plan.reason = "volumen solicitado invalido";
      return(false);
     }

   volume = LmFloorVolume(LmCapVolumePerOrder(volume, config.maxLotPerOrder), volumeStep);
   volume = LmFloorVolume(LmCapVolumePerBasket(volume, currentVolume,
                                               config.maxVolumePerStrategy), volumeStep);

   if(volume < volumeMin)
     {
      plan.reason = "el paso de grid queda debajo del minimo o del tope de canasta";
      return(false);
     }

   if(volume > volumeMax)
      volume = LmFloorVolume(volumeMax, volumeStep);

   double projected = LmProjectedLoss(currentVolume + volume,
                                      config.slPips, pipValuePerLot);
   plan.projectedLoss = projected;

   if(!LmFitsBasketBudget(projected, balance, config.maxBasketLossPct))
     {
      plan.reason = "la perdida proyectada supera el presupuesto de la canasta";
      return(false);
     }

   plan.volume   = volume;
   plan.decision = RISK_DECISION_OPEN_GRID;
   return(true);
  }

//+------------------------------------------------------------------+
//| La gestion de posiciones abiertas nunca se bloquea.              |
//+------------------------------------------------------------------+
bool LmCanManagePositions(const bool dailyLossBlocked)
  {
   //--- La gestion (SL, TP, trailing, cierre) tiene prioridad absoluta.
   return(true);
  }

//+------------------------------------------------------------------+
//| Solo las aperturas quedan sujetas a los guards de entrada.       |
//+------------------------------------------------------------------+
bool LmCanOpenNew(const bool dailyLossBlocked,
                  const bool spreadBlocked,
                  const bool highVolatility,
                  const bool sessionOpen)
  {
   return(!dailyLossBlocked && !spreadBlocked && !highVolatility && sessionOpen);
  }

#endif // LMROBOT_RISK_RISKPOLICY_MQH
