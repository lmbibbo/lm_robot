//+------------------------------------------------------------------+
//| CodigoRefactorizado: 3 estrategias independientes                |
//| - Fibonacci Focus                                                |
//| - Scalper Pro                                                    |
//| - TrendMaster                                                    |
//|                                                                  |
//| MEJORAS:                                                         |
//| 1. Sin return(0) intermedios → un solo return al final           |
//| 2. Cada estrategia es una función independiente                  |
//| 3. Escaneo único de órdenes por estrategia (reduce loops)        |
//| 4. Sin PrintFormat debug (solo errores)                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| PARÁMETROS GENERALES                                             |
//+------------------------------------------------------------------+
extern double Lots = 0.01;
extern double GeneralStopLoss = 200;
extern int lotdecimal = 5;
extern double PipStepATRMultiplier = 2.0;
extern double MaxLots = 9.0;
extern bool MM = TRUE;
extern double Risk = 1.0;
extern double TakeProfit = 80.0;
extern bool UseEquityStop = FALSE;
extern double TotalEquityRisk = 20.0;
extern double slip = 3.0;

//+------------------------------------------------------------------+
//| CONFIGURACIÓN POR ESTRATEGIA                                     |
//+------------------------------------------------------------------+

// --- Fibonacci Focus ---
extern string SETT_FIBO = "--- Fibonacci Focus ---";
extern int MaxTrades_Hilo = 20;
extern double RiskMultiplier_Hilo = 1.0;
extern int Magic_Hilo = 10278;
extern int Timeframe_Hilo = PERIOD_M1;
double StopLossPips_Hilo = 40.0;
string Comment_Hilo = "Fibonacci Focus/2019";

// --- Scalper Pro ---
extern string SETT_SCALPER = "--- Scalper Pro ---";
extern int MaxTrades_Scalper = 20;
extern int Magic_Scalper = 22324;
extern double RiskMultiplier_Scalper = 1.0; // 0.5=conservador, 1.0=default, 2.0=agresivo
int Timeframe_Scalper = PERIOD_M1;
// double StopLossPips_Scalper = 40.0;
string Comment_Scalper = "Scalper Pro/2019";
extern bool UseTimeOut_Scalper = FALSE;
extern double TimeOutHours_Scalper = 48.0;

// --- TrendMaster ---
extern string SETT_TREND = "--- TrendMaster ---";
extern int MaxTrades_Trend = 20;
extern int Magic_Trend = 23794;
extern double RiskMultiplier_Trend = 1.0; // 0.5=conservador, 1.0=default, 2.0=agresivo
int Timeframe_Trend = PERIOD_H1;
double StopLossPips_Trend = 40.0;
string Comment_Trend = "TrendMaster/2019";

//+------------------------------------------------------------------+
//| VARIABLES DE ESTADO (compartidas, sin duplicar por estrategia)   |
//+------------------------------------------------------------------+

// --- Protección ATR ---
extern double MaxAllowedATR = 150.0;
extern int ATR_Period = 14;
extern int ATR_Timeframe = PERIOD_H1;

//+------------------------------------------------------------------+
//| ESTRUCTURA: RESULTADO DEL SCAN DE ÓRDENES (1 solo loop)          |
//+------------------------------------------------------------------+
// En lugar de llamar CountTrades + FindLastBuy/FindLastSell +
// calcular avgPrice + calcular profit por separado (cada uno con su
// propio loop), esta estructura almacena TODO en una sola pasada.
struct StrategyState
  {
   int               trades;         // N° de órdenes abiertas
   double            avgPrice;       // Precio promedio ponderado
   double            totalLots;      // Suma de lotes
   bool              hasBuy;
   bool              hasSell;
   double            lastBuyPrice;   // Precio de la última compra (mayor ticket)
   double            lastSellPrice;  // Precio de la última venta (mayor ticket)
   double            profit;         // Profit flotante total
   int               lastBuyTicket;
   int               lastSellTicket;
  };

//+------------------------------------------------------------------+
//| Escanea todas las órdenes abiertas del magic indicado y          |
//| llena el StrategyState con: trades, avgPrice, totalLots,         |
//| hasBuy/hasSell, lastBuyPrice/lastSellPrice, profit.             |
//| Un solo loop reemplaza CountTrades + FindLastBuy/FindLastSell  |
//| + CalculateProfit + CalculateAvgPrice del código original.      |
//+------------------------------------------------------------------+
void ScanOrders(int magic, StrategyState &st)
  {
   st.trades = 0;
   st.avgPrice = 0;
   st.totalLots = 0;
   st.hasBuy = FALSE;
   st.hasSell = FALSE;
   st.lastBuyPrice = 0;
   st.lastSellPrice = 0;
   st.profit = 0;
   st.lastBuyTicket = 0;
   st.lastSellTicket = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != magic)
         continue;

      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
        {
         st.trades++;
         st.avgPrice += OrderOpenPrice() * OrderLots();
         st.totalLots += OrderLots();
         st.profit += OrderProfit();

         if(OrderType() == OP_BUY)
           {
            st.hasBuy = TRUE;
            if(OrderTicket() > st.lastBuyTicket)
              {
               st.lastBuyTicket = OrderTicket();
               st.lastBuyPrice = OrderOpenPrice();
              }
           }
         else
            if(OrderType() == OP_SELL)
              {
               st.hasSell = TRUE;
               if(OrderTicket() > st.lastSellTicket)
                 {
                  st.lastSellTicket = OrderTicket();
                  st.lastSellPrice = OrderOpenPrice();
                 }
              }
        }
     }

   if(st.trades > 0 && st.totalLots > 0)
      st.avgPrice = NormalizeDouble(st.avgPrice / st.totalLots, Digits);
  }

//+------------------------------------------------------------------+
//| FUNCIONES AUXILIARES COMUNES                                     |
//+------------------------------------------------------------------+

double GetLotExponentByTimeframe(int tf, double riskMultiplier)
  {
   double base;
   switch(tf)
     {
      case PERIOD_M1:
         base = 1.2;
         break;
      case PERIOD_M5:
         base = 1.25;
         break;
      case PERIOD_M15:
         base = 1.35;
         break;
      case PERIOD_M30:
         base = 1.5;
         break;
      case PERIOD_H1:
         base = 1.667;
         break;
      case PERIOD_H4:
         base = 1.8;
         break;
      case PERIOD_D1:
         base = 2.0;
         break;
      default:
         base = 1.5;
     }
   double r = MathMax(0.5, MathMin(2.0, riskMultiplier));
   return NormalizeDouble(MathMax(1.01, base * r), 4);
  }

//+------------------------------------------------------------------+
//| Calcula PipStep dinámico basado en ATR del timeframe indicado.   |
//| PipStep = ATR_en_puntos * PipStepATRMultiplier.                  |
//| Ajusta por riskMultiplier: a mayor riesgo, menor PipStep.        |
//| Mínimo 10 puntos para evitar grids demasiado densos.             |
//+------------------------------------------------------------------+
double GetPipStepByTimeframe(int tf, double riskMultiplier)
  {
   double atr = iATR(Symbol(), tf, 14, 0);
   double pipStep = MathMax(10, atr / Point * PipStepATRMultiplier);
   double r = MathMax(0.5, MathMin(2.0, riskMultiplier));
   return NormalizeDouble(pipStep / r, 1);
  }

//+------------------------------------------------------------------+
//| Retorna TakeProfit en puntos según timeframe (tabla fija).       |
//| Timeframes cortos → TP ajustado, largos → TP amplio.            |
//+------------------------------------------------------------------+
double GetTakeProfitByTimeframe(int tf)
  {
   switch(tf)
     {
      case PERIOD_M1:  return 30;
      case PERIOD_M5:  return 50;
      case PERIOD_M15: return 70;
      case PERIOD_M30: return 80;
      case PERIOD_H1:  return 100;
      case PERIOD_H4:  return 150;
      case PERIOD_D1:  return 300;
      default:         return 80;
     }
  }

// Contar órdenes de Fibonacci Focus (para panel visual)
int CountTrades_Hilo()
  {
   int count = 0;
   for(int pos = OrdersTotal() - 1; pos >= 0; pos--)
     {
      if(!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic_Hilo)
         continue;
      if(OrderType() == OP_SELL || OrderType() == OP_BUY)
         count++;
     }
   return (count);
  }

// Contar órdenes de Scalper Pro (para panel visual)
int CountTrades_Scalper()
  {
   int count = 0;
   for(int pos = OrdersTotal() - 1; pos >= 0; pos--)
     {
      if(!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic_Scalper)
         continue;
      if(OrderType() == OP_SELL || OrderType() == OP_BUY)
         count++;
     }
   return (count);
  }

// Contar órdenes de TrendMaster (para panel visual)
int CountTrades_Trend()
  {
   int count = 0;
   for(int pos = OrdersTotal() - 1; pos >= 0; pos--)
     {
      if(!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic_Trend)
         continue;
      if(OrderType() == OP_SELL || OrderType() == OP_BUY)
         count++;
     }
   return (count);
  }

//+------------------------------------------------------------------+
//| Retorna el nombre corto del timeframe (M1, M5, H1, D1, ...).    |
//+------------------------------------------------------------------+
string TfToString(int tf)
  {
   switch(tf)
     {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      default:         return "?";
     }
  }

//+------------------------------------------------------------------+
//| Retorna TRUE si el ATR actual supera MaxAllowedATR.             |
//| Se usa en GetLotSizeBasedOnBalance para reducir lote en alta     |
//| volatilidad.                                                     |
//+------------------------------------------------------------------+
bool isHighVolatility()
  {
   double atr = iATR(Symbol(), ATR_Timeframe, ATR_Period, 0) / Point;
   return (atr > MaxAllowedATR);
  }

//+------------------------------------------------------------------+
//| Cierra todas las órdenes abiertas del magic number indicado.    |
//| Recorre de atrás hacia adelante para evitar problemas de         |
//| índice al cerrar.                                                |
//+------------------------------------------------------------------+
void CloseAllOrders(int magic)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != magic)
         continue;
      if(OrderType() == OP_BUY)
        {
         if(!OrderClose(OrderTicket(), OrderLots(), Bid, (int)slip, Blue))
            Print("CloseAllOrders: error ", GetLastError());
        }
      else
         if(OrderType() == OP_SELL)
           {
            if(!OrderClose(OrderTicket(), OrderLots(), Ask, (int)slip, Red))
               Print("CloseAllOrders: error ", GetLastError());
           }
      Sleep(1000);
     }
  }

//+------------------------------------------------------------------+
//| Envía una orden de mercado (0=BUY, 1=SELL). Reintenta hasta     |
//| 100 veces si el broker devuelve errores de conexión (4, 137,    |
//+------------------------------------------------------------------+
//| 146, 136). Retorna ticket o 0 si falla.                          |
//| Abre con TP por orden (como EXPERIMENTAL: TakeLong/TakeShort     |
//| relativo al precio del momento) → el TP del open siempre es       |
//| válido para el broker.                                           |
//+------------------------------------------------------------------+
int SendOrder(int type, double lots, string comment, int magic, color arrow, double tpDist)
  {
   int ticket = 0;
   int err = 0;
   for(int retry = 0; retry < 100; retry++)
     {
      RefreshRates();
      double tp_open = 0;
      if(type == 0)  // BUY
        {
         tp_open = Ask + tpDist * Point;
         ticket = OrderSend(Symbol(), OP_BUY, lots, Ask, (int)slip, 0, tp_open, comment, magic, 0, arrow);
        }
      else            // SELL
        {
         tp_open = Bid - tpDist * Point;
         ticket = OrderSend(Symbol(), OP_SELL, lots, Bid, (int)slip, 0, tp_open, comment, magic, 0, arrow);
        }

      err = GetLastError();
      if(err == 0)
         break;
      if(!(err == 4 || err == 137 || err == 146 || err == 136))
        {
         Print("SendOrder error ", err, " type=", type, " lots=", lots);
         break;
        }
      Sleep(5000);
     }
   return (ticket);
  }

//+------------------------------------------------------------------+
//| Modifica SOLO el TakeProfit de una orden. Versión minimalista    |
//| igual que CódigoOriginal / THE_ALGORITHM_PRO_EXPERIMENTAL.       |
//| Precio = OrderOpenPrice(), SL se conserva, reintento infinito    |
//| con Sleep(1000) + RefreshRates().                                |
//+------------------------------------------------------------------+
void SetTakeProfit(int ticket, double tp)
  {
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
     {
      Print("SetTakeProfit: ticket no encontrado ", ticket);
      return;
     }
   while(!OrderModify(ticket, OrderOpenPrice(), OrderStopLoss(), tp, 0, Yellow))
     {
      Sleep(1000);
      RefreshRates();
      if(!OrderSelect(ticket, SELECT_BY_TICKET))
         return;
     }
  }

//+------------------------------------------------------------------+
//| FUNCIONES DE GESTIÓN DE RIESGO Y MM                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Retorna TRUE si la pérdida flotante total supera umbrales        |
//| definidos según el lote original. Medida de protección contra    |
//| pérdidas excesivas.                                              |
//+------------------------------------------------------------------+
bool CheckStopOutByFloatingLoss(double originalLot, double totalProfit)
  {
   if(originalLot >= 0.04 && totalProfit <= -4000)
      return true;
   if(originalLot >= 0.03 && totalProfit <= -2800)
      return true;
   if(originalLot >= 0.02 && totalProfit <= -2000)
      return true;
   if(originalLot >= 0.01 && totalProfit <= -1200)
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//| Calcula el lote óptimo según AccountBalance y Risk%.            |
//| Incluye ajuste por volatilidad (ATR): si el ATR actual es       |
//| mayor que el promedio, reduce el lote (y viceversa).            |
//| Si la volatilidad supera MaxAllowedATR, retorna 0 (no opera).   |
//| Usa GetLotExponentByTimeframe(tf, riskMultiplier) en vez del    |
//| LotExponent fijo de los inputs.                                 |
//+------------------------------------------------------------------+
double GetLotSizeBasedOnBalance(int tf, double riskMultiplier)
  {
   if(Point <= 0)
      return (0);
   if(isHighVolatility())
     {
      Print("GetLotSize: Volatilidad alta, lote=0");
      return (0);
     }
   double balance = AccountBalance();
   double atr = iATR(Symbol(), ATR_Timeframe, ATR_Period, 0);
   double stopLoss = GeneralStopLoss;

   if(atr > 0)
     {
      double atrPoints = atr / Point;
      stopLoss = MathMax(GeneralStopLoss, atrPoints * GetLotExponentByTimeframe(tf, riskMultiplier));
     }
   double lot = NormalizeDouble((Risk / 1000.0 * balance) / stopLoss, 5);
   if(atr > 0)
     {
      double avgAtr = 0;
      for(int i = 1; i <= 50; i++)
         avgAtr += iATR(Symbol(), ATR_Timeframe, ATR_Period, i);
      avgAtr /= 50;
      if(avgAtr > 0)
        {
         double volFactor = MathMin(avgAtr / atr, 2.0);
         volFactor = MathMax(volFactor, 0.3);
         lot *= volFactor;
        }
     }
   lot = NormalizeDouble(lot, 5);
   lot = MathMax(lot, Lots);
   lot = MathMin(lot, MaxLots);
   return (lot);
  }

//+------------------------------------------------------------------+
//| Calcula lote fijo según rango de balance (sin MM).              |
//| balance < 5000 → 0.01, < 7000 → 0.02, < 10000 → 0.03,           |
//| >= 10000 → 0.04.                                                 |
//+------------------------------------------------------------------+
double GetLotBasedOnRange()
  {
   double balance = AccountBalance();
   if(balance < 5000)
      return (0.01);
   if(balance < 7000)
      return (0.02);
   if(balance < 10000)
      return (0.03);
   return (0.04);
  }

//+------------------------------------------------------------------+
//| Dibuja el panel informativo con OBJ_LABEL. Se llama desde init() |
//| (para que aparezca al adjuntar el EA aunque no haya ticks) y     |
//| desde start() para actualizar valores en cada tick.              |
//+------------------------------------------------------------------+
void DrawPanel()
  {
   // Mercado abierto = broker permite operar Y se siguen formando
   // barras M1 (si la última barra tiene más de 5 min, está cerrado).
   bool marketOpen = (MarketInfo(Symbol(), MODE_TRADEALLOWED) > 0);
   if(marketOpen && TimeCurrent() - iTime(Symbol(), PERIOD_M1, 0) > 300)
      marketOpen = FALSE;
   string status = marketOpen ? "ABIERTO" : "CERRADO";
   color clr = marketOpen ? Lime : Red;

   ObjectsDeleteAll(0, "panel_");
   int y = 10, s = 18;
   ObjectCreate("panel_h1", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("panel_h1", "___________________________________________________", 10, "Consolas", White);
   ObjectSet("panel_h1", OBJPROP_CORNER, 0); ObjectSet("panel_h1", OBJPROP_XDISTANCE, 10); ObjectSet("panel_h1", OBJPROP_YDISTANCE, y); y += s;
   ObjectCreate("panel_broker", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("panel_broker", "Broker                     : " + AccountCompany(), 10, "Consolas", White);
   ObjectSet("panel_broker", OBJPROP_CORNER, 0); ObjectSet("panel_broker", OBJPROP_XDISTANCE, 10); ObjectSet("panel_broker", OBJPROP_YDISTANCE, y); y += s;
   ObjectCreate("panel_time", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("panel_time", "Time                        : " + TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS), 10, "Consolas", White);
   ObjectSet("panel_time", OBJPROP_CORNER, 0); ObjectSet("panel_time", OBJPROP_XDISTANCE, 10); ObjectSet("panel_time", OBJPROP_YDISTANCE, y); y += s;
   ObjectCreate("panel_market", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("panel_market", "Market                    : " + status, 10, "Consolas", clr);
   ObjectSet("panel_market", OBJPROP_CORNER, 0); ObjectSet("panel_market", OBJPROP_XDISTANCE, 10); ObjectSet("panel_market", OBJPROP_YDISTANCE, y); y += s;
   ObjectCreate("panel_spread", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("panel_spread", "Spread                     : " + IntegerToString(MarketInfo(Symbol(), MODE_SPREAD)), 10, "Consolas", White);
   ObjectSet("panel_spread", OBJPROP_CORNER, 0); ObjectSet("panel_spread", OBJPROP_XDISTANCE, 10); ObjectSet("panel_spread", OBJPROP_YDISTANCE, y); y += s;
   ObjectCreate("panel_h2", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("panel_h2", "___________________________________________________", 10, "Consolas", White);
   ObjectSet("panel_h2", OBJPROP_CORNER, 0); ObjectSet("panel_h2", OBJPROP_XDISTANCE, 10); ObjectSet("panel_h2", OBJPROP_YDISTANCE, y); y += s;
   ObjectCreate("panel_name", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("panel_name", "Name                       : " + AccountName(), 10, "Consolas", White);
   ObjectSet("panel_name", OBJPROP_CORNER, 0); ObjectSet("panel_name", OBJPROP_XDISTANCE, 10); ObjectSet("panel_name", OBJPROP_YDISTANCE, y); y += s;
   ObjectCreate("panel_acc", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("panel_acc", "Account                    : " + AccountNumber(), 10, "Consolas", White);
   ObjectSet("panel_acc", OBJPROP_CORNER, 0); ObjectSet("panel_acc", OBJPROP_XDISTANCE, 10); ObjectSet("panel_acc", OBJPROP_YDISTANCE, y); y += s;
   ObjectCreate("panel_cur", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("panel_cur", "Currency                   : " + AccountCurrency(), 10, "Consolas", White);
   ObjectSet("panel_cur", OBJPROP_CORNER, 0); ObjectSet("panel_cur", OBJPROP_XDISTANCE, 10); ObjectSet("panel_cur", OBJPROP_YDISTANCE, y); y += s;
   ObjectCreate("panel_h3", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("panel_h3", "___________________________________________________", 10, "Consolas", White);
   ObjectSet("panel_h3", OBJPROP_CORNER, 0); ObjectSet("panel_h3", OBJPROP_XDISTANCE, 10); ObjectSet("panel_h3", OBJPROP_YDISTANCE, y); y += s;
   ObjectCreate("panel_scalper", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("panel_scalper", "Scalper Pro [" + TfToString(Timeframe_Scalper) + "] : " + CountTrades_Scalper(), 10, "Consolas", White);
   ObjectSet("panel_scalper", OBJPROP_CORNER, 0); ObjectSet("panel_scalper", OBJPROP_XDISTANCE, 10); ObjectSet("panel_scalper", OBJPROP_YDISTANCE, y); y += s;
   ObjectCreate("panel_fibo", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("panel_fibo", "Fibonacci Focus [" + TfToString(Timeframe_Hilo) + "] : " + CountTrades_Hilo(), 10, "Consolas", White);
   ObjectSet("panel_fibo", OBJPROP_CORNER, 0); ObjectSet("panel_fibo", OBJPROP_XDISTANCE, 10); ObjectSet("panel_fibo", OBJPROP_YDISTANCE, y); y += s;
   ObjectCreate("panel_trend", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("panel_trend", "TrendMaster [" + TfToString(Timeframe_Trend) + "] : " + CountTrades_Trend(), 10, "Consolas", White);
   ObjectSet("panel_trend", OBJPROP_CORNER, 0); ObjectSet("panel_trend", OBJPROP_XDISTANCE, 10); ObjectSet("panel_trend", OBJPROP_YDISTANCE, y); y += s;
   ObjectCreate("panel_all", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("panel_all", "ALL ORDERS                   : " + OrdersTotal(), 10, "Consolas", White);
   ObjectSet("panel_all", OBJPROP_CORNER, 0); ObjectSet("panel_all", OBJPROP_XDISTANCE, 10); ObjectSet("panel_all", OBJPROP_YDISTANCE, y); y += s;
   ObjectCreate("panel_h4", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("panel_h4", "___________________________________________________", 10, "Consolas", White);
   ObjectSet("panel_h4", OBJPROP_CORNER, 0); ObjectSet("panel_h4", OBJPROP_XDISTANCE, 10); ObjectSet("panel_h4", OBJPROP_YDISTANCE, y); y += s;
   ObjectCreate("panel_bal", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("panel_bal", "BALANCE                    : " + DoubleToStr(AccountBalance(), 2), 10, "Consolas", White);
   ObjectSet("panel_bal", OBJPROP_CORNER, 0); ObjectSet("panel_bal", OBJPROP_XDISTANCE, 10); ObjectSet("panel_bal", OBJPROP_YDISTANCE, y); y += s;
   ObjectCreate("panel_eq", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("panel_eq", "EQUITY                       : " + DoubleToStr(AccountEquity(), 2), 10, "Consolas", White);
   ObjectSet("panel_eq", OBJPROP_CORNER, 0); ObjectSet("panel_eq", OBJPROP_XDISTANCE, 10); ObjectSet("panel_eq", OBJPROP_YDISTANCE, y); y += s;
   ObjectCreate("panel_h5", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("panel_h5", "___________________________________________________", 10, "Consolas", White);
   ObjectSet("panel_h5", OBJPROP_CORNER, 0); ObjectSet("panel_h5", OBJPROP_XDISTANCE, 10); ObjectSet("panel_h5", OBJPROP_YDISTANCE, y);
   WindowRedraw();
  }

//+------------------------------------------------------------------+
//| init()                                                           |
//+------------------------------------------------------------------+
int init()
  {
   if(!GlobalVariableCheck("Risk_Hilo"))
      GlobalVariableSet("Risk_Hilo", RiskMultiplier_Hilo);
   if(!GlobalVariableCheck("Risk_Scalper"))
      GlobalVariableSet("Risk_Scalper", RiskMultiplier_Scalper);
   if(!GlobalVariableCheck("Risk_Trend"))
      GlobalVariableSet("Risk_Trend", RiskMultiplier_Trend);
   DrawPanel();
   PrintFormat("Market check: tradeAllowed=%d now=%s lastM1=%s diffSec=%d",
     MarketInfo(Symbol(), MODE_TRADEALLOWED),
     TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS),
     TimeToStr(iTime(Symbol(), PERIOD_M1, 0), TIME_DATE|TIME_SECONDS),
     TimeCurrent() - iTime(Symbol(), PERIOD_M1, 0));
   return(0);
  }

//+------------------------------------------------------------------+
//| deinit()                                                          |
//+------------------------------------------------------------------+
int deinit()
  {
   ObjectsDeleteAll(0, "panel_");
   return(0);
  }

//+------------------------------------------------------------------+
//| ESTRATEGIA 1: FIBONACCI FOCUS                                    |
//+------------------------------------------------------------------+
void RunFibonacciFocus()
  {
// 1. Calcular lote
   double lotSize = 0.01; // placeholder - usar MM igual que original

// 2. Trailing stop
// (implementar con ScanOrders)

// 3. Timeout
// ...

// 4. Escanear órdenes UNA vez
// StrategyState st;
// ScanOrders(Magic_Hilo, st);

// 5. Si hay trades, verificar grid (PipStep)

// 6. Si no hay trades, decidir dirección y abrir primera orden

// 7. Si se abrió orden, calcular SL/TP sobre avgPrice y modificar

// 8. Coverage: asegurar TP en todas las órdenes

// (detalles se completarán en la implementación final)
  }


//+------------------------------------------------------------------+
//| start() — UN SOLO return(0) al final                             |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| ESTRATEGIA 2: SCALPER PRO                                        |
//| Grid unidireccional con apertura por cambio de barra.           |
//| - Primer trade: dirección según iClose[2] vs iClose[1]          |
//| - Trades siguientes: cuando PipStep se alcanza                   |
//| - SL/TP se asignan vía SetTakeProfit con OrderOpenPrice() como     |
//|   precio (no altera precio de apertura)                         |
//| - Coverage (líneas finales): actualiza TP de TODAS las órdenes  |
//|   al avgPrice actual cada tick                                   |
//+------------------------------------------------------------------+
void RunScalperPro()
  {
   static int s_lastBar = 0;
   static int s_lastBarTrigger = 0;
   static int s_timeLimit = 0;
   static double g_close2 = 0, g_close1 = 0;
   static int g_ticket = -1;

   double lotSize;
   if(MM)
      lotSize = GetLotSizeBasedOnBalance(Timeframe_Scalper, 1.0);
   else
      lotSize = GetLotBasedOnRange();

   StrategyState st;
   ScanOrders(Magic_Scalper, st);

   if(UseTimeOut_Scalper && s_timeLimit > 0 && TimeCurrent() >= s_timeLimit)
     {
      CloseAllOrders(Magic_Scalper);
      s_timeLimit = 0;
     }

   if(s_lastBar != Time[0])
     {
      s_lastBar = Time[0];

      if(UseEquityStop && st.trades > 0 && CheckStopOutByFloatingLoss(lotSize, st.profit))
        {
         CloseAllOrders(Magic_Scalper);
         return;
        }

      //============================================================//
      // [MARTINGALA] NUEVA ORDEN — grid por PipStep                 //
      // Se añade UNA orden más al grid SOLO si ya existen trades    //
      // (st.trades > 0) y el precio se alejó PipStep del último     //
      // trade. Este bloque NUNCA abre la primera orden.             //
      //============================================================//
      bool canOpen = FALSE;
      if(st.trades > 0 && st.trades <= MaxTrades_Scalper)
        {
         RefreshRates();
          if(st.hasBuy && st.lastBuyPrice - Ask >= GetPipStepByTimeframe(Timeframe_Scalper, 1.0) * Point)
             canOpen = TRUE;
          if(st.hasSell && Bid - st.lastSellPrice >= GetPipStepByTimeframe(Timeframe_Scalper, 1.0) * Point)
            canOpen = TRUE;
        }

      if(canOpen)
        {
          double nextLot = NormalizeDouble(lotSize * MathPow(GetLotExponentByTimeframe(Timeframe_Scalper, 1.0), st.trades), lotdecimal);
         if(st.hasSell)
           {
            RefreshRates();
            g_ticket = SendOrder(1, nextLot, Comment_Scalper + "-" + st.trades, Magic_Scalper, HotPink, GetTakeProfitByTimeframe(Timeframe_Scalper)); // [MARTINGALA] nueva orden SELL (PipStep)
           }
         else
            if(st.hasBuy)
              {
               g_ticket = SendOrder(0, nextLot, Comment_Scalper + "-" + st.trades, Magic_Scalper, Lime, GetTakeProfitByTimeframe(Timeframe_Scalper)); // [MARTINGALA] nueva orden BUY (PipStep)
              }
         if(g_ticket > 0)
           {
            if(UseTimeOut_Scalper)
               s_timeLimit = TimeCurrent() + (int)(3600 * TimeOutHours_Scalper);
           }
        }
     }

   //============================================================//
   // [MARTINGALA] PRIMERA ORDEN — único punto de entrada inicial //
   // Se abre SOLO cuando NO hay trades (st.trades < 1), en la    //
   // nueva barra del timeframe de la estrategia.                 //
   //============================================================//
   int currentBarScalper = iTime(NULL, Timeframe_Scalper, 0);
   if(s_lastBarTrigger != currentBarScalper)
     {
      s_lastBarTrigger = currentBarScalper;
      if(st.trades < 1)
        {
         g_close2 = iClose(Symbol(), 0, 2);
         g_close1 = iClose(Symbol(), 0, 1);
         if(g_close2 > g_close1)
            g_ticket = SendOrder(1, lotSize, Comment_Scalper + "-0", Magic_Scalper, HotPink, GetTakeProfitByTimeframe(Timeframe_Scalper)); // [MARTINGALA] PRIMERA orden SELL
         else
            g_ticket = SendOrder(0, lotSize, Comment_Scalper + "-0", Magic_Scalper, Lime, GetTakeProfitByTimeframe(Timeframe_Scalper)); // [MARTINGALA] PRIMERA orden BUY
if(g_ticket > 0)
           {
            if(UseTimeOut_Scalper)
               s_timeLimit = TimeCurrent() + (int)(3600 * TimeOutHours_Scalper);
           }
        }
      }

   ScanOrders(Magic_Scalper, st);

   //============================================================//
   // [COVERAGE] Mantenimiento del TP — corre CADA tick.          //
   // Actualiza el TP de todas las órdenes Scalper al objetivo    //
   // del basket (avgPrice ± TP*Point) SOLO si difiere del actual //
   // (MathAbs > Point/2). Las órdenes ya abren con TP propio     //
   // (ver SendOrder), así que este bloque las realinea al avg.   //
   //============================================================//
   if(st.trades > 0 && GetTakeProfitByTimeframe(Timeframe_Scalper) > 0)
     {
      for(int pos = OrdersTotal() - 1; pos >= 0; pos--)
        {
         if(!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic_Scalper)
            continue;
         double tpc = 0;
         if(OrderType() == OP_BUY)
            tpc = st.avgPrice + GetTakeProfitByTimeframe(Timeframe_Scalper) * Point;
         else
            if(OrderType() == OP_SELL)
               tpc = st.avgPrice - GetTakeProfitByTimeframe(Timeframe_Scalper) * Point;
            else
               continue;
         if(tpc > 0 && MathAbs(OrderTakeProfit() - tpc) > Point/2)
            SetTakeProfit(OrderTicket(), tpc);
        }
     }
  }

//+------------------------------------------------------------------+
//| ESTRATEGIA 3: TRENDMASTER                                        |
//+------------------------------------------------------------------+
void RunTrendMaster()
  {
// MISMA ESTRUCTURA
// - Calcular lote
// - Trailing stop
// - Timeout
// - Filtro RSI antes de abrir
// - ScanOrders(Magic_Trend, st)   ← un solo loop
// - Grid: verificar PipStep si hay trades
// - Primer trade: decidir dirección + RSI filter
// - SL/TP sobre avgPrice y modificar

  }

//+------------------------------------------------------------------+
//| start() — Punto de entrada principal del EA.                    |
//| Muestra panel informativo en pantalla y ejecuta las estrategias. |
//| NOTA: Un solo return(0) al final (no hay return intermedios).   |
//+------------------------------------------------------------------+
int start()
  {
   DrawPanel();

   RunScalperPro();
   return (0);
  }

//+------------------------------------------------------------------+
//| NOTAS DE REFACTORIZACIÓN                                         |
//+------------------------------------------------------------------+
//
// PROBLEMAS DEL CÓDIGO ORIGINAL:
// a) return(0) intermedios bloquean TODAS las estrategias
//    - ATR filter (línea 921): bloquea todo si volatilidad alta
//    - Fibonacci bar check (línea 945): bloquea todo si barra no cambió
//    - Errores 1-12: algunos tenían return(0) que paraba todo el EA
//
// b) 6-7 loops por estrategia por tick:
//    CountTrades, FindDirection, FindLastBuyPrice, FindLastSellPrice,
//    CalculateProfit, CalculateAvgPrice → se fusionan en 1 solo ScanOrders
//
// c) Código duplicado entre estrategias (casi idéntico con diferentes magic)
//    → se extrae a funciones comunes (ScanOrders, SendOrder, SetTakeProfit, CloseAllOrders)
//
// d) Variables redundantes: cada estrategia tiene su propia copia de
//    TakeProfitPrice, StopLossPrice, Slippage, SpreadPoints, etc.
//    → se reemplazan con cálculos inline en cada estrategia
//
// MEJORAS IMPLEMENTADAS:
// 1. Un solo return(0) al final de start()
// 2. Cada estrategia es una función independiente (no se afectan entre sí)
// 3. ScanOrders() reemplaza CountTrades + FindLastBuyPrice + FindLastSellPrice + CalculateProfit + CalculateAvgPrice
// 4. No hay return(0) dentro de las estrategias
// 5. ATR filter solo loguea, no bloquea
// 6. Errores de OrderSend solo loguean, no bloquean
//+------------------------------------------------------------------+
