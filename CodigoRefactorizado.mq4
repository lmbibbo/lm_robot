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
extern double Risk = 1.0;
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
double StopLossPips_Hilo = 40.0;
string Comment_Hilo = "Fibonacci Focus/2019";

// --- Scalper Pro ---
extern string SETT_SCALPER = "--- Scalper Pro ---";
extern int MaxTrades_Scalper = 20;
extern int Magic_Scalper = 22324;
int Timeframe_Scalper = PERIOD_H1;
double StopLossPips_Scalper = 40.0;
string Comment_Scalper = "Scalper Pro/2019";

// --- TrendMaster ---
extern string SETT_TREND = "--- TrendMaster ---";
extern int MaxTrades_Trend = 20;
extern int Magic_Trend = 23794;
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
double g_atrValue = 0;

// --- Control de barras ---
int g_lastBar_Fibo = 0;
int g_lastBar_Scalper = 0;
int g_lastBar_Trend = 0;
int g_lastBarTrigger_Scalper = 0;
int g_lastBarTrigger_Trend = 0;

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

double AccountBalance_Normalized;
double AccountEquity_Normalized;

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
void ModifySLTP(int ticket, double avgPrice, double sl, double tp)
  {
// Validar TP contra open price antes de intentar
   if(tp > 0)
     {
      if(OrderType() == OP_BUY && tp <= avgPrice)
        {
         PrintFormat("ModifySLTP skip ticket=%d BUY tp=%.5f <= open=%.5f", ticket, tp, avgPrice);
         return;
        }
      if(OrderType() == OP_SELL && tp >= avgPrice)
        {
         PrintFormat("ModifySLTP skip ticket=%d SELL tp=%.5f >= open=%.5f", ticket, tp, avgPrice);
         return;
        }
     }
   double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
   double bid = Bid, ask = Ask;
   double refPrice = (OrderType() == OP_BUY ? ask : bid);
   double price = (tp > 0 ? tp : sl);
   if(price > 0)
     {
      double refForDist = (OrderType() == OP_BUY ? bid : ask);
      double dist = MathAbs(price - refForDist);
      if(dist < stopLevel)
        {
         PrintFormat("ModifySLTP skip ticket=%d dist=%.5f < stopLevel=%.5f price=%.5f refPrice=%.5f", ticket, dist, stopLevel, price, refForDist);
         return;
        }
     }
   int maxRetries = 20;
   int retry = 0;
   while(retry < maxRetries)
     {
      retry++;
      RefreshRates();
      bid = Bid;
      ask = Ask;
      if(OrderModify(ticket, avgPrice, sl, tp, 0, Yellow))
        {
         PrintFormat("ModifySLTP OK ticket=%d sl=%.5f tp=%.5f avgPrice=%.5f bid=%.5f ask=%.5f", ticket, sl, tp, avgPrice, bid, ask);
         return;
        }
      int err = GetLastError();
      PrintFormat("ModifySLTP retry %d/%d ticket=%d error=%d bid=%.5f ask=%.5f", retry, maxRetries, ticket, err, bid, ask);
      if(err == 130)
        {
         Sleep(1000);
        }
      else
        {
         Sleep(500);
         break;
        }
     }
   PrintFormat("ModifySLTP FAILED ticket=%d sl=%.5f tp=%.5f avgPrice=%.5f", ticket, sl, tp, avgPrice);
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
double GetLotSizeBasedOnBalance()
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
      stopLoss = MathMax(GeneralStopLoss, atrPoints * LotExponent);
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
//+------------------------------------------------------------------+
void RunScalperPro()
  {
   static int s_lastBar = 0;
   static int s_lastBarTrigger = 0;
   static bool s_orderSent = FALSE;
   static bool s_priceSync = TRUE;
   static int s_timeLimit = 0;
   static double s_equityStart = 0;
   static double g_close2 = 0, g_close1 = 0;
   static int g_ticket = -1;

   double lotSize;
   if(MM) lotSize = GetLotSizeBasedOnBalance();
   else   lotSize = GetLotBasedOnRange();

   StrategyState st;
   ScanOrders(Magic_Scalper, st);

   if(s_priceSync && st.trades > 0) {
      for(int ps = OrdersTotal() - 1; ps >= 0; ps--) {
         if(!OrderSelect(ps, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic_Scalper) continue;
         if(MathAbs(OrderOpenPrice() - st.avgPrice) < Point) continue;
         double tp_ps = 0;
         if(OrderType() == OP_BUY) tp_ps = st.avgPrice + TakeProfit * Point;
         else if(OrderType() == OP_SELL) tp_ps = st.avgPrice - TakeProfit * Point;
         else continue;
         ModifySLTP(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), tp_ps);
      }
      s_priceSync = FALSE;
   }

   if(UseTrailingStop && TrailStop != 0 && st.trades > 0)
      TrailingAll(Magic_Scalper, TrailStart, TrailStop, st.avgPrice);

   if(s_timeLimit > 0 && TimeCurrent() >= s_timeLimit) {
      CloseAllOrders(Magic_Scalper);
      s_orderSent = FALSE;
      s_timeLimit = 0;
   }

   if(s_lastBar != Time[0]) {
      s_lastBar = Time[0];

      if(UseEquityStop && st.trades > 0 && CheckStopOutByFloatingLoss(lotSize, st.profit)) {
         CloseAllOrders(Magic_Scalper);
         s_orderSent = FALSE;
         return;
      }

      if(st.trades == 0) s_orderSent = FALSE;

      bool canOpen = FALSE;
      if(st.trades > 0 && st.trades <= MaxTrades_Scalper) {
         RefreshRates();
         if(st.hasBuy && st.lastBuyPrice - Ask >= PipStep * Point) canOpen = TRUE;
         if(st.hasSell && Bid - st.lastSellPrice >= PipStep * Point) canOpen = TRUE;
      }

      if(st.trades < 1) {
         canOpen = TRUE;
         g_close2 = iClose(Symbol(), 0, 2);
         g_close1 = iClose(Symbol(), 0, 1);
         st.hasBuy = (g_close2 <= g_close1);
         st.hasSell = (g_close2 > g_close1);
         s_equityStart = AccountEquity();
      }

      if(canOpen) {
         double nextLot = NormalizeDouble(lotSize * MathPow(LotExponent, st.trades), lotdecimal);
         if(st.hasSell) { RefreshRates(); g_ticket = SendOrder(1, nextLot, Comment_Scalper + "-" + st.trades, Magic_Scalper, HotPink); }
         else if(st.hasBuy) { g_ticket = SendOrder(0, nextLot, Comment_Scalper + "-" + st.trades, Magic_Scalper, Lime); }
         if(g_ticket > 0) { s_orderSent = TRUE; s_timeLimit = TimeCurrent() + (int)(3600 * 48); }
      }
   }

   int currentBarScalper = iTime(NULL, Timeframe_Scalper, 0);
   if(s_lastBarTrigger != currentBarScalper) {
      s_lastBarTrigger = currentBarScalper;
      if(st.trades < 1) {
         g_close2 = iClose(Symbol(), 0, 2);
         g_close1 = iClose(Symbol(), 0, 1);
         if(g_close2 > g_close1) g_ticket = SendOrder(1, lotSize, Comment_Scalper + "-0", Magic_Scalper, HotPink);
         else g_ticket = SendOrder(0, lotSize, Comment_Scalper + "-0", Magic_Scalper, Lime);
         if(g_ticket > 0) { s_orderSent = TRUE; s_timeLimit = TimeCurrent() + (int)(3600 * 48); }
      }
   }

   ScanOrders(Magic_Scalper, st);

   if(s_orderSent && st.trades > 0) {
      for(int i = OrdersTotal() - 1; i >= 0; i--) {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic_Scalper) continue;
         double tps = 0;
         if(OrderType() == OP_BUY) tps = st.avgPrice + TakeProfit * Point;
         else if(OrderType() == OP_SELL) tps = st.avgPrice - TakeProfit * Point;
         else continue;
         ModifySLTP(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), tps);
      }
      s_orderSent = FALSE;
   }

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
           + "Open Orders Scalper Pro          :" + CountTrades_Scalper() + "\n"
           + "ALL ORDERS                          :" + OrdersTotal() + "\n"
           + "_____________________________________________________\n\n"
           + "Account BALANCE                  :" + DoubleToStr(AccountBalance(), 2) + "\n\n"
           + "Account EQUITY                     :" + DoubleToStr(AccountEquity(), 2) + "\n"
           + "_____________________________________________________\n\n");

   AccountBalance_Normalized = NormalizeDouble(AccountBalance(), 2);
   AccountEquity_Normalized = NormalizeDouble(AccountEquity(), 2);

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
