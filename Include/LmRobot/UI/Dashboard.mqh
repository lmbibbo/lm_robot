//+------------------------------------------------------------------+
//|                                                    Dashboard.mqh |
//|                                              lm_robot (MQL5)    |
//+------------------------------------------------------------------+
#ifndef LMROBOT_UI_DASHBOARD_MQH
#define LMROBOT_UI_DASHBOARD_MQH

#include "../Core/BasketState.mqh"
#include "../Core/Instrument.mqh"
#include "../Risk/RiskPolicy.mqh"
#include "../Risk/DailyLossGuard.mqh"
#include "../Strategies/Strategy.mqh"

//--- Prefijo unico de los objetos que crea el panel.
#define LM_DASHBOARD_PREFIX "LMROBOT_PANEL_"

//--- Rango y paso del control de riesgo vivo.
#define LM_RISK_MIN_PCT   0.5
#define LM_RISK_MAX_PCT   10.0
#define LM_RISK_STEP_PCT  0.5

//--- Nombres estables de los botones de ajuste.
#define LMROBOT_PANEL_BTN_RISK_DOWN "LMROBOT_PANEL_BTN_RISK_DOWN"
#define LMROBOT_PANEL_BTN_RISK_MODE "LMROBOT_PANEL_BTN_RISK_MODE"
#define LMROBOT_PANEL_BTN_RISK_UP   "LMROBOT_PANEL_BTN_RISK_UP"

//+------------------------------------------------------------------+
//| El riesgo esta dentro del rango operable del control.            |
//+------------------------------------------------------------------+
bool LmRiskInControlRange(const double riskPct)
  {
   return(riskPct >= LM_RISK_MIN_PCT - 1e-9 &&
          riskPct <= LM_RISK_MAX_PCT + 1e-9);
  }

//+------------------------------------------------------------------+
//| El riesgo admite un paso en la direccion indicada (-1 / +1).     |
//+------------------------------------------------------------------+
bool LmRiskCanStep(const double riskPct, const int direction)
  {
   if(!LmRiskInControlRange(riskPct))
      return(false);

   if(direction < 0)
      return(riskPct > LM_RISK_MIN_PCT + 1e-9);

   if(direction > 0)
      return(riskPct < LM_RISK_MAX_PCT - 1e-9);

   return(false);
  }

//+------------------------------------------------------------------+
//| Siguiente riesgo tras un paso. Redondea a dos decimales y no     |
//| cambia el valor si el paso quedaria fuera del rango operable.    |
//+------------------------------------------------------------------+
double LmNextRiskPct(const double riskPct, const int direction)
  {
   if(direction == 0 || !LmRiskCanStep(riskPct, direction))
      return(riskPct);

   double next = riskPct + (direction > 0 ? LM_RISK_STEP_PCT : -LM_RISK_STEP_PCT);
   next = MathRound(next * 100.0) / 100.0;

   if(!LmRiskInControlRange(next))
      return(riskPct);

   return(next);
  }

//+------------------------------------------------------------------+
//| Direccion asociada a un nombre de boton: -1, +1 o 0 si no es uno.|
//+------------------------------------------------------------------+
int LmRiskButtonDirection(const string objectName)
  {
   if(objectName == LMROBOT_PANEL_BTN_RISK_DOWN)
      return(-1);

   if(objectName == LMROBOT_PANEL_BTN_RISK_UP)
      return(+1);

   return(0);
  }

//+------------------------------------------------------------------+
//| El objeto clicado es el boton que alterna la modalidad.          |
//+------------------------------------------------------------------+
bool LmRiskModeButton(const string objectName)
  {
   return(objectName == LMROBOT_PANEL_BTN_RISK_MODE);
  }

//+------------------------------------------------------------------+
//| Fila del panel: una estrategia o el agregado de la instancia.    |
//+------------------------------------------------------------------+
struct DashboardRow
  {
   ENUM_LM_STRATEGY      strategy;
   ENUM_BASKET_DIRECTION direction;
   double                volume;
   double                averagePrice;
   double                nextGridPrice;
   double                budgetUsedPct;
   bool                  mixed;
  };

//+------------------------------------------------------------------+
//| Vista de una estrategia activa para construir el panel.          |
//+------------------------------------------------------------------+
struct StrategyView
  {
   ENUM_LM_STRATEGY strategy;
   BasketState      basket;
  };

//+------------------------------------------------------------------+
//| Proyeccion del estado que muestra el panel.                      |
//| No contiene indicadores ni valores derivados del mercado: solo   |
//| lee BasketState, RiskConfig y DailyLossState.                    |
//+------------------------------------------------------------------+
struct DashboardState
  {
   ENUM_LM_STRATEGY      strategy;
   ENUM_BASKET_DIRECTION direction;
   double                volume;
   double                averagePrice;
   double                nextGridPrice;
   double                budgetUsedPct;
   double                dailyPnl;
   ENUM_LM_RISK_MODE     riskMode;
   double                riskPct;
   bool                  riskInRange;
   bool                  canDecrease;
   bool                  canIncrease;
   int                   digits;
   bool                  valid;
   bool                  portfolio;
   int                   rowCount;
   DashboardRow          rows[LM_MAX_ACTIVE_STRATEGIES];
   DashboardRow          aggregate;
  };

//+------------------------------------------------------------------+
//| Estado neutro del panel.                                         |
//+------------------------------------------------------------------+
void LmResetDashboardRow(DashboardRow &row)
  {
   row.strategy      = LM_STRATEGY_SCALPER_PRO;
   row.direction     = BASKET_DIRECTION_NONE;
   row.volume        = 0.0;
   row.averagePrice  = 0.0;
   row.nextGridPrice = 0.0;
   row.budgetUsedPct = 0.0;
   row.mixed         = false;
  }

void LmResetDashboardState(DashboardState &state)
  {
   state.strategy      = LM_STRATEGY_SCALPER_PRO;
   state.direction     = BASKET_DIRECTION_NONE;
   state.volume        = 0.0;
   state.averagePrice  = 0.0;
   state.nextGridPrice = 0.0;
   state.budgetUsedPct = 0.0;
   state.dailyPnl      = 0.0;
   state.riskMode      = LM_RISK_AUTO;
   state.riskPct       = 0.0;
   state.riskInRange   = false;
   state.canDecrease   = false;
   state.canIncrease   = false;
   state.digits        = 5;
   state.valid         = false;
   state.portfolio     = false;
   state.rowCount      = 0;
   LmResetDashboardRow(state.aggregate);

   for(int i = 0; i < LM_MAX_ACTIVE_STRATEGIES; i++)
      LmResetDashboardRow(state.rows[i]);
  }

//+------------------------------------------------------------------+
//| Nombre legible de la direccion de la canasta.                    |
//+------------------------------------------------------------------+
string LmBasketDirectionName(const ENUM_BASKET_DIRECTION direction)
  {
   if(direction == BASKET_DIRECTION_BUY)
      return("Compra");

   if(direction == BASKET_DIRECTION_SELL)
      return("Venta");

   return("Plana");
  }

//+------------------------------------------------------------------+
//| Nombre legible de la modalidad de riesgo.                        |
//+------------------------------------------------------------------+
string LmRiskModeName(const ENUM_LM_RISK_MODE mode)
  {
   return(mode == LM_RISK_MANUAL ? "manual" : "auto");
  }

//+------------------------------------------------------------------+
//| Texto del boton que alterna la modalidad.                        |
//+------------------------------------------------------------------+
string LmRiskModeButtonText(const ENUM_LM_RISK_MODE mode)
  {
   return(mode == LM_RISK_MANUAL ? "Modo: Manual" : "Modo: Auto");
  }

//+------------------------------------------------------------------+
//| Proximo nivel de grid desde la ultima orden de la canasta.       |
//| Compra: por debajo; venta: por encima. Sin canasta devuelve 0.   |
//+------------------------------------------------------------------+
double LmNextGridPrice(const BasketState &basket,
                       const double gridStepPips,
                       const double pipSize)
  {
   if(basket.count <= 0 || basket.lastOpenPrice <= 0.0 ||
      gridStepPips <= 0.0 || pipSize <= 0.0)
      return(0.0);

   double distance = gridStepPips * pipSize;

   if(basket.direction == BASKET_DIRECTION_BUY)
      return(NormalizeDouble(basket.lastOpenPrice - distance, 8));

   if(basket.direction == BASKET_DIRECTION_SELL)
      return(NormalizeDouble(basket.lastOpenPrice + distance, 8));

   return(0.0);
  }

//+------------------------------------------------------------------+
//| Presupuesto de riesgo consumido por la canasta, en porcentaje.   |
//| Compara la perdida proyectada al SL contra el presupuesto.       |
//+------------------------------------------------------------------+
double LmRiskBudgetUsedPct(const double volume,
                           const double slPips,
                           const double pipValuePerLot,
                           const double balance,
                           const double maxBasketLossPct)
  {
   if(volume <= 0.0 || balance <= 0.0 || maxBasketLossPct <= 0.0)
      return(0.0);

   double budget = LmBasketLossBudget(balance, maxBasketLossPct);
   if(budget <= 0.0)
      return(0.0);

   double projected = LmProjectedLoss(volume, slPips, pipValuePerLot);
   return(projected / budget * 100.0);
  }

//+------------------------------------------------------------------+
//| Llena una fila con el estado de una canasta.                     |
//+------------------------------------------------------------------+
void LmFillDashboardRow(DashboardRow &row, const ENUM_LM_STRATEGY strategy,
                        const BasketState &basket, const RiskConfig &risk,
                        const InstrumentInfo &instrument, const double balance)
  {
   row.strategy      = strategy;
   row.direction     = basket.direction;
   row.volume        = basket.volume;
   row.averagePrice  = basket.averagePrice;
   row.nextGridPrice = LmNextGridPrice(basket, risk.gridStepPips,
                                       instrument.pipSize);
   row.budgetUsedPct = LmRiskBudgetUsedPct(basket.volume, risk.slPips,
                                           instrument.pipValuePerLot,
                                           balance, risk.maxBasketLossPct);
   row.mixed         = false;
  }

//+------------------------------------------------------------------+
//| Copia modalidad, riesgo vivo y habitabilidad del control.        |
//| En automatico los botones +/- quedan siempre deshabilitados.     |
//+------------------------------------------------------------------+
void LmFillDashboardRisk(DashboardState &state, const RiskConfig &risk)
  {
   state.riskMode    = risk.riskMode;
   state.riskPct     = risk.riskPct;
   state.riskInRange = LmRiskInControlRange(risk.riskPct);
   state.canDecrease = (risk.riskMode == LM_RISK_MANUAL &&
                        LmRiskCanStep(risk.riskPct, -1));
   state.canIncrease = (risk.riskMode == LM_RISK_MANUAL &&
                        LmRiskCanStep(risk.riskPct, +1));
  }

//+------------------------------------------------------------------+
//| Construye el estado del panel para una sola estrategia.          |
//+------------------------------------------------------------------+
DashboardState LmBuildDashboardState(const ENUM_LM_STRATEGY strategy,
                                     const BasketState &basket,
                                     const RiskConfig &risk,
                                     const DailyLossState &daily,
                                     const InstrumentInfo &instrument,
                                     const double balance,
                                     const double equity)
  {
   DashboardState state;
   LmResetDashboardState(state);

   state.strategy = strategy;
   state.digits   = (instrument.digits > 0 ? instrument.digits : 5);
   state.valid    = true;
   LmFillDashboardRisk(state, risk);

   if(basket.count > 0)
     {
      state.direction     = basket.direction;
      state.volume        = basket.volume;
      state.averagePrice  = basket.averagePrice;
      state.nextGridPrice = LmNextGridPrice(basket, risk.gridStepPips, instrument.pipSize);
      state.budgetUsedPct = LmRiskBudgetUsedPct(basket.volume, risk.slPips,
                                                instrument.pipValuePerLot,
                                                balance, risk.maxBasketLossPct);
     }

   if(daily.initialized && daily.startEquity > 0.0 && equity > 0.0)
      state.dailyPnl = equity - daily.startEquity;

   return(state);
  }

//+------------------------------------------------------------------+
//| Construye el panel de portafolio: una fila por estrategia y una  |
//| fila agregada. Con una sola vista mantiene el formato clasico.   |
//+------------------------------------------------------------------+
DashboardState LmBuildPortfolioDashboardState(StrategyView &views[],
                                              const int viewCount,
                                              const RiskConfig &risk,
                                              const DailyLossState &daily,
                                              const InstrumentInfo &instrument,
                                              const double balance,
                                              const double equity)
  {
   DashboardState state;
   LmResetDashboardState(state);

   state.digits = (instrument.digits > 0 ? instrument.digits : 5);
   state.valid  = true;
   LmFillDashboardRisk(state, risk);

   int total = MathMin(MathMax(viewCount, 0), LM_MAX_ACTIVE_STRATEGIES);
   state.rowCount  = total;
   state.portfolio = (total > 1);

   double totalVolume   = 0.0;
   double weightedPrice = 0.0;
   double totalBudget   = 0.0;
   bool   hasBuy        = false;
   bool   hasSell       = false;

   for(int i = 0; i < total; i++)
     {
      LmFillDashboardRow(state.rows[i], views[i].strategy, views[i].basket,
                         risk, instrument, balance);

      totalVolume   += state.rows[i].volume;
      weightedPrice += state.rows[i].averagePrice * state.rows[i].volume;
      totalBudget   += state.rows[i].budgetUsedPct;

      if(state.rows[i].direction == BASKET_DIRECTION_BUY)
         hasBuy = true;
      else if(state.rows[i].direction == BASKET_DIRECTION_SELL)
         hasSell = true;
     }

   state.aggregate.strategy      = (total > 0 ? views[0].strategy : LM_STRATEGY_ALL);
   state.aggregate.volume        = totalVolume;
   state.aggregate.averagePrice  = (totalVolume > 0.0 ? weightedPrice / totalVolume : 0.0);
   state.aggregate.nextGridPrice = 0.0;
   state.aggregate.budgetUsedPct = totalBudget;
   state.aggregate.mixed         = (hasBuy && hasSell);
   state.aggregate.direction     = (state.aggregate.mixed ? BASKET_DIRECTION_NONE :
                                    (hasBuy ? BASKET_DIRECTION_BUY :
                                     (hasSell ? BASKET_DIRECTION_SELL : BASKET_DIRECTION_NONE)));

   //--- Campos clasicos: reflejan la primera estrategia activa.
   if(total > 0)
     {
      state.strategy      = views[0].strategy;
      state.direction     = state.rows[0].direction;
      state.volume        = state.rows[0].volume;
      state.averagePrice  = state.rows[0].averagePrice;
      state.nextGridPrice = state.rows[0].nextGridPrice;
      state.budgetUsedPct = state.rows[0].budgetUsedPct;
     }

   if(total > 1)
      state.strategy = LM_STRATEGY_ALL;

   if(daily.initialized && daily.startEquity > 0.0 && equity > 0.0)
      state.dailyPnl = equity - daily.startEquity;

   return(state);
  }

//+------------------------------------------------------------------+
//| Compara dos filas con la tolerancia suficiente para no           |
//| redibujar por ruido de punto flotante.                           |
//+------------------------------------------------------------------+
bool LmDashboardRowEquals(const DashboardRow &a, const DashboardRow &b)
  {
   if(a.strategy != b.strategy || a.direction != b.direction ||
      a.mixed != b.mixed)
      return(false);

   return(MathAbs(a.volume - b.volume) <= 1e-9 &&
          MathAbs(a.averagePrice - b.averagePrice) <= 1e-9 &&
          MathAbs(a.nextGridPrice - b.nextGridPrice) <= 1e-9 &&
          MathAbs(a.budgetUsedPct - b.budgetUsedPct) <= 1e-9);
  }

//+------------------------------------------------------------------+
//| Compara dos estados con la tolerancia suficiente para no         |
//| redibujar por ruido de punto flotante.                           |
//+------------------------------------------------------------------+
bool LmDashboardStateEquals(const DashboardState &a, const DashboardState &b)
  {
   if(a.valid != b.valid || a.strategy != b.strategy ||
      a.direction != b.direction || a.digits != b.digits)
      return(false);

   if(a.riskInRange != b.riskInRange ||
      a.riskMode != b.riskMode ||
      a.canDecrease != b.canDecrease || a.canIncrease != b.canIncrease)
      return(false);

   if(a.portfolio != b.portfolio || a.rowCount != b.rowCount)
      return(false);

   if(a.portfolio)
     {
      for(int i = 0; i < a.rowCount; i++)
         if(!LmDashboardRowEquals(a.rows[i], b.rows[i]))
            return(false);

      if(!LmDashboardRowEquals(a.aggregate, b.aggregate))
         return(false);
     }

   return(MathAbs(a.volume - b.volume) <= 1e-9 &&
          MathAbs(a.averagePrice - b.averagePrice) <= 1e-9 &&
          MathAbs(a.nextGridPrice - b.nextGridPrice) <= 1e-9 &&
          MathAbs(a.budgetUsedPct - b.budgetUsedPct) <= 1e-9 &&
          MathAbs(a.dailyPnl - b.dailyPnl) <= 1e-9 &&
          MathAbs(a.riskPct - b.riskPct) <= 1e-9);
  }

//+------------------------------------------------------------------+
//| Linea de una estrategia en el panel de portafolio.               |
//+------------------------------------------------------------------+
string LmDashboardRowLine(const DashboardRow &row, const int digits)
  {
   string direction = (row.mixed ? "Mixta" : LmBasketDirectionName(row.direction));

   return(LmStrategyName(row.strategy) + ": " + direction +
          " | Vol " + DoubleToString(row.volume, 2) +
          " | Prom " + (row.averagePrice > 0.0
                        ? DoubleToString(row.averagePrice, digits) : "-") +
          " | Grid " + (row.nextGridPrice > 0.0
                        ? DoubleToString(row.nextGridPrice, digits) : "-") +
          " | Pres " + DoubleToString(row.budgetUsedPct, 1) + "%");
  }

//+------------------------------------------------------------------+
//| Linea del riesgo vivo y su estado de control.                    |
//+------------------------------------------------------------------+
string LmDashboardRiskLine(const DashboardState &state)
  {
   string line = "Riesgo: " + DoubleToString(state.riskPct, 2) + "% (" +
                 LmRiskModeName(state.riskMode) + ")";

   if(state.riskMode == LM_RISK_MANUAL && !state.riskInRange)
      line += " (fuera de 0.5-10: control deshabilitado)";

   return(line);
  }

//+------------------------------------------------------------------+
//| Lineas del panel.                                               |
//| Modo unico: titulo + los siete campos + riesgo (9 lineas).       |
//| Modo ALL: titulo + una fila por estrategia + agregado + PnL dia  |
//| + riesgo (rowCount + 4 lineas).                                  |
//+------------------------------------------------------------------+
int LmDashboardLines(const DashboardState &state, const string symbol,
                     string &lines[])
  {
   int digits = (state.digits > 0 ? state.digits : 5);

   if(state.portfolio && state.rowCount > 0)
     {
      int total = state.rowCount + 4;
      ArrayResize(lines, total);

      lines[0] = "LmRobot " + symbol;
      for(int i = 0; i < state.rowCount; i++)
         lines[1 + i] = LmDashboardRowLine(state.rows[i], digits);

      string aggregateDirection = (state.aggregate.mixed
                                   ? "Mixta"
                                   : LmBasketDirectionName(state.aggregate.direction));

      lines[1 + state.rowCount] = "Agregado: " + aggregateDirection +
                                  " | Vol " + DoubleToString(state.aggregate.volume, 2) +
                                  " | Pres " + DoubleToString(state.aggregate.budgetUsedPct, 1) + "%";
      lines[2 + state.rowCount] = "PnL del dia: " + DoubleToString(state.dailyPnl, 2);
      lines[3 + state.rowCount] = LmDashboardRiskLine(state);

      return(ArraySize(lines));
     }

   ArrayResize(lines, 9);

   lines[0] = "LmRobot " + symbol;
   lines[1] = "Estrategia: " + LmStrategyName(state.strategy);
   lines[2] = "Direccion: " + LmBasketDirectionName(state.direction);
   lines[3] = "Volumen: " + DoubleToString(state.volume, 2);
   lines[4] = "Promedio: " + (state.averagePrice > 0.0
                              ? DoubleToString(state.averagePrice, digits)
                              : "-");
   lines[5] = "Proximo grid: " + (state.nextGridPrice > 0.0
                                  ? DoubleToString(state.nextGridPrice, digits)
                                  : "-");
   lines[6] = "Presupuesto usado: " + DoubleToString(state.budgetUsedPct, 1) + "%";
   lines[7] = "PnL del dia: " + DoubleToString(state.dailyPnl, 2);
   lines[8] = LmDashboardRiskLine(state);

   return(ArraySize(lines));
  }

//+------------------------------------------------------------------+
//| Destino de dibujo. La interfaz permite probar el dirty flag sin  |
//| tocar el grafico.                                                |
//+------------------------------------------------------------------+
class IDashboardRenderer
  {
public:
   virtual void Render(const DashboardState &state, const string symbol) {}
   virtual void Clear() {}
  };

//+------------------------------------------------------------------+
//| Renderer real: un objeto de texto por linea, actualizado en su   |
//| lugar. No se recrean objetos cuando solo cambia el contenido.    |
//+------------------------------------------------------------------+
class CChartDashboardRenderer : public IDashboardRenderer
  {
private:
   int m_createdCount;

   string ObjectNameAt(const int index)
     {
      return(LM_DASHBOARD_PREFIX + IntegerToString(index));
     }

   //--- Crea o actualiza un boton del panel sin recrearlo.
   void RenderRiskButton(const string name, const string text, const int x,
                         const int y, const bool enabled,
                         const int width = 22)
     {
      if(ObjectFind(0, name) < 0)
        {
         if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
            return;

         m_createdCount++;
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
        }

      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, 18);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR,
                       (enabled ? clrSlateGray : clrDimGray));
      ObjectSetInteger(0, name, OBJPROP_COLOR,
                       (enabled ? clrWhite : clrGray));
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR,
                       (enabled ? clrSilver : clrDimGray));
     }

public:
   CChartDashboardRenderer()
     {
      m_createdCount = 0;
     }

   virtual void Render(const DashboardState &state, const string symbol)
     {
      string lines[];
      int total = LmDashboardLines(state, symbol, lines);

      for(int i = 0; i < total; i++)
        {
         string name = ObjectNameAt(i);

         if(ObjectFind(0, name) < 0)
           {
            if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
               continue;

            m_createdCount++;
            ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 12);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
            ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
            ObjectSetInteger(0, name, OBJPROP_FONTSIZE, (i == 0 ? 10 : 9));
            ObjectSetInteger(0, name, OBJPROP_COLOR, (i == 0 ? clrWhite : clrSilver));
           }

         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 18 + i * 16);
         ObjectSetString(0, name, OBJPROP_TEXT, lines[i]);
        }

      //--- Controles de riesgo debajo de la ultima linea.
      int buttonY = 18 + total * 16 + 6;
      RenderRiskButton(LMROBOT_PANEL_BTN_RISK_DOWN, "-", 12, buttonY,
                       state.canDecrease);
      RenderRiskButton(LMROBOT_PANEL_BTN_RISK_MODE,
                       LmRiskModeButtonText(state.riskMode), 38, buttonY,
                       true, 92);
      RenderRiskButton(LMROBOT_PANEL_BTN_RISK_UP, "+", 134, buttonY,
                       state.canIncrease);

      ChartRedraw(0);
     }

   virtual void Clear()
     {
      int total = ObjectsTotal(0, 0, -1);

      for(int i = total - 1; i >= 0; i--)
        {
         string name = ObjectName(0, i, 0, -1);
         if(StringFind(name, LM_DASHBOARD_PREFIX) == 0)
            ObjectDelete(0, name);
        }

      Comment("");
      ChartSetString(0, CHART_COMMENT, "");
      ChartRedraw(0);
     }

   int ObjectCount()
     {
      int count = 0;
      int total = ObjectsTotal(0, 0, -1);

      for(int i = 0; i < total; i++)
        {
         string name = ObjectName(0, i, 0, -1);
         if(StringFind(name, LM_DASHBOARD_PREFIX) == 0)
            count++;
        }

      return(count);
     }

   //--- Objetos creados en toda la vida del renderer. Un segundo
   //--- render sobre el mismo estado no debe incrementarlo.
   int CreatedCount()
     {
      return(m_createdCount);
     }
  };

//+------------------------------------------------------------------+
//| Panel con dirty flag: solo dibuja cuando cambio algun campo.     |
//+------------------------------------------------------------------+
class CDashboard
  {
private:
   IDashboardRenderer *m_renderer;
   DashboardState      m_lastState;
   string              m_lastSymbol;
   bool                m_hasState;
   int                 m_renderCount;
   int                 m_skippedCount;
   int                 m_clearCount;

public:
   CDashboard()
     {
      m_renderer     = NULL;
      m_lastSymbol   = "";
      m_hasState     = false;
      m_renderCount  = 0;
      m_skippedCount = 0;
      m_clearCount   = 0;
      LmResetDashboardState(m_lastState);
     }

   bool Init(IDashboardRenderer *renderer)
     {
      if(renderer == NULL)
         return(false);

      m_renderer = renderer;
      m_hasState = false;
      m_lastSymbol = "";
      m_renderCount  = 0;
      m_skippedCount = 0;
      m_clearCount   = 0;
      LmResetDashboardState(m_lastState);
      return(true);
     }

   //--- Devuelve true solo cuando efectivamente redibujo.
   bool Update(const DashboardState &state, const string symbol)
     {
      if(m_renderer == NULL || !state.valid)
         return(false);

      if(m_hasState && symbol == m_lastSymbol &&
         LmDashboardStateEquals(state, m_lastState))
        {
         m_skippedCount++;
         return(false);
        }

      m_renderer.Render(state, symbol);
      m_lastState  = state;
      m_lastSymbol = symbol;
      m_hasState   = true;
      m_renderCount++;
      return(true);
     }

   void Clear()
     {
      if(m_renderer != NULL)
         m_renderer.Clear();

      LmResetDashboardState(m_lastState);
      m_lastSymbol = "";
      m_hasState   = false;
      m_clearCount++;
     }

   int RenderCount()  { return(m_renderCount); }
   int SkippedCount() { return(m_skippedCount); }
   int ClearCount()   { return(m_clearCount); }
   bool HasState()    { return(m_hasState); }
   DashboardState LastState() { return(m_lastState); }
  };

#endif // LMROBOT_UI_DASHBOARD_MQH
