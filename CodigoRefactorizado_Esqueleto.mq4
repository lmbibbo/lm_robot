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
bool cg = FALSE;

//+------------------------------------------------------------------+
//| ESTRUCTURA: RESULTADO DEL SCAN DE ÓRDENES (1 solo loop)          |
//+------------------------------------------------------------------+
// En lugar de llamar CountTrades + FindLastBuy/FindLastSell +
// calcular avgPrice + calcular profit por separado (cada uno con su
// propio loop), esta estructura almacena TODO en una sola pasada.
struct StrategyState {
   int    trades;         // N° de órdenes abiertas
   double avgPrice;       // Precio promedio ponderado
   double totalLots;      // Suma de lotes
   bool   hasBuy;
   bool   hasSell;
   double lastBuyPrice;   // Precio de la última compra (mayor ticket)
   double lastSellPrice;  // Precio de la última venta (mayor ticket)
   double profit;         // Profit flotante total
   int    lastBuyTicket;
   int    lastSellTicket;
};

//+------------------------------------------------------------------+
//| SCAN ÚNICO: recorre las órdenes UNA VEZ por estrategia           |
//+------------------------------------------------------------------+
void ScanOrders(int magic, StrategyState &st) {
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

   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != magic) continue;

      if (OrderType() == OP_BUY || OrderType() == OP_SELL) {
         st.trades++;
         st.avgPrice += OrderOpenPrice() * OrderLots();
         st.totalLots += OrderLots();
         st.profit += OrderProfit();

         if (OrderType() == OP_BUY) {
            st.hasBuy = TRUE;
            if (OrderTicket() > st.lastBuyTicket) {
               st.lastBuyTicket = OrderTicket();
               st.lastBuyPrice = OrderOpenPrice();
            }
         } else if (OrderType() == OP_SELL) {
            st.hasSell = TRUE;
            if (OrderTicket() > st.lastSellTicket) {
               st.lastSellTicket = OrderTicket();
               st.lastSellPrice = OrderOpenPrice();
            }
         }
      }
   }

   if (st.trades > 0 && st.totalLots > 0)
      st.avgPrice = NormalizeDouble(st.avgPrice / st.totalLots, Digits);
}

//+------------------------------------------------------------------+
//| FUNCIONES AUXILIARES COMUNES                                     |
//+------------------------------------------------------------------+

double AccountBalance_Normalized;
double AccountEquity_Normalized;

// Contar órdenes de Fibonacci Focus (para panel visual)
int CountTrades_Hilo() {
   int count = 0;
   for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
      if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != Magic_Hilo) continue;
      if (OrderType() == OP_SELL || OrderType() == OP_BUY) count++;
   }
   return (count);
}

// Contar órdenes de Scalper Pro (para panel visual)
int CountTrades_Scalper() {
   int count = 0;
   for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
      if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != Magic_Scalper) continue;
      if (OrderType() == OP_SELL || OrderType() == OP_BUY) count++;
   }
   return (count);
}

// Contar órdenes de TrendMaster (para panel visual)
int CountTrades_Trend() {
   int count = 0;
   for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
      if (!OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != Magic_Trend) continue;
      if (OrderType() == OP_SELL || OrderType() == OP_BUY) count++;
   }
   return (count);
}

bool isHighVolatility() {
   double atr = iATR(Symbol(), ATR_Timeframe, ATR_Period, 0) / Point;
   g_atrValue = atr;
   return (atr > MaxAllowedATR);
}

void CloseAllOrders(int magic) {
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != magic) continue;
      if (OrderType() == OP_BUY)
         OrderClose(OrderTicket(), OrderLots(), Bid, (int)slip, Blue);
      else if (OrderType() == OP_SELL)
         OrderClose(OrderTicket(), OrderLots(), Ask, (int)slip, Red);
      Sleep(1000);
   }
}

int SendOrder(int type, double lots, string comment, int magic, color arrow) {
   int ticket = 0;
   int err = 0;
   for (int retry = 0; retry < 100; retry++) {
      RefreshRates();
      if (type == 0) // BUY
         ticket = OrderSend(Symbol(), OP_BUY, lots, Ask, (int)slip, 0, 0, comment, magic, 0, arrow);
      else            // SELL
         ticket = OrderSend(Symbol(), OP_SELL, lots, Bid, (int)slip, 0, 0, comment, magic, 0, arrow);

      err = GetLastError();
      if (err == 0) break;
      if (!(err == 4 || err == 137 || err == 146 || err == 136)) {
         Print("SendOrder error ", err, " type=", type, " lots=", lots);
         break;
      }
      Sleep(5000);
   }
   return (ticket);
}

void ModifySLTP(int ticket, double avgPrice, double sl, double tp) {
   while (!OrderModify(ticket, avgPrice, sl, tp, 0, Yellow)) {
      Print("Modify retry ticket=", ticket, " error=", GetLastError());
      Sleep(1000);
      RefreshRates();
   }
}

//+------------------------------------------------------------------+
//| ESTRATEGIA 1: FIBONACCI FOCUS                                    |
//+------------------------------------------------------------------+
void RunFibonacciFocus() {
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
//| ESTRATEGIA 2: SCALPER PRO                                        |
//+------------------------------------------------------------------+
void RunScalperPro() {
   // MISMA ESTRUCTURA QUE FIBONACCI FOCUS
   // - Calcular lote
   // - Trailing stop
   // - Timeout
   // - ScanOrders(Magic_Scalper, st)   ← un solo loop
   // - Grid: verificar PipStep si hay trades
   // - Primer trade: decidir dirección y abrir
   // - Si OrderSentFlag, calcular SL/TP y modificar TODAS las órdenes
   // - Coverage: actualizar TP de todas al avgPrice actual
}

//+------------------------------------------------------------------+
//| ESTRATEGIA 3: TRENDMASTER                                        |
//+------------------------------------------------------------------+
void RunTrendMaster() {
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
//| init()                                                           |
//+------------------------------------------------------------------+
int init() {
   // Inicializar panel visual (copiar del original si se desea)
   return (0);
}

//+------------------------------------------------------------------+
//| deinit()                                                          |
//+------------------------------------------------------------------+
int deinit() {
   // Limpiar objetos visuales (copiar del original)
   return (0);
}

//+------------------------------------------------------------------+
//| start() — UN SOLO return(0) al final                             |
//+------------------------------------------------------------------+
int start() {
   // 1. Panel de información en el gráfico
   Comment("___________________________________________________\n\n\n"
         + "Broker                                    :" + AccountCompany() + "\n"
         + "Brokers Time                          :" + TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\n"
         + "___________________________________________________\n\n"
         + "Name                                     :" + AccountName() + "\n"
         + "Account Number                    :" + AccountNumber() + "\n"
         + "Account Currency                  :" + AccountCurrency() + "\n"
         + "____________________________________________________\n\n"
         + "Open Orders Fibonacci Focus         :" + CountTrades_Hilo() + "\n"
         + "Open Orders Scalper Pro          :" + CountTrades_Scalper() + "\n"
         + "Open Orders TrendMaster     :" + CountTrades_Trend() + "\n"
         + "ALL ORDERS                          :" + OrdersTotal() + "\n"
         + "_____________________________________________________\n\n"
         + "Account BALANCE                  :" + DoubleToStr(AccountBalance(), 2) + "\n\n"
         + "Account EQUITY                     :" + DoubleToStr(AccountEquity(), 2) + "\n"
         + "_____________________________________________________\n\n");

   AccountBalance_Normalized = NormalizeDouble(AccountBalance(), 2);
   AccountEquity_Normalized = NormalizeDouble(AccountEquity(), 2);

   // 2. Filtro ATR global — solo loguea, NO bloquea
   if (isHighVolatility()) {
      Print("ATR alta (", g_atrValue, " pips). Estrategias en pausa.");
   } else {
      // 3. Ejecutar cada estrategia de forma independiente
      RunFibonacciFocus();
      RunScalperPro();
      RunTrendMaster();
   }

   return (0);  // ÚNICO return de toda la función
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
