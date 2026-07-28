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
extern double LotExponent = 1.667;
extern int lotdecimal = 5;
extern double PipStep = 220.0;
extern double MaxLots = 9.0;
extern bool MM = TRUE;
extern double Risk = 2.0;
extern double TakeProfit = 80.0;
extern bool UseEquityStop = FALSE;
extern double TotalEquityRisk = 20.0;
extern bool UseTrailingStop = FALSE;
extern double TrailStart = 13.0;
extern double TrailStop = 3.0;
extern double slip = 3.0;

//+------------------------------------------------------------------+
//| CONFIGURACIÓN POR ESTRATEGIA                                     |
//+------------------------------------------------------------------+

// --- Fibonacci Focus ---
extern string SETT_FIBO = "--- Fibonacci Focus ---";
extern int MaxTrades_Hilo = 20;
extern int Magic_Hilo = 10278;
extern double RiskMultiplier_Hilo = 1.0;
extern int Timeframe_Hilo = PERIOD_M1;
extern bool UseTimeOut_Hilo = FALSE;
extern double TimeOutHours_Hilo = 48.0;
double StopLossPips_Hilo = 40.0;
string Comment_Hilo = "Fibonacci Focus/2019";

// --- Scalper Pro ---
extern string SETT_SCALPER = "--- Scalper Pro ---";
extern int MaxTrades_Scalper = 20;
extern int Magic_Scalper = 22324;
extern double RiskMultiplier_Scalper = 1.0; // 0.5=conservador, 1.0=default, 2.0=agresivo
extern int Timeframe_Scalper = PERIOD_M1;
double StopLossPips_Scalper = 40.0;
string Comment_Scalper = "Scalper Pro/2019";

// --- TrendMaster ---
extern string SETT_TREND = "--- TrendMaster ---";
extern int MaxTrades_Trend = 20;
extern int Magic_Trend = 23794;
extern double RiskMultiplier_Trend = 1.0; // 0.5=conservador, 1.0=default, 2.0=agresivo
extern bool UseTimeOut_Trend = FALSE;
extern double TimeOutHours_Trend = 48.0;
extern int Timeframe_Trend = PERIOD_M1;
double StopLossPips_Trend = 40.0;
string Comment_Trend = "TrendMaster/2019";

//+------------------------------------------------------------------+
//| VARIABLES DE ESTADO (compartidas, sin duplicar por estrategia)   |
//+------------------------------------------------------------------+

// --- Protección ATR ---
extern double MaxAllowedATR = 150.0;
extern int ATR_Period = 14;
extern int ATR_Timeframe = PERIOD_M1;
double g_atrValue = 0;



// --- Variables panel visual ---
// (se mantienen igual que el original si se quiere el panel)
// bool cg = FALSE;

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
//| SCAN ÚNICO: recorre las órdenes UNA VEZ por estrategia           |
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
      case PERIOD_M1:  base = 1.2;   break;
      case PERIOD_M5:  base = 1.25;  break;
      case PERIOD_M15: base = 1.35;  break;
      case PERIOD_M30: base = 1.5;   break;
      case PERIOD_H1:  base = 1.667; break;
      case PERIOD_H4:  base = 1.8;   break;
      case PERIOD_D1:  base = 2.0;   break;
      default:         base = 1.5;
     }
   double r = MathMax(0.5, MathMin(2.0, riskMultiplier));
   return NormalizeDouble(MathMax(1.01, base * r), 4);
  }

double GetPipStepByTimeframe(int tf, double riskMultiplier)
  {
   double base;
   switch(tf)
     {
      case PERIOD_M1:  base = 40;  break;
      case PERIOD_M5:  base = 80;  break;
      case PERIOD_M15: base = 130; break;
      case PERIOD_M30: base = 180; break;
      case PERIOD_H1:  base = 220; break;
      case PERIOD_H4:  base = 400; break;
      case PERIOD_D1:  base = 700; break;
      default:         base = 220;
     }
   double r = MathMax(0.5, MathMin(2.0, riskMultiplier));
   return NormalizeDouble(MathMax(10, base / r), 1);
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
//|                                                                  |
//+------------------------------------------------------------------+
bool isHighVolatility()
  {
   double atr = iATR(Symbol(), ATR_Timeframe, ATR_Period, 0) / Point;
   g_atrValue = atr;
   return (atr > MaxAllowedATR);
  }

//+------------------------------------------------------------------+
//|                                                                  |
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
//|                                                                  |
//+------------------------------------------------------------------+
int SendOrder(int type, double lots, string comment, int magic, color arrow)
  {
   int ticket = 0;
   int err = 0;
   for(int retry = 0; retry < 100; retry++)
     {
      RefreshRates();
      if(type == 0)  // BUY
         ticket = OrderSend(Symbol(), OP_BUY, lots, Ask, (int)slip, 0, 0, comment, magic, 0, arrow);
      else            // SELL
         ticket = OrderSend(Symbol(), OP_SELL, lots, Bid, (int)slip, 0, 0, comment, magic, 0, arrow);

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
//|                                                                  |
//+------------------------------------------------------------------+
void ModifySLTP(int ticket, double avgP, double sl, double tp)
  {
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
     {
      PrintFormat("ModifySLTP cant select ticket=%d", ticket);
      return;
     }
   RefreshRates();
   int oType = OrderType();
   int stopLevel = MathMax(10, (int)MarketInfo(Symbol(), MODE_STOPLEVEL));
   double minDist = (stopLevel + 2) * Point;

   if(sl != 0)
     {
      double refSL = (oType == OP_BUY) ? Bid : Ask;
      if(MathAbs(sl - refSL) < minDist)
        {
         PrintFormat("ModifySLTP SKIP sl ticket=%d sl=%.5f ref=%.5f dist=%.0f stopLvl=%d", ticket, sl, refSL, MathAbs(sl - refSL) / Point, stopLevel);
         return;
        }
     }
   if(tp != 0)
     {
      double refTP = (oType == OP_BUY) ? Ask : Bid;
      if(MathAbs(tp - refTP) < minDist)
        {
         PrintFormat("ModifySLTP SKIP tp ticket=%d tp=%.5f ref=%.5f dist=%.0f stopLvl=%d", ticket, tp, refTP, MathAbs(tp - refTP) / Point, stopLevel);
         return;
        }
     }

   double ref = (oType == OP_BUY) ? Ask : Bid;
   for(int retry = 0; retry < 20; retry++)
     {
      RefreshRates();
      if(OrderModify(ticket, avgP, sl, tp, 0, Yellow))
        {
         PrintFormat("ModifySLTP OK ticket=%d price=%.5f sl=%.5f tp=%.5f", ticket, avgP, sl, tp);
         return;
        }
      int err = GetLastError();
      ref = (oType == OP_BUY) ? Ask : Bid;
      PrintFormat("ModifySLTP retry %d ticket=%d err=%d price=%.5f ref=%.5f tp=%.5f stopLvl=%d", retry+1, ticket, err, avgP, ref, tp, stopLevel);
      Sleep(500);
     }
   PrintFormat("ModifySLTP GIVEUP ticket=%d tp=%.5f ref=%.5f stopLvl=%d", ticket, tp, ref, stopLevel);
  }

//+------------------------------------------------------------------+
//| FUNCIONES DE GESTIÓN DE RIESGO Y MM                              |
//+------------------------------------------------------------------+

// Trailing stop genérico (por magic number)
void TrailingAll(int magic, int trailStart, int trailStop, double avgPrice)
  {
   if(trailStop == 0)
      return;
   int diff;
   double sl, target;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != magic)
         continue;

      if(OrderType() == OP_BUY)
        {
         diff = NormalizeDouble((Bid - avgPrice) / Point, 0);
         if(diff < trailStart)
            continue;
         sl = OrderStopLoss();
         target = Bid - trailStop * Point;
         // validar que SL esté por debajo del open price
         if(target >= OrderOpenPrice())
           {
            Print("TrailingAll BUY skip: target SL=", target, " >= open=", OrderOpenPrice());
            continue;
           }
         if(sl == 0.0 || target > sl)
           {
            if(!OrderModify(OrderTicket(), OrderOpenPrice(), target, OrderTakeProfit(), 0, Aqua))
               Print("TrailingAll BUY modify error ", GetLastError());
           }
        }
      else
         if(OrderType() == OP_SELL)
           {
            diff = NormalizeDouble((avgPrice - Ask) / Point, 0);
            if(diff < trailStart)
               continue;
            sl = OrderStopLoss();
            target = Ask + trailStop * Point;
            // validar que SL esté por encima del open price
            if(target <= OrderOpenPrice())
              {
               Print("TrailingAll SELL skip: target SL=", target, " <= open=", OrderOpenPrice());
               continue;
              }
            if(sl == 0.0 || target < sl)
              {
               if(!OrderModify(OrderTicket(), OrderOpenPrice(), target, OrderTakeProfit(), 0, Red))
                  Print("TrailingAll SELL modify error ", GetLastError());
              }
           }
      Sleep(1000);
     }
  }

// Verificar si la pérdida flotante excede los umbrales
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

// Calcular lote según balance y riesgo (MM)
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

// Calcular lote según rango de balance (sin MM)
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
   return(0);
  }

//+------------------------------------------------------------------+
//| deinit()                                                          |
//+------------------------------------------------------------------+
int deinit()
  {
   return(0);
  }

//+------------------------------------------------------------------+
//| ESTRATEGIA 1: FIBONACCI FOCUS                                    |
//+------------------------------------------------------------------+
void RunFibonacciFocus()
  {
   static int s_lastBarFibo = 0;
   static bool s_orderSent_Fibo = FALSE;
   static int s_timeLimit_Fibo = 0;

   double rmHilo = RiskMultiplier_Hilo;
   if(GlobalVariableCheck("Risk_Hilo"))
      rmHilo = MathMax(0.5, MathMin(2.0, GlobalVariableGet("Risk_Hilo")));

   double lotSize;
   if(MM) lotSize = GetLotSizeBasedOnBalance(Timeframe_Hilo, rmHilo);
   else   lotSize = GetLotBasedOnRange();

   StrategyState st;
   ScanOrders(Magic_Hilo, st);

   if(UseTrailingStop && TrailStop != 0 && st.trades > 0)
      TrailingAll(Magic_Hilo, TrailStart, TrailStop, st.avgPrice);

   if(st.trades > 0 && TakeProfit > 0) {
      RefreshRates();
      bool hitTP = FALSE;
      if(st.hasBuy && Bid >= st.avgPrice + TakeProfit * Point) hitTP = TRUE;
      if(st.hasSell && Ask <= st.avgPrice - TakeProfit * Point) hitTP = TRUE;
      if(hitTP) {
         CloseAllOrders(Magic_Hilo);
         s_orderSent_Fibo = FALSE;
         s_timeLimit_Fibo = 0;
      }
   }

   if(UseTimeOut_Hilo && s_timeLimit_Fibo > 0 && TimeCurrent() >= s_timeLimit_Fibo) {
      CloseAllOrders(Magic_Hilo);
      s_orderSent_Fibo = FALSE;
      s_timeLimit_Fibo = 0;
   }

   int barFibo = iTime(NULL, Timeframe_Hilo, 0);
   if(s_lastBarFibo != barFibo) {
      s_lastBarFibo = barFibo;

      if(UseEquityStop && st.trades > 0 && CheckStopOutByFloatingLoss(lotSize, st.profit)) {
         CloseAllOrders(Magic_Hilo);
         s_orderSent_Fibo = FALSE;
         return;
      }

      if(st.trades == 0) s_orderSent_Fibo = FALSE;

      bool canOpen = FALSE;
      if(st.trades > 0 && st.trades <= MaxTrades_Hilo) {
         RefreshRates();
         if(st.hasBuy && st.lastBuyPrice - Ask >= GetPipStepByTimeframe(Timeframe_Hilo, rmHilo) * Point)
            canOpen = TRUE;
         if(st.hasSell && Bid - st.lastSellPrice >= GetPipStepByTimeframe(Timeframe_Hilo, rmHilo) * Point)
            canOpen = TRUE;
      }

      if(st.trades < 1) {
         double high1 = iHigh(Symbol(), Timeframe_Hilo, 1);
         double low2  = iLow(Symbol(), Timeframe_Hilo, 2);
         if(high1 > low2) {
            if(iRSI(NULL, Timeframe_Hilo, 14, PRICE_CLOSE, 1) > 30.0) {
               canOpen = TRUE;
               st.hasSell = TRUE;
               st.hasBuy = FALSE;
            }
         } else {
            if(iRSI(NULL, Timeframe_Hilo, 14, PRICE_CLOSE, 1) < 70.0) {
               canOpen = TRUE;
               st.hasBuy = TRUE;
               st.hasSell = FALSE;
            }
         }
      }

      if(canOpen) {
         double nextLot = NormalizeDouble(lotSize * MathPow(GetLotExponentByTimeframe(Timeframe_Hilo, rmHilo), st.trades), lotdecimal);
         if(st.hasSell) { RefreshRates(); SendOrder(1, nextLot, Comment_Hilo + "-" + st.trades, Magic_Hilo, HotPink); }
         else if(st.hasBuy) { RefreshRates(); SendOrder(0, nextLot, Comment_Hilo + "-" + st.trades, Magic_Hilo, Lime); }
         s_orderSent_Fibo = TRUE;
         if(UseTimeOut_Hilo)
            s_timeLimit_Fibo = TimeCurrent() + (int)(3600 * TimeOutHours_Hilo);
      }
   }

   ScanOrders(Magic_Hilo, st);

   if(st.trades > 0 && TakeProfit > 0) {
      for(int pos = OrdersTotal() - 1; pos >= 0; pos--) {
         if(!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic_Hilo) continue;
         double tpc_f = 0;
         if(OrderType() == OP_BUY) tpc_f = st.avgPrice + TakeProfit * Point;
         else if(OrderType() == OP_SELL) tpc_f = st.avgPrice - TakeProfit * Point;
         else continue;
         if(tpc_f > 0 && MathAbs(OrderTakeProfit() - tpc_f) > Point/2)
            ModifySLTP(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), tpc_f);
      }
   }
  }

//+------------------------------------------------------------------+
//| ESTRATEGIA 2: SCALPER PRO                                        |
//+------------------------------------------------------------------+
void RunScalperPro()
  {
   static int s_lastBarScalper = 0;
   static bool s_orderSent = FALSE;
   static int s_timeLimit = 0;
   static double s_equityStart = 0;
   static int g_ticket = -1;

   double rmScalper = RiskMultiplier_Scalper;
   if(GlobalVariableCheck("Risk_Scalper"))
      rmScalper = MathMax(0.5, MathMin(2.0, GlobalVariableGet("Risk_Scalper")));

   double lotSize;
   if(MM) lotSize = GetLotSizeBasedOnBalance(Timeframe_Scalper, rmScalper);
   else   lotSize = GetLotBasedOnRange();

   StrategyState st;
   ScanOrders(Magic_Scalper, st);

   if(UseTrailingStop && TrailStop != 0 && st.trades > 0)
      TrailingAll(Magic_Scalper, TrailStart, TrailStop, st.avgPrice);

   if(st.trades > 0 && TakeProfit > 0) {
      RefreshRates();
      bool hitTP = FALSE;
      if(st.hasBuy && Bid >= st.avgPrice + TakeProfit * Point) hitTP = TRUE;
      if(st.hasSell && Ask <= st.avgPrice - TakeProfit * Point) hitTP = TRUE;
      if(hitTP) {
         CloseAllOrders(Magic_Scalper);
         s_orderSent = FALSE;
         s_timeLimit = 0;
      }
   }

   if(s_timeLimit > 0 && TimeCurrent() >= s_timeLimit) {
      CloseAllOrders(Magic_Scalper);
      s_orderSent = FALSE;
      s_timeLimit = 0;
   }

   int barScalper = iTime(NULL, Timeframe_Scalper, 0);
   if(s_lastBarScalper != barScalper) {
      s_lastBarScalper = barScalper;

      if(UseEquityStop && st.trades > 0 && CheckStopOutByFloatingLoss(lotSize, st.profit)) {
         CloseAllOrders(Magic_Scalper);
         s_orderSent = FALSE;
         return;
      }

      if(st.trades == 0) s_orderSent = FALSE;

      bool canOpen = FALSE;
      if(st.trades > 0 && st.trades <= MaxTrades_Scalper) {
         RefreshRates();
         if(st.hasBuy && st.lastBuyPrice - Ask >= GetPipStepByTimeframe(Timeframe_Scalper, rmScalper) * Point) canOpen = TRUE;
         if(st.hasSell && Bid - st.lastSellPrice >= GetPipStepByTimeframe(Timeframe_Scalper, rmScalper) * Point) canOpen = TRUE;
      }

      if(st.trades < 1) {
         canOpen = TRUE;
         double g_close2 = iClose(Symbol(), 0, 2);
         double g_close1 = iClose(Symbol(), 0, 1);
         st.hasBuy = (g_close2 <= g_close1);
         st.hasSell = (g_close2 > g_close1);
         s_equityStart = AccountEquity();
      }

      if(canOpen) {
         double nextLot = NormalizeDouble(lotSize * MathPow(GetLotExponentByTimeframe(Timeframe_Scalper, rmScalper), st.trades), lotdecimal);
         if(st.hasSell) { RefreshRates(); g_ticket = SendOrder(1, nextLot, Comment_Scalper + "-" + st.trades, Magic_Scalper, HotPink); }
         else if(st.hasBuy) { g_ticket = SendOrder(0, nextLot, Comment_Scalper + "-" + st.trades, Magic_Scalper, Lime); }
         if(g_ticket > 0) { s_orderSent = TRUE; s_timeLimit = TimeCurrent() + (int)(3600 * 48); }
      }
   }

   ScanOrders(Magic_Scalper, st);

   if(st.trades > 0 && TakeProfit > 0) {
      for(int pos = OrdersTotal() - 1; pos >= 0; pos--) {
         if(!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic_Scalper) continue;
         double tpc = 0;
         if(OrderType() == OP_BUY) tpc = st.avgPrice + TakeProfit * Point;
         else if(OrderType() == OP_SELL) tpc = st.avgPrice - TakeProfit * Point;
         else continue;
         if(tpc > 0 && MathAbs(OrderTakeProfit() - tpc) > Point/2)
            ModifySLTP(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), tpc);
      }
   }
  }

//+------------------------------------------------------------------+
//| ESTRATEGIA 3: TRENDMASTER                                        |
//+------------------------------------------------------------------+
void RunTrendMaster()
  {
   static int s_lastBarTrend = 0;
   static bool s_orderSent_Trend = FALSE;
   static int s_timeLimit_Trend = 0;
   static int g_ticket_Trend = -1;

   double rmTrend = RiskMultiplier_Trend;
   if(GlobalVariableCheck("Risk_Trend"))
      rmTrend = MathMax(0.5, MathMin(2.0, GlobalVariableGet("Risk_Trend")));

   double lotSize;
   if(MM) lotSize = GetLotSizeBasedOnBalance(Timeframe_Trend, rmTrend);
   else   lotSize = GetLotBasedOnRange();

   StrategyState st;
   ScanOrders(Magic_Trend, st);

   if(UseTrailingStop && TrailStop != 0 && st.trades > 0)
      TrailingAll(Magic_Trend, TrailStart, TrailStop, st.avgPrice);

   if(st.trades > 0 && TakeProfit > 0) {
      RefreshRates();
      bool hitTP = FALSE;
      if(st.hasBuy && Bid >= st.avgPrice + TakeProfit * Point) hitTP = TRUE;
      if(st.hasSell && Ask <= st.avgPrice - TakeProfit * Point) hitTP = TRUE;
      if(hitTP) {
         CloseAllOrders(Magic_Trend);
         s_orderSent_Trend = FALSE;
         s_timeLimit_Trend = 0;
      }
   }

   if(UseTimeOut_Trend && s_timeLimit_Trend > 0 && TimeCurrent() >= s_timeLimit_Trend) {
      CloseAllOrders(Magic_Trend);
      s_orderSent_Trend = FALSE;
      s_timeLimit_Trend = 0;
   }

   int barTrend = iTime(NULL, Timeframe_Trend, 0);
   if(s_lastBarTrend != barTrend) {
      s_lastBarTrend = barTrend;

      if(UseEquityStop && st.trades > 0 && CheckStopOutByFloatingLoss(lotSize, st.profit)) {
         CloseAllOrders(Magic_Trend);
         s_orderSent_Trend = FALSE;
         return;
      }

      if(st.trades == 0) s_orderSent_Trend = FALSE;

      bool canOpen = FALSE;
      if(st.trades > 0 && st.trades <= MaxTrades_Trend) {
         RefreshRates();
         if(st.hasBuy && st.lastBuyPrice - Ask >= GetPipStepByTimeframe(Timeframe_Trend, rmTrend) * Point)
            canOpen = TRUE;
         if(st.hasSell && Bid - st.lastSellPrice >= GetPipStepByTimeframe(Timeframe_Trend, rmTrend) * Point)
            canOpen = TRUE;
      }

      if(st.trades < 1) {
         double g_close2_t = iClose(Symbol(), 0, 2);
         double g_close1_t = iClose(Symbol(), 0, 1);
         if(g_close2_t > g_close1_t) {
            if(iRSI(NULL, Timeframe_Trend, 14, PRICE_CLOSE, 1) > 30.0) {
               canOpen = TRUE;
               st.hasSell = TRUE;
               st.hasBuy = FALSE;
            }
         } else {
            if(iRSI(NULL, Timeframe_Trend, 14, PRICE_CLOSE, 1) < 70.0) {
               canOpen = TRUE;
               st.hasBuy = TRUE;
               st.hasSell = FALSE;
            }
         }
      }

      if(canOpen) {
         double nextLot = NormalizeDouble(lotSize * MathPow(GetLotExponentByTimeframe(Timeframe_Trend, rmTrend), st.trades), lotdecimal);
         if(st.hasSell) { RefreshRates(); g_ticket_Trend = SendOrder(1, nextLot, Comment_Trend + "-" + st.trades, Magic_Trend, HotPink); }
         else if(st.hasBuy) { g_ticket_Trend = SendOrder(0, nextLot, Comment_Trend + "-" + st.trades, Magic_Trend, Lime); }
         if(g_ticket_Trend > 0) {
            s_orderSent_Trend = TRUE;
            if(UseTimeOut_Trend)
               s_timeLimit_Trend = TimeCurrent() + (int)(3600 * TimeOutHours_Trend);
         }
      }
   }

   ScanOrders(Magic_Trend, st);

   if(st.trades > 0 && TakeProfit > 0) {
      for(int pos = OrdersTotal() - 1; pos >= 0; pos--) {
         if(!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic_Trend) continue;
         double tpc_t = 0;
         if(OrderType() == OP_BUY) tpc_t = st.avgPrice + TakeProfit * Point;
         else if(OrderType() == OP_SELL) tpc_t = st.avgPrice - TakeProfit * Point;
         else continue;
         if(tpc_t > 0 && MathAbs(OrderTakeProfit() - tpc_t) > Point/2)
            ModifySLTP(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), tpc_t);
      }
   }
  }

//+------------------------------------------------------------------+
//| start() — UN SOLO return(0) al final                             |
//+------------------------------------------------------------------+
int start()
  {
   string marketStatus = (MarketInfo(Symbol(), MODE_TRADEALLOWED) > 0) ? "ABIERTO" : "CERRADO";

   Comment("___________________________________________________\n\n\n"
           + "Broker                                    :" + AccountCompany() + "\n"
           + "Brokers Time                          :" + TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\n"
           + "Market                                    :" + marketStatus + "\n"
           + "Spread                                    :" + IntegerToString(MarketInfo(Symbol(), MODE_SPREAD)) + "\n"
           + "___________________________________________________\n\n"
           + "Name                                     :" + AccountName() + "\n"
           + "Account Number                    :" + AccountNumber() + "\n"
           + "Account Currency                  :" + AccountCurrency() + "\n"
           + "____________________________________________________\n\n"
            + "Open Orders Fibonacci Focus      :" + CountTrades_Hilo() + "\n"
            + "Open Orders Scalper Pro          :" + CountTrades_Scalper() + "\n"
            + "Open Orders TrendMaster          :" + CountTrades_Trend() + "\n"
            + "ALL ORDERS                          :" + OrdersTotal() + "\n"
           + "_____________________________________________________\n\n"
           + "Account BALANCE                  :" + DoubleToStr(AccountBalance(), 2) + "\n\n"
           + "Account EQUITY                     :" + DoubleToStr(AccountEquity(), 2) + "\n"
           + "_____________________________________________________\n\n");


   RunFibonacciFocus();
   RunScalperPro();
   RunTrendMaster();

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
//    → se extrae a funciones comunes (ScanOrders, SendOrder, ModifySLTP, CloseAllOrders)
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
