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
          MathAbs(a.dailyPnl - b.dailyPnl) <= 1e-9);
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
//| Lineas del panel.                                               |
//| Modo unico: titulo + los siete campos del contrato (8 lineas).   |
//| Modo ALL: titulo + una fila por estrategia + agregado + PnL dia. |
//+------------------------------------------------------------------+
int LmDashboardLines(const DashboardState &state, const string symbol,
                     string &lines[])
  {
   int digits = (state.digits > 0 ? state.digits : 5);

   if(state.portfolio && state.rowCount > 0)
     {
      int total = state.rowCount + 3;
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

      return(ArraySize(lines));
     }

   ArrayResize(lines, 8);

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
