#property description   "Potencia tu trading en AUDCAD con 3 estrategias avanzadas:"
#property description   " "
#property description   "1. Scalper Pro: Aprovecha los movimientos rápidos para maximizar cada micro-oportunidad en el mercado."
#property description   "2. Fibonacci Focus: Opera con precisión siguiendo los retrocesos clave basados en Fibonacci."
#property description   "3. TrendMaster: Sigue las tendencias dominantes y mantente en el flujo del mercado."
#property description   " "
#property description   "¡Domina el AUDCAD con estas tácticas especializadas!"

//+------------------------------------------------------------------+
//| PARÁMETROS GENERALES Y CONFIGURACIÓN                             |
//+------------------------------------------------------------------+
bool UseOnlineIndicator = false;
extern double GeneralStopLoss = 200;
extern double Lots = 0.01;
extern double LotExponent = 1.667;
extern int lotdecimal = 2;
extern double PipStep = 220.0;
extern double MaxLots = 9.0;
extern bool MM = TRUE;
extern double Risk = 1.0;                  // Porcentaje de Riesgo
extern double TakeProfit = 80.0;
extern bool UseEquityStop = FALSE;
extern double TotalEquityRisk = 20.0;
extern bool UseTrailingStop = FALSE;
extern double TrailStart = 13.0;
extern double TrailStop = 3.0;
extern double slip = 3.0;

// Configuración de Protección ATR
extern string ATRINFO = "=== PROTECCIÓN POR VOLATILIDAD ===";
extern double MaxAllowedATR = 150.0;       // Límite de volatilidad en pips (ATR)
extern int ATR_Period = 14;                // Período del ATR (velas)
extern int ATR_Timeframe = PERIOD_H1;      // Timeframe del ATR (por defecto: H1)

// Configuración para Fibonacci Focus (Hilo)
extern string ATURANFIBO = "SETTINGS For Fibonacci Focus: ";
extern int MaxTrades_Hilo = 20;
extern int MagicNumber_Hilo = 10278;

// Configuración para Scalper Pro
extern string ATURANAFSCALPER = "SETTINGS For Scalper Pro: ";
extern int MaxTrades_15 = 20;
extern int g_magic_176_15 = 22324;

// Configuración para TrendMaster
extern string ATURANTRENDKILLER = "SETTINGS For TrendMaster:";
extern int MaxTrades_16 = 20;
extern int g_magic_176_16 = 23794;
extern bool UseNewsFilter = TRUE;

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES DE TRABAJO (Estrategia 1: Fibonacci Focus)    |
//+------------------------------------------------------------------+
bool UseTimeOut_Hilo = FALSE;
double TimeOutHours_Hilo = 48.0;
double StopLossPips_Hilo = 40.0;
double Slippage_Hilo;
double TakeProfitPrice_Hilo;
double EquityAtStart_Hilo;
double AccountBalance_Normalized;
double AccountEquity_Normalized;
double AveragePrice_Hilo;
double Bid_Hilo;
double Ask_Hilo;
double LastBuyPrice_Hilo;
double LastSellPrice_Hilo;
double SpreadPoints_Hilo;
bool ModifyRequired_Hilo;
string StrategyComment_Hilo = "Fibonacci Focus/2019";
int LastBarTime_Hilo = -1;
int TimeLimit_Hilo;
int TradeCountForLot_Hilo = 0;
double NextLotSize_Hilo;
int OrderLoopPos_Hilo = 0;
int CurrentTrades_Hilo;
double StopLossPrice_Hilo = 0.0;
bool CanOpenNew_Hilo = FALSE;
bool HasBuyOrders_Hilo = FALSE;
bool HasSellOrders_Hilo = FALSE;
int Ticket_Hilo;
bool OrderSentFlag_Hilo = FALSE;
double EquityHigh_Hilo;
double EquityLast_Hilo;

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES DE TRABAJO (Estrategia 2: Scalper Pro)        |
//+------------------------------------------------------------------+
int Timeframe_Scalper = PERIOD_H1;
double StopLossPips_Scalper = 40.0;
bool UseTimeOut_Scalper = FALSE;
double TimeOutHours_Scalper = 48.0;
double Slippage_Scalper;
double TakeProfitPrice_Scalper;
double EquityAtStart_Scalper;
double AveragePrice_Scalper;
double Bid_Scalper;
double Ask_Scalper;
double LastBuyPrice_Scalper;
double LastSellPrice_Scalper;
double SpreadPoints_Scalper;
bool ModifyRequired_Scalper;
string StrategyComment_Scalper = "Scalper Pro/2019";
int LastBarTime_Scalper = 0;
int TimeLimit_Scalper;
int TradeCountForLot_Scalper = 0;
double NextLotSize_Scalper;
int OrderLoopPos_Scalper = 0;
int CurrentTrades_Scalper;
double StopLossPrice_Scalper = 0.0;
bool CanOpenNew_Scalper = FALSE;
bool HasBuyOrders_Scalper = FALSE;
bool HasSellOrders_Scalper = FALSE;
int Ticket_Scalper;
bool OrderSentFlag_Scalper = FALSE;
double EquityHigh_Scalper;
double EquityLast_Scalper;
int LastBarTime_ScalperTrigger = 1;

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES DE TRABAJO (Estrategia 3: TrendMaster)        |
//+------------------------------------------------------------------+
int Timeframe_Trend = PERIOD_H1;
double StopLossPips_Trend = 40.0;
bool UseTimeOut_Trend = FALSE;
double TimeOutHours_Trend = 48.0;
double Slippage_Trend;
double TakeProfitPrice_Trend;
double EquityAtStart_Trend;
double AveragePrice_Trend;
double Bid_Trend;
double Ask_Trend;
double LastBuyPrice_Trend;
double LastSellPrice_Trend;
double SpreadPoints_Trend;
bool ModifyRequired_Trend;
string StrategyComment_Trend = "TrendMaster/2019";
int LastBarTime_Trend = 0;
int TimeLimit_Trend;
int TradeCountForLot_Trend = 0;
double NextLotSize_Trend;
int OrderLoopPos_Trend = 0;
int CurrentTrades_Trend;
double StopLossPrice_Trend = 0.0;
bool CanOpenNew_Trend = FALSE;
bool HasBuyOrders_Trend = FALSE;
bool HasSellOrders_Trend = FALSE;
int Ticket_Trend;
bool OrderSentFlag_Trend = FALSE;
bool cg = FALSE;
double EquityHigh_Trend;
double EquityLast_Trend;
int LastBarTime_TrendTrigger = 1;

//+------------------------------------------------------------------+
//| PARÁMETROS E VARIABLES DE INDICADORES VISUALES (PANEL)           |
//+------------------------------------------------------------------+
int g_timeframe_828 = PERIOD_M1;
int g_timeframe_832 = PERIOD_M5;
int g_timeframe_836 = PERIOD_M15;
int g_timeframe_840 = PERIOD_M30;
int g_timeframe_844 = PERIOD_H1;
int g_timeframe_848 = PERIOD_H4;
int g_timeframe_852 = PERIOD_D1;
bool g_corner_856 = TRUE;
int gi_860 = 0;
int gi_864 = 10;
int g_window_868 = 0;
bool gi_872 = TRUE;
bool gi_880 = FALSE;
int g_color_884 = Gray;
int g_color_888 = Gray;
int g_color_892 = Gray;
int g_color_896 = DarkOrange;
int g_color_904 = Lime;
int g_color_908 = OrangeRed;
int gi_912 = 65280;
int gi_916 = 17919;
int g_color_920 = Lime;
int g_color_924 = Red;
int g_color_928 = Orange;
int g_period_932 = 8;
int g_period_936 = 17;
int g_period_940 = 9;
int g_applied_price_944 = PRICE_CLOSE;
int g_color_948 = Lime;
int g_color_952 = Tomato;
int g_color_956 = Green;
int g_color_960 = Red;
int g_period_980 = 9;
int g_applied_price_984 = PRICE_CLOSE;
int g_period_996 = 13;
int g_applied_price_1000 = PRICE_CLOSE;
int g_period_1012 = 5;
int g_period_1016 = 3;
int g_slowing_1020 = 3;
int g_ma_method_1024 = MODE_EMA;
int g_color_1036 = Lime;
int g_color_1040 = Red;
int g_color_1044 = Orange;
int g_period_1056 = 5;
int g_period_1060 = 9;
int g_ma_method_1064 = MODE_EMA;
int g_applied_price_1068 = PRICE_CLOSE;
int g_color_1080 = Lime;
int g_color_1084 = Red;
string g_text_1096;
string g_text_1104;
string g_dbl2str_1112 = "";
string g_dbl2str_1120 = "";
int g_color_1128 = ForestGreen;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
   SpreadPoints_Hilo = MarketInfo(Symbol(), MODE_SPREAD) * Point;
   SpreadPoints_Scalper = MarketInfo(Symbol(), MODE_SPREAD) * Point;
   SpreadPoints_Trend = MarketInfo(Symbol(), MODE_SPREAD) * Point;
   
   // Crear etiquetas de marca/web
   ObjectCreate("Lable1", OBJ_LABEL, 0, 0, 1.0);
   ObjectSet("Lable1", OBJPROP_CORNER, 2);
   ObjectSet("Lable1", OBJPROP_XDISTANCE, 25);
   ObjectSet("Lable1", OBJPROP_YDISTANCE, 25);
   g_text_1104 = "THE ALGORITHM";
   ObjectSetText("Lable1", g_text_1104, 12, "Times New Roman", Aqua);
   
   ObjectCreate("Lable", OBJ_LABEL, 0, 0, 1.0);
   ObjectSet("Lable", OBJPROP_CORNER, 2);
   ObjectSet("Lable", OBJPROP_XDISTANCE, 3);
   ObjectSet("Lable", OBJPROP_YDISTANCE, 1);
   g_text_1096 = " https://thealgorithmco.com ";
   ObjectSetText("Lable", g_text_1096, 11, "Times New Roman", DeepSkyBlue);
   
   return (0);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit() {
   // Eliminar todos los objetos visuales creados
   ObjectDelete("cja");
   ObjectDelete("Signalprice");
   ObjectDelete("SIG_BARS_TF1");
   ObjectDelete("SIG_BARS_TF2");
   ObjectDelete("SIG_BARS_TF3");
   ObjectDelete("SIG_BARS_TF4");
   ObjectDelete("SIG_BARS_TF5");
   ObjectDelete("SIG_BARS_TF6");
   ObjectDelete("SIG_BARS_TF7");
   ObjectDelete("SSignalMACD_TEXT");
   ObjectDelete("SSignalMACDM1");
   ObjectDelete("SSignalMACDM5");
   ObjectDelete("SSignalMACDM15");
   ObjectDelete("SSignalMACDM30");
   ObjectDelete("SSignalMACDH1");
   ObjectDelete("SSignalMACDH4");
   ObjectDelete("SSignalMACDD1");
   ObjectDelete("SSignalSTR_TEXT");
   ObjectDelete("SignalSTRM1");
   ObjectDelete("SignalSTRM5");
   ObjectDelete("SignalSTRM15");
   ObjectDelete("SignalSTRM30");
   ObjectDelete("SignalSTRH1");
   ObjectDelete("SignalSTRH4");
   ObjectDelete("SignalSTRD1");
   ObjectDelete("SignalEMA_TEXT");
   ObjectDelete("SignalEMAM1");
   ObjectDelete("SignalEMAM5");
   ObjectDelete("SignalEMAM15");
   ObjectDelete("SignalEMAM30");
   ObjectDelete("SignalEMAH1");
   ObjectDelete("SignalEMAH4");
   ObjectDelete("SignalEMAD1");
   ObjectDelete("SIG_DETAIL_1");
   ObjectDelete("SIG_DETAIL_2");
   ObjectDelete("SIG_DETAIL_3");
   ObjectDelete("SIG_DETAIL_4");
   ObjectDelete("SIG_DETAIL_5");
   ObjectDelete("SIG_DETAIL_6");
   ObjectDelete("SIG_DETAIL_7");
   ObjectDelete("SIG_DETAIL_8");
   ObjectDelete("Lable");
   ObjectDelete("Lable1");
   ObjectDelete("Lable2");
   ObjectDelete("Lable3");
   Comment("https://thealgorithmco.com");
   return (0);
}

//+------------------------------------------------------------------+
//| Expert start function                                            |
//+------------------------------------------------------------------+
int start() {
   HideTestIndicators(TRUE);
   
   // Variables locales de control
   int tf1_offset = 0;
   int tf2_offset = 0;
   int tf3_offset = 0;
   int tf4_offset = 0;
   int tf5_offset = 0;
   int tf6_offset = 0;
   int tf7_offset = 0;
   
   color color_macd_d1;
   color color_macd_h4;
   color color_macd_h1;
   color color_macd_m30;
   color color_macd_m15;
   color color_macd_m5;
   color color_macd_m1;
   
   color color_str_d1;
   color color_str_h4;
   color color_str_h1;
   color color_str_m30;
   color color_str_m15;
   color color_str_m5;
   color color_str_m1;
   
   color color_price_trend;
   
   double ihigh_d1_1;
   double ilow_d1_2;
   double iclose_scalper_2;
   double iclose_scalper_1;
   
   double lotSize_Hilo;
   double lotSize_Scalper;
   double lotSize_Trend;
   
   double profit_Hilo;
   double profit_Scalper;
   double profit_Trend;
   
   if (Lots > MaxLots) Lots = MaxLots;
   
   // Actualizar el comentario del gráfico
   Comment("\n\nTHE ALGORITHM\n\n\n"
         + "___________________________________________________\n\n"
         + "Broker                                    :" + AccountCompany() + "\n\n"
         + "Brokers Time                          :" + TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\n\n"
         + "___________________________________________________\n\n"
         + "Name                                     :" + AccountName() + "\n\n"
         + "Account Number                    :" + AccountNumber() + "\n\n"
         + "Account Currency                  :" + AccountCurrency() + "\n\n"
         + "____________________________________________________\n\n"
         + "Open Orders Fibonacci Focus         :" + CountTrades_Hilo() + "\n\n"
         + "Open Orders Scalper Pro          :" + CountTrades_15() + "\n\n"
         + "Open Orders TrendMaster     :" + CountTrades_16() + "\n\n"
         + "ALL ORDERS                          :" + OrdersTotal() + "\n\n"
         + "_____________________________________________________\n\n"
         + "Account BALANCE                  :" + DoubleToStr(AccountBalance(), 2) + "\n\n"
         + "Account EQUITY                     :" + DoubleToStr(AccountEquity(), 2) + "\n\n\n"
         + "THE ALGORITHM");
         
   AccountBalance_Normalized = NormalizeDouble(AccountBalance(), 2);
   AccountEquity_Normalized = NormalizeDouble(AccountEquity(), 2);
   
   // Determinar color de equidad basado en estado de salud de la cuenta
   if (AccountEquity_Normalized >= 5.0 * (AccountBalance_Normalized / 6.0)) g_color_1128 = DodgerBlue;
   if (AccountEquity_Normalized >= 4.0 * (AccountBalance_Normalized / 6.0) && AccountEquity_Normalized < 5.0 * (AccountBalance_Normalized / 6.0)) g_color_1128 = DeepSkyBlue;
   if (AccountEquity_Normalized >= 3.0 * (AccountBalance_Normalized / 6.0) && AccountEquity_Normalized < 4.0 * (AccountBalance_Normalized / 6.0)) g_color_1128 = Gold;
   if (AccountEquity_Normalized >= 2.0 * (AccountBalance_Normalized / 6.0) && AccountEquity_Normalized < 3.0 * (AccountBalance_Normalized / 6.0)) g_color_1128 = OrangeRed;
   if (AccountEquity_Normalized >= AccountBalance_Normalized / 6.0 && AccountEquity_Normalized < 2.0 * (AccountBalance_Normalized / 6.0)) g_color_1128 = Crimson;
   if (AccountEquity_Normalized < AccountBalance_Normalized / 5.0) g_color_1128 = Red;
   
   ObjectDelete("Lable2");
   ObjectCreate("Lable2", OBJ_LABEL, 0, 0, 1.0);
   ObjectSet("Lable2", OBJPROP_CORNER, 3);
   ObjectSet("Lable2", OBJPROP_XDISTANCE, 153);
   ObjectSet("Lable2", OBJPROP_YDISTANCE, 41);
   g_dbl2str_1112 = DoubleToStr(AccountBalance(), 2);
   ObjectSetText("Lable2", "Account BALANCE:  " + g_dbl2str_1112, 10, "Times New Roman", DodgerBlue);
   
   ObjectDelete("Lable3");
   ObjectCreate("Lable3", OBJ_LABEL, 0, 0, 1.0);
   ObjectSet("Lable3", OBJPROP_CORNER, 3);
   ObjectSet("Lable3", OBJPROP_XDISTANCE, 153);
   ObjectSet("Lable3", OBJPROP_YDISTANCE, 11);
   g_dbl2str_1120 = DoubleToStr(AccountEquity(), 2);
   ObjectSetText("Lable3", "Account EQUITY:  " + g_dbl2str_1120, 10, "Times New Roman", g_color_1128);
   
   // Dibujar el panel indicador de Timeframes (M1 a D1)
   string text_tf1 = "";
   string text_tf2 = "";
   string text_tf3 = "";
   string text_tf4 = "";
   string text_tf5 = "";
   string text_tf6 = "";
   string text_tf7 = "";
   
   if (g_timeframe_828 == PERIOD_M1) text_tf1 = "M1";
   if (g_timeframe_828 == PERIOD_M5) text_tf1 = "M5";
   if (g_timeframe_828 == PERIOD_M15) text_tf1 = "M15";
   if (g_timeframe_828 == PERIOD_M30) text_tf1 = "M30";
   if (g_timeframe_828 == PERIOD_H1) text_tf1 = "H1";
   if (g_timeframe_828 == PERIOD_H4) text_tf1 = "H4";
   if (g_timeframe_828 == PERIOD_D1) text_tf1 = "D1";
   if (g_timeframe_828 == PERIOD_W1) text_tf1 = "W1";
   if (g_timeframe_828 == PERIOD_MN1) text_tf1 = "MN";
   
   if (g_timeframe_832 == PERIOD_M1) text_tf2 = "M1";
   if (g_timeframe_832 == PERIOD_M5) text_tf2 = "M5";
   if (g_timeframe_832 == PERIOD_M15) text_tf2 = "M15";
   if (g_timeframe_832 == PERIOD_M30) text_tf2 = "M30";
   if (g_timeframe_832 == PERIOD_H1) text_tf2 = "H1";
   if (g_timeframe_832 == PERIOD_H4) text_tf2 = "H4";
   if (g_timeframe_832 == PERIOD_D1) text_tf2 = "D1";
   if (g_timeframe_832 == PERIOD_W1) text_tf2 = "W1";
   if (g_timeframe_832 == PERIOD_MN1) text_tf2 = "MN";
   
   if (g_timeframe_836 == PERIOD_M1) text_tf3 = "M1";
   if (g_timeframe_836 == PERIOD_M5) text_tf3 = "M5";
   if (g_timeframe_836 == PERIOD_M15) text_tf3 = "M15";
   if (g_timeframe_836 == PERIOD_M30) text_tf3 = "M30";
   if (g_timeframe_836 == PERIOD_H1) text_tf3 = "H1";
   if (g_timeframe_836 == PERIOD_H4) text_tf3 = "H4";
   if (g_timeframe_836 == PERIOD_D1) text_tf3 = "D1";
   if (g_timeframe_836 == PERIOD_W1) text_tf3 = "W1";
   if (g_timeframe_836 == PERIOD_MN1) text_tf3 = "MN";
   
   if (g_timeframe_840 == PERIOD_M1) text_tf4 = "M1";
   if (g_timeframe_840 == PERIOD_M5) text_tf4 = "M5";
   if (g_timeframe_840 == PERIOD_M15) text_tf4 = "M15";
   if (g_timeframe_840 == PERIOD_M30) text_tf4 = "M30";
   if (g_timeframe_840 == PERIOD_H1) text_tf4 = "H1";
   if (g_timeframe_840 == PERIOD_H4) text_tf4 = "H4";
   if (g_timeframe_840 == PERIOD_D1) text_tf4 = "D1";
   if (g_timeframe_840 == PERIOD_W1) text_tf4 = "W1";
   if (g_timeframe_840 == PERIOD_MN1) text_tf4 = "MN";
   
   if (g_timeframe_844 == PERIOD_M1) text_tf5 = "M1";
   if (g_timeframe_844 == PERIOD_M5) text_tf5 = "M5";
   if (g_timeframe_844 == PERIOD_M15) text_tf5 = "M15";
   if (g_timeframe_844 == PERIOD_M30) text_tf5 = "M30";
   if (g_timeframe_844 == PERIOD_H1) text_tf5 = "H1";
   if (g_timeframe_844 == PERIOD_H4) text_tf5 = "H4";
   if (g_timeframe_844 == PERIOD_D1) text_tf5 = "D1";
   if (g_timeframe_844 == PERIOD_W1) text_tf5 = "W1";
   if (g_timeframe_844 == PERIOD_MN1) text_tf5 = "MN";
   
   if (g_timeframe_848 == PERIOD_M1) text_tf6 = "M1";
   if (g_timeframe_848 == PERIOD_M5) text_tf6 = "M5";
   if (g_timeframe_848 == PERIOD_M15) text_tf6 = "M15";
   if (g_timeframe_848 == PERIOD_M30) text_tf6 = "M30";
   if (g_timeframe_848 == PERIOD_H1) text_tf6 = "H1";
   if (g_timeframe_848 == PERIOD_H4) text_tf6 = "H4";
   if (g_timeframe_848 == PERIOD_D1) text_tf6 = "D1";
   if (g_timeframe_848 == PERIOD_W1) text_tf6 = "W1";
   if (g_timeframe_848 == PERIOD_MN1) text_tf6 = "MN";
   
   if (g_timeframe_852 == PERIOD_M1) text_tf7 = "M1";
   if (g_timeframe_852 == PERIOD_M5) text_tf7 = "M5";
   if (g_timeframe_852 == PERIOD_M15) text_tf7 = "M15";
   if (g_timeframe_852 == PERIOD_M30) text_tf7 = "M30";
   if (g_timeframe_852 == PERIOD_H1) text_tf7 = "H1";
   if (g_timeframe_852 == PERIOD_H4) text_tf7 = "H4";
   if (g_timeframe_852 == PERIOD_D1) text_tf7 = "D1";
   if (g_timeframe_852 == PERIOD_W1) text_tf7 = "W1";
   if (g_timeframe_852 == PERIOD_MN1) text_tf7 = "MN";
   
   // Ajuste de coordenadas del panel
   if (g_timeframe_828 == PERIOD_M15 || g_timeframe_828 == PERIOD_M30) tf1_offset = -2;
   if (g_timeframe_832 == PERIOD_M15 || g_timeframe_832 == PERIOD_M30) tf2_offset = -2;
   if (g_timeframe_836 == PERIOD_M15 || g_timeframe_836 == PERIOD_M30) tf3_offset = -2;
   if (g_timeframe_840 == PERIOD_M15 || g_timeframe_840 == PERIOD_M30) tf4_offset = -2;
   if (g_timeframe_844 == PERIOD_M15 || g_timeframe_844 == PERIOD_M30) tf5_offset = -2;
   if (g_timeframe_848 == PERIOD_M15 || g_timeframe_848 == PERIOD_M30) tf6_offset = -2;
   if (g_timeframe_852 == PERIOD_M15) tf7_offset = -2;
   if (g_timeframe_848 == PERIOD_M30) tf7_offset = -2;
   
   if (gi_860 < 0) return (0);
   
   // Dibujar nombres de timeframes en el gráfico
   ObjectDelete("SIG_BARS_TF1");
   ObjectCreate("SIG_BARS_TF1", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SIG_BARS_TF1", text_tf1, 7, "Arial Bold", g_color_884);
   ObjectSet("SIG_BARS_TF1", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SIG_BARS_TF1", OBJPROP_XDISTANCE, gi_864 + 265 + tf1_offset);
   ObjectSet("SIG_BARS_TF1", OBJPROP_YDISTANCE, gi_860 + 25);
   
   ObjectDelete("SIG_BARS_TF2");
   ObjectCreate("SIG_BARS_TF2", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SIG_BARS_TF2", text_tf2, 7, "Arial Bold", g_color_884);
   ObjectSet("SIG_BARS_TF2", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SIG_BARS_TF2", OBJPROP_XDISTANCE, gi_864 + 230 + tf2_offset);
   ObjectSet("SIG_BARS_TF2", OBJPROP_YDISTANCE, gi_860 + 25);
   
   ObjectDelete("SIG_BARS_TF3");
   ObjectCreate("SIG_BARS_TF3", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SIG_BARS_TF3", text_tf3, 7, "Arial Bold", g_color_884);
   ObjectSet("SIG_BARS_TF3", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SIG_BARS_TF3", OBJPROP_XDISTANCE, gi_864 + 190 + tf3_offset);
   ObjectSet("SIG_BARS_TF3", OBJPROP_YDISTANCE, gi_860 + 25);
   
   ObjectDelete("SIG_BARS_TF4");
   ObjectCreate("SIG_BARS_TF4", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SIG_BARS_TF4", text_tf4, 7, "Arial Bold", g_color_884);
   ObjectSet("SIG_BARS_TF4", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SIG_BARS_TF4", OBJPROP_XDISTANCE, gi_864 + 140 + tf4_offset);
   ObjectSet("SIG_BARS_TF4", OBJPROP_YDISTANCE, gi_860 + 25);
   
   ObjectDelete("SIG_BARS_TF5");
   ObjectCreate("SIG_BARS_TF5", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SIG_BARS_TF5", text_tf5, 7, "Arial Bold", g_color_884);
   ObjectSet("SIG_BARS_TF5", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SIG_BARS_TF5", OBJPROP_XDISTANCE, gi_864 + 94 + tf5_offset);
   ObjectSet("SIG_BARS_TF5", OBJPROP_YDISTANCE, gi_860 + 25);
   
   ObjectDelete("SIG_BARS_TF6");
   ObjectCreate("SIG_BARS_TF6", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SIG_BARS_TF6", text_tf6, 7, "Arial Bold", g_color_884);
   ObjectSet("SIG_BARS_TF6", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SIG_BARS_TF6", OBJPROP_XDISTANCE, gi_864 + 54 + tf6_offset);
   ObjectSet("SIG_BARS_TF6", OBJPROP_YDISTANCE, gi_860 + 25);
   
   ObjectDelete("SIG_BARS_TF7");
   ObjectCreate("SIG_BARS_TF7", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SIG_BARS_TF7", text_tf7, 7, "Arial Bold", g_color_884);
   ObjectSet("SIG_BARS_TF7", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SIG_BARS_TF7", OBJPROP_XDISTANCE, gi_864 + 14 + tf7_offset);
   ObjectSet("SIG_BARS_TF7", OBJPROP_YDISTANCE, gi_860 + 25);
   
   // Lógica de cálculo e indicación visual de MACD
   double imacd_m1_main = iMACD(NULL, g_timeframe_828, g_period_932, g_period_936, g_period_940, g_applied_price_944, MODE_MAIN, 0);
   double imacd_m1_sig  = iMACD(NULL, g_timeframe_828, g_period_932, g_period_936, g_period_940, g_applied_price_944, MODE_SIGNAL, 0);
   double imacd_m5_main = iMACD(NULL, g_timeframe_832, g_period_932, g_period_936, g_period_940, g_applied_price_944, MODE_MAIN, 0);
   double imacd_m5_sig  = iMACD(NULL, g_timeframe_832, g_period_932, g_period_936, g_period_940, g_applied_price_944, MODE_SIGNAL, 0);
   double imacd_m15_main = iMACD(NULL, g_timeframe_836, g_period_932, g_period_936, g_period_940, g_applied_price_944, MODE_MAIN, 0);
   double imacd_m15_sig  = iMACD(NULL, g_timeframe_836, g_period_932, g_period_936, g_period_940, g_applied_price_944, MODE_SIGNAL, 0);
   double imacd_m30_main = iMACD(NULL, g_timeframe_840, g_period_932, g_period_936, g_period_940, g_applied_price_944, MODE_MAIN, 0);
   double imacd_m30_sig  = iMACD(NULL, g_timeframe_840, g_period_932, g_period_936, g_period_940, g_applied_price_944, MODE_SIGNAL, 0);
   double imacd_h1_main = iMACD(NULL, g_timeframe_844, g_period_932, g_period_936, g_period_940, g_applied_price_944, MODE_MAIN, 0);
   double imacd_h1_sig  = iMACD(NULL, g_timeframe_844, g_period_932, g_period_936, g_period_940, g_applied_price_944, MODE_SIGNAL, 0);
   double imacd_h4_main = iMACD(NULL, g_timeframe_848, g_period_932, g_period_936, g_period_940, g_applied_price_944, MODE_MAIN, 0);
   double imacd_h4_sig  = iMACD(NULL, g_timeframe_848, g_period_932, g_period_936, g_period_940, g_applied_price_944, MODE_SIGNAL, 0);
   double imacd_d1_main = iMACD(NULL, g_timeframe_852, g_period_932, g_period_936, g_period_940, g_applied_price_944, MODE_MAIN, 0);
   double imacd_d1_sig  = iMACD(NULL, g_timeframe_852, g_period_932, g_period_936, g_period_940, g_applied_price_944, MODE_SIGNAL, 0);
   
   if (imacd_m1_main > imacd_m1_sig) { color_macd_m1 = g_color_956; }
   else { color_macd_m1 = g_color_952; }
   if (imacd_m1_main > imacd_m1_sig && imacd_m1_main > 0.0) { color_macd_m1 = g_color_948; }
   if (imacd_m1_main <= imacd_m1_sig && imacd_m1_main < 0.0) { color_macd_m1 = g_color_960; }
   
   if (imacd_m5_main > imacd_m5_sig) { color_macd_m5 = g_color_956; }
   else { color_macd_m5 = g_color_952; }
   if (imacd_m5_main > imacd_m5_sig && imacd_m5_main > 0.0) { color_macd_m5 = g_color_948; }
   if (imacd_m5_main <= imacd_m5_sig && imacd_m5_main < 0.0) { color_macd_m5 = g_color_960; }
   
   if (imacd_m15_main > imacd_m15_sig) { color_macd_m15 = g_color_956; }
   else { color_macd_m15 = g_color_952; }
   if (imacd_m15_main > imacd_m15_sig && imacd_m15_main > 0.0) { color_macd_m15 = g_color_948; }
   if (imacd_m15_main <= imacd_m15_sig && imacd_m15_main < 0.0) { color_macd_m15 = g_color_960; }
   
   if (imacd_m30_main > imacd_m30_sig) { color_macd_m30 = g_color_956; }
   else { color_macd_m30 = g_color_952; }
   if (imacd_m30_main > imacd_m30_sig && imacd_m30_main > 0.0) { color_macd_m30 = g_color_948; }
   if (imacd_m30_main <= imacd_m30_sig && imacd_m30_main < 0.0) { color_macd_m30 = g_color_960; }
   
   if (imacd_h1_main > imacd_h1_sig) { color_macd_h1 = g_color_956; }
   else { color_macd_h1 = g_color_952; }
   if (imacd_h1_main > imacd_h1_sig && imacd_h1_main > 0.0) { color_macd_h1 = g_color_948; }
   if (imacd_h1_main <= imacd_h1_sig && imacd_h1_main < 0.0) { color_macd_h1 = g_color_960; }
   
   if (imacd_h4_main > imacd_h4_sig) { color_macd_h4 = g_color_956; }
   else { color_macd_h4 = g_color_952; }
   if (imacd_h4_main > imacd_h4_sig && imacd_h4_main > 0.0) { color_macd_h4 = g_color_948; }
   if (imacd_h4_main <= imacd_h4_sig && imacd_h4_main < 0.0) { color_macd_h4 = g_color_960; }
   
   if (imacd_d1_main > imacd_d1_sig) { color_macd_d1 = g_color_956; }
   else { color_macd_d1 = g_color_952; }
   if (imacd_d1_main > imacd_d1_sig && imacd_d1_main > 0.0) { color_macd_d1 = g_color_948; }
   if (imacd_d1_main <= imacd_d1_sig && imacd_d1_main < 0.0) { color_macd_d1 = g_color_960; }
   
   // Dibujar indicadores de MACD en el panel
   ObjectDelete("SSignalMACD_TEXT");
   ObjectCreate("SSignalMACD_TEXT", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SSignalMACD_TEXT", "MACD", 6, "Tahoma Narrow", g_color_888);
   ObjectSet("SSignalMACD_TEXT", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SSignalMACD_TEXT", OBJPROP_XDISTANCE, gi_864 + 300);
   ObjectSet("SSignalMACD_TEXT", OBJPROP_YDISTANCE, gi_860 + 80);
   
   ObjectDelete("SSignalMACDM1");
   ObjectCreate("SSignalMACDM1", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SSignalMACDM1", "-", 45, "Tahoma Narrow", color_macd_m1);
   ObjectSet("SSignalMACDM1", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SSignalMACDM1", OBJPROP_XDISTANCE, gi_864 + 250);
   ObjectSet("SSignalMACDM1", OBJPROP_YDISTANCE, gi_860 + 0);
   
   ObjectDelete("SSignalMACDM5");
   ObjectCreate("SSignalMACDM5", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SSignalMACDM5", "-", 45, "Tahoma Narrow", color_macd_m5);
   ObjectSet("SSignalMACDM5", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SSignalMACDM5", OBJPROP_XDISTANCE, gi_864 + 210);
   ObjectSet("SSignalMACDM5", OBJPROP_YDISTANCE, gi_860 + 0);
   
   ObjectDelete("SSignalMACDM15");
   ObjectCreate("SSignalMACDM15", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SSignalMACDM15", "-", 45, "Tahoma Narrow", color_macd_m15);
   ObjectSet("SSignalMACDM15", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SSignalMACDM15", OBJPROP_XDISTANCE, gi_864 + 170);
   ObjectSet("SSignalMACDM15", OBJPROP_YDISTANCE, gi_860 + 0);
   
   ObjectDelete("SSignalMACDM30");
   ObjectCreate("SSignalMACDM30", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SSignalMACDM30", "-", 45, "Tahoma Narrow", color_macd_m30);
   ObjectSet("SSignalMACDM30", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SSignalMACDM30", OBJPROP_XDISTANCE, gi_864 + 130);
   ObjectSet("SSignalMACDM30", OBJPROP_YDISTANCE, gi_860 + 0);
   
   ObjectDelete("SSignalMACDH1");
   ObjectCreate("SSignalMACDH1", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SSignalMACDH1", "-", 45, "Tahoma Narrow", color_macd_h1);
   ObjectSet("SSignalMACDH1", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SSignalMACDH1", OBJPROP_XDISTANCE, gi_864 + 90);
   ObjectSet("SSignalMACDH1", OBJPROP_YDISTANCE, gi_860 + 0);
   
   ObjectDelete("SSignalMACDH4");
   ObjectCreate("SSignalMACDH4", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SSignalMACDH4", "-", 45, "Tahoma Narrow", color_macd_h4);
   ObjectSet("SSignalMACDH4", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SSignalMACDH4", OBJPROP_XDISTANCE, gi_864 + 50);
   ObjectSet("SSignalMACDH4", OBJPROP_YDISTANCE, gi_860 + 0);
   
   ObjectDelete("SSignalMACDD1");
   ObjectCreate("SSignalMACDD1", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SSignalMACDD1", "-", 45, "Tahoma Narrow", color_macd_d1);
   ObjectSet("SSignalMACDD1", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SSignalMACDD1", OBJPROP_XDISTANCE, gi_864 + 10);
   ObjectSet("SSignalMACDD1", OBJPROP_YDISTANCE, gi_860 + 0);
   
   // Lógica de cálculo de Filtro STR (RSI, Stochastic y CCI combinados)
   double irsi_d1 = iRSI(NULL, g_timeframe_852, g_period_980, g_applied_price_984, 0);
   double irsi_h4 = iRSI(NULL, g_timeframe_848, g_period_980, g_applied_price_984, 0);
   double irsi_h1 = iRSI(NULL, g_timeframe_844, g_period_980, g_applied_price_984, 0);
   double irsi_m30 = iRSI(NULL, g_timeframe_840, g_period_980, g_applied_price_984, 0);
   double irsi_m15 = iRSI(NULL, g_timeframe_836, g_period_980, g_applied_price_984, 0);
   double irsi_m5 = iRSI(NULL, g_timeframe_832, g_period_980, g_applied_price_984, 0);
   double irsi_m1 = iRSI(NULL, g_timeframe_828, g_period_980, g_applied_price_984, 0);
   
   double istoch_d1 = iStochastic(NULL, g_timeframe_852, g_period_1012, g_period_1016, g_slowing_1020, g_ma_method_1024, 0, MODE_MAIN, 0);
   double istoch_h4 = iStochastic(NULL, g_timeframe_848, g_period_1012, g_period_1016, g_slowing_1020, g_ma_method_1024, 0, MODE_MAIN, 0);
   double istoch_h1 = iStochastic(NULL, g_timeframe_844, g_period_1012, g_period_1016, g_slowing_1020, g_ma_method_1024, 0, MODE_MAIN, 0);
   double istoch_m30 = iStochastic(NULL, g_timeframe_840, g_period_1012, g_period_1016, g_slowing_1020, g_ma_method_1024, 0, MODE_MAIN, 0);
   double istoch_m15 = iStochastic(NULL, g_timeframe_836, g_period_1012, g_period_1016, g_slowing_1020, g_ma_method_1024, 0, MODE_MAIN, 0);
   double istoch_m5 = iStochastic(NULL, g_timeframe_832, g_period_1012, g_period_1016, g_slowing_1020, g_ma_method_1024, 0, MODE_MAIN, 0);
   double istoch_m1 = iStochastic(NULL, g_timeframe_828, g_period_1012, g_period_1016, g_slowing_1020, g_ma_method_1024, 0, MODE_MAIN, 0);
   
   double icci_d1 = iCCI(NULL, g_timeframe_852, g_period_996, g_applied_price_1000, 0);
   double icci_h4 = iCCI(NULL, g_timeframe_848, g_period_996, g_applied_price_1000, 0);
   double icci_h1 = iCCI(NULL, g_timeframe_844, g_period_996, g_applied_price_1000, 0);
   double icci_m30 = iCCI(NULL, g_timeframe_840, g_period_996, g_applied_price_1000, 0);
   double icci_m15 = iCCI(NULL, g_timeframe_836, g_period_996, g_applied_price_1000, 0);
   double icci_m5 = iCCI(NULL, g_timeframe_832, g_period_996, g_applied_price_1000, 0);
   double icci_m1 = iCCI(NULL, g_timeframe_828, g_period_996, g_applied_price_1000, 0);
   
   color_str_d1 = g_color_1044;
   color_str_h4 = g_color_1044;
   color_str_h1 = g_color_1044;
   color_str_m30 = g_color_1044;
   color_str_m15 = g_color_1044;
   color_str_m5 = g_color_1044;
   color_str_m1 = g_color_1044;
   
   // Determinar señales alcistas del filtro STR
   if (irsi_d1 > 50.0 && istoch_d1 > 40.0 && icci_d1 > 0.0) { color_str_d1 = g_color_1036; }
   if (irsi_h4 > 50.0 && istoch_h4 > 40.0 && icci_h4 > 0.0) { color_str_h4 = g_color_1036; }
   if (irsi_h1 > 50.0 && istoch_h1 > 40.0 && icci_h1 > 0.0) { color_str_h1 = g_color_1036; }
   if (irsi_m30 > 50.0 && istoch_m30 > 40.0 && icci_m30 > 0.0) { color_str_m30 = g_color_1036; }
   if (irsi_m15 > 50.0 && istoch_m15 > 40.0 && icci_m15 > 0.0) { color_str_m15 = g_color_1036; }
   if (irsi_m5 > 50.0 && istoch_m5 > 40.0 && icci_m5 > 0.0) { color_str_m5 = g_color_1036; }
   if (irsi_m1 > 50.0 && istoch_m1 > 40.0 && icci_m1 > 0.0) { color_str_m1 = g_color_1036; }
   
   // Determinar señales bajistas del filtro STR
   if (irsi_d1 < 50.0 && istoch_d1 < 60.0 && icci_d1 < 0.0) { color_str_d1 = g_color_1040; }
   if (irsi_h4 < 50.0 && istoch_h4 < 60.0 && icci_h4 < 0.0) { color_str_h4 = g_color_1040; }
   if (irsi_h1 < 50.0 && istoch_h1 < 60.0 && icci_h1 < 0.0) { color_str_h1 = g_color_1040; }
   if (irsi_m30 < 50.0 && istoch_m30 < 60.0 && icci_m30 < 0.0) { color_str_m30 = g_color_1040; }
   if (irsi_m15 < 50.0 && istoch_m15 < 60.0 && icci_m15 < 0.0) { color_str_m15 = g_color_1040; }
   if (irsi_m5 < 50.0 && istoch_m5 < 60.0 && icci_m5 < 0.0) { color_str_m5 = g_color_1040; }
   if (irsi_m1 < 50.0 && istoch_m1 < 60.0 && icci_m1 < 0.0) { color_str_m1 = g_color_1040; }
   
   // Dibujar indicadores STR en el panel gráfico
   ObjectDelete("SSignalSTR_TEXT");
   ObjectCreate("SSignalSTR_TEXT", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SSignalSTR_TEXT", "STR", 6, "Tahoma Narrow", g_color_888);
   ObjectSet("SSignalSTR_TEXT", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SSignalSTR_TEXT", OBJPROP_XDISTANCE, gi_864 + 300);
   ObjectSet("SSignalSTR_TEXT", OBJPROP_YDISTANCE, gi_860 + 115);
   
   ObjectDelete("SignalSTRM1");
   ObjectCreate("SignalSTRM1", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SignalSTRM1", "-", 45, "Tahoma Narrow", color_str_m1);
   ObjectSet("SignalSTRM1", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SignalSTRM1", OBJPROP_XDISTANCE, gi_864 + 250);
   ObjectSet("SignalSTRM1", OBJPROP_YDISTANCE, gi_860 + 30);
   
   ObjectDelete("SignalSTRM5");
   ObjectCreate("SignalSTRM5", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SignalSTRM5", "-", 45, "Tahoma Narrow", color_str_m5);
   ObjectSet("SignalSTRM5", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SignalSTRM5", OBJPROP_XDISTANCE, gi_864 + 210);
   ObjectSet("SignalSTRM5", OBJPROP_YDISTANCE, gi_860 + 30);
   
   ObjectDelete("SignalSTRM15");
   ObjectCreate("SignalSTRM15", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SignalSTRM15", "-", 45, "Tahoma Narrow", color_str_m15);
   ObjectSet("SignalSTRM15", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SignalSTRM15", OBJPROP_XDISTANCE, gi_864 + 170);
   ObjectSet("SignalSTRM15", OBJPROP_YDISTANCE, gi_860 + 30);
   
   ObjectDelete("SignalSTRM30");
   ObjectCreate("SignalSTRM30", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SignalSTRM30", "-", 45, "Tahoma Narrow", color_str_m30);
   ObjectSet("SignalSTRM30", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SignalSTRM30", OBJPROP_XDISTANCE, gi_864 + 130);
   ObjectSet("SignalSTRM30", OBJPROP_YDISTANCE, gi_860 + 30);
   
   ObjectDelete("SignalSTRH1");
   ObjectCreate("SignalSTRH1", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SignalSTRH1", "-", 45, "Tahoma Narrow", color_str_h1);
   ObjectSet("SignalSTRH1", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SignalSTRH1", OBJPROP_XDISTANCE, gi_864 + 90);
   ObjectSet("SignalSTRH1", OBJPROP_YDISTANCE, gi_860 + 30);
   
   ObjectDelete("SignalSTRH4");
   ObjectCreate("SignalSTRH4", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SignalSTRH4", "-", 45, "Tahoma Narrow", color_str_h4);
   ObjectSet("SignalSTRH4", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SignalSTRH4", OBJPROP_XDISTANCE, gi_864 + 50);
   ObjectSet("SignalSTRH4", OBJPROP_YDISTANCE, gi_860 + 30);
   
   ObjectDelete("SignalSTRD1");
   ObjectCreate("SignalSTRD1", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SignalSTRD1", "-", 45, "Tahoma Narrow", color_str_d1);
   ObjectSet("SignalSTRD1", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SignalSTRD1", OBJPROP_XDISTANCE, gi_864 + 10);
   ObjectSet("SignalSTRD1", OBJPROP_YDISTANCE, gi_860 + 30);
   
   // Lógica de cálculo e indicación visual de Medias Móviles (EMA)
   double ima_m1_fast = iMA(Symbol(), g_timeframe_828, g_period_1056, 0, g_ma_method_1064, g_applied_price_1068, 0);
   double ima_m1_slow = iMA(Symbol(), g_timeframe_828, g_period_1060, 0, g_ma_method_1064, g_applied_price_1068, 0);
   double ima_m5_fast = iMA(Symbol(), g_timeframe_832, g_period_1056, 0, g_ma_method_1064, g_applied_price_1068, 0);
   double ima_m5_slow = iMA(Symbol(), g_timeframe_832, g_period_1060, 0, g_ma_method_1064, g_applied_price_1068, 0);
   double ima_m15_fast = iMA(Symbol(), g_timeframe_836, g_period_1056, 0, g_ma_method_1064, g_applied_price_1068, 0);
   double ima_m15_slow = iMA(Symbol(), g_timeframe_836, g_period_1060, 0, g_ma_method_1064, g_applied_price_1068, 0);
   double ima_m30_fast = iMA(Symbol(), g_timeframe_840, g_period_1056, 0, g_ma_method_1064, g_applied_price_1068, 0);
   double ima_m30_slow = iMA(Symbol(), g_timeframe_840, g_period_1060, 0, g_ma_method_1064, g_applied_price_1068, 0);
   double ima_h1_fast = iMA(Symbol(), g_timeframe_844, g_period_1056, 0, g_ma_method_1064, g_applied_price_1068, 0);
   double ima_h1_slow = iMA(Symbol(), g_timeframe_844, g_period_1060, 0, g_ma_method_1064, g_applied_price_1068, 0);
   double ima_h4_fast = iMA(Symbol(), g_timeframe_848, g_period_1056, 0, g_ma_method_1064, g_applied_price_1068, 0);
   double ima_h4_slow = iMA(Symbol(), g_timeframe_848, g_period_1060, 0, g_ma_method_1064, g_applied_price_1068, 0);
   double ima_d1_fast = iMA(Symbol(), g_timeframe_852, g_period_1056, 0, g_ma_method_1064, g_applied_price_1068, 0);
   double ima_d1_slow = iMA(Symbol(), g_timeframe_852, g_period_1060, 0, g_ma_method_1064, g_applied_price_1068, 0);
   
   color color_ema_m1, color_ema_m5, color_ema_m15, color_ema_m30, color_ema_h1, color_ema_h4, color_ema_d1;
   
   if (ima_m1_fast > ima_m1_slow)  { color_ema_m1 = g_color_1080; } else { color_ema_m1 = g_color_1084; }
   if (ima_m5_fast > ima_m5_slow)  { color_ema_m5 = g_color_1080; } else { color_ema_m5 = g_color_1084; }
   if (ima_m15_fast > ima_m15_slow) { color_ema_m15 = g_color_1080; } else { color_ema_m15 = g_color_1084; }
   if (ima_m30_fast > ima_m30_slow) { color_ema_m30 = g_color_1080; } else { color_ema_m30 = g_color_1084; }
   if (ima_h1_fast > ima_h1_slow)  { color_ema_h1 = g_color_1080; } else { color_ema_h1 = g_color_1084; }
   if (ima_h4_fast > ima_h4_slow)  { color_ema_h4 = g_color_1080; } else { color_ema_h4 = g_color_1084; }
   if (ima_d1_fast > ima_d1_slow)  { color_ema_d1 = g_color_1080; } else { color_ema_d1 = g_color_1084; }
   
   // Dibujar indicadores EMA en el panel gráfico
   ObjectDelete("SignalEMA_TEXT");
   ObjectCreate("SignalEMA_TEXT", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SignalEMA_TEXT", "EMA", 6, "Tahoma Narrow", g_color_888);
   ObjectSet("SignalEMA_TEXT", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SignalEMA_TEXT", OBJPROP_XDISTANCE, gi_864 + 300);
   ObjectSet("SignalEMA_TEXT", OBJPROP_YDISTANCE, gi_860 + 145);
   
   ObjectDelete("SignalEMAM1");
   ObjectCreate("SignalEMAM1", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SignalEMAM1", "-", 45, "Tahoma Narrow", color_ema_m1);
   ObjectSet("SignalEMAM1", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SignalEMAM1", OBJPROP_XDISTANCE, gi_864 + 250);
   ObjectSet("SignalEMAM1", OBJPROP_YDISTANCE, gi_860 + 60);
   
   ObjectDelete("SignalEMAM5");
   ObjectCreate("SignalEMAM5", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SignalEMAM5", "-", 45, "Tahoma Narrow", color_ema_m5);
   ObjectSet("SignalEMAM5", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SignalEMAM5", OBJPROP_XDISTANCE, gi_864 + 210);
   ObjectSet("SignalEMAM5", OBJPROP_YDISTANCE, gi_860 + 60);
   
   ObjectDelete("SignalEMAM15");
   ObjectCreate("SignalEMAM15", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SignalEMAM15", "-", 45, "Tahoma Narrow", color_ema_m15);
   ObjectSet("SignalEMAM15", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SignalEMAM15", OBJPROP_XDISTANCE, gi_864 + 170);
   ObjectSet("SignalEMAM15", OBJPROP_YDISTANCE, gi_860 + 60);
   
   ObjectDelete("SignalEMAM30");
   ObjectCreate("SignalEMAM30", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SignalEMAM30", "-", 45, "Tahoma Narrow", color_ema_m30);
   ObjectSet("SignalEMAM30", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SignalEMAM30", OBJPROP_XDISTANCE, gi_864 + 130);
   ObjectSet("SignalEMAM30", OBJPROP_YDISTANCE, gi_860 + 60);
   
   ObjectDelete("SignalEMAH1");
   ObjectCreate("SignalEMAH1", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SignalEMAH1", "-", 45, "Tahoma Narrow", color_ema_h1);
   ObjectSet("SignalEMAH1", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SignalEMAH1", OBJPROP_XDISTANCE, gi_864 + 90);
   ObjectSet("SignalEMAH1", OBJPROP_YDISTANCE, gi_860 + 60);
   
   ObjectDelete("SignalEMAH4");
   ObjectCreate("SignalEMAH4", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SignalEMAH4", "-", 45, "Tahoma Narrow", color_ema_h4);
   ObjectSet("SignalEMAH4", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SignalEMAH4", OBJPROP_XDISTANCE, gi_864 + 50);
   ObjectSet("SignalEMAH4", OBJPROP_YDISTANCE, gi_860 + 60);
   
   ObjectDelete("SignalEMAD1");
   ObjectCreate("SignalEMAD1", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SignalEMAD1", "-", 45, "Tahoma Narrow", color_ema_d1);
   ObjectSet("SignalEMAD1", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SignalEMAD1", OBJPROP_XDISTANCE, gi_864 + 10);
   ObjectSet("SignalEMAD1", OBJPROP_YDISTANCE, gi_860 + 60);
   
   // Lógica de cálculo visual de precios y volatilidad instantánea
   double current_bid = NormalizeDouble(MarketInfo(Symbol(), MODE_BID), Digits);
   double ima_m1_trend = iMA(Symbol(), PERIOD_M1, 1, 0, MODE_EMA, PRICE_CLOSE, 1);
   
   if (ima_m1_trend > current_bid) { color_price_trend = g_color_924; }
   else if (ima_m1_trend < current_bid) { color_price_trend = g_color_920; }
   else { color_price_trend = g_color_928; }
   
   ObjectDelete("cja");
   ObjectCreate("cja", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("cja", "cja", 8, "Tahoma Narrow", DimGray);
   ObjectSet("cja", OBJPROP_CORNER, g_corner_856);
   ObjectSet("cja", OBJPROP_XDISTANCE, gi_864 + 310);
   ObjectSet("cja", OBJPROP_YDISTANCE, gi_860 + 23);
   
   // Dibujar precio actual grande o pequeño
   if (gi_880 == FALSE) {
      if (gi_872 == TRUE) {
         ObjectDelete("Signalprice");
         ObjectCreate("Signalprice", OBJ_LABEL, g_window_868, 0, 0);
         ObjectSetText("Signalprice", DoubleToStr(current_bid, Digits), 35, "Arial", color_price_trend);
         ObjectSet("Signalprice", OBJPROP_CORNER, g_corner_856);
         ObjectSet("Signalprice", OBJPROP_XDISTANCE, gi_864 + 10);
         ObjectSet("Signalprice", OBJPROP_YDISTANCE, gi_860 + 150);
      }
   } else {
      if (gi_872 == TRUE) {
         ObjectDelete("Signalprice");
         ObjectCreate("Signalprice", OBJ_LABEL, g_window_868, 0, 0);
         ObjectSetText("Signalprice", DoubleToStr(current_bid, Digits), 15, "Arial", color_price_trend);
         ObjectSet("Signalprice", OBJPROP_CORNER, g_corner_856);
         ObjectSet("Signalprice", OBJPROP_XDISTANCE, gi_864 + 10);
         ObjectSet("Signalprice", OBJPROP_YDISTANCE, gi_860 + 150);
      }
   }
   
   // Cálculo de Spread y Rangos de Volatilidad Diaria
   int range_1d_1 = (iHigh(NULL, PERIOD_D1, 1) - iLow(NULL, PERIOD_D1, 1)) / Point;
   int sum_range_5d = 0;
   int sum_range_10d = 0;
   int sum_range_20d = 0;
   int loop_idx = 0;
   
   for (loop_idx = 1; loop_idx <= 5; loop_idx++)  sum_range_5d += (iHigh(NULL, PERIOD_D1, loop_idx) - iLow(NULL, PERIOD_D1, loop_idx)) / Point;
   for (loop_idx = 1; loop_idx <= 10; loop_idx++) sum_range_10d += (iHigh(NULL, PERIOD_D1, loop_idx) - iLow(NULL, PERIOD_D1, loop_idx)) / Point;
   for (loop_idx = 1; loop_idx <= 20; loop_idx++) sum_range_20d += (iHigh(NULL, PERIOD_D1, loop_idx) - iLow(NULL, PERIOD_D1, loop_idx)) / Point;
   
   int avg_5d = sum_range_5d / 5;
   int avg_10d = sum_range_10d / 10;
   int avg_20d = sum_range_20d / 20;
   int combined_volatility = (range_1d_1 + avg_5d + avg_10d + avg_20d) / 4;
   
   double daily_open = iOpen(NULL, PERIOD_D1, 0);
   double daily_close = iClose(NULL, PERIOD_D1, 0);
   double spread_instant = (Ask - Bid) / Point;
   double daily_high = iHigh(NULL, PERIOD_D1, 0);
   double daily_low = iLow(NULL, PERIOD_D1, 0);
   
   string dbl2str_chg_points = DoubleToStr((daily_close - daily_open) / Point, 0);
   string dbl2str_spread = DoubleToStr(spread_instant, Digits - 4);
   
   if (daily_close >= daily_open) { color_price_trend = g_color_904; }
   else { color_price_trend = g_color_908; }
   
   // Mostrar Spread en Panel
   ObjectDelete("SIG_DETAIL_1");
   ObjectCreate("SIG_DETAIL_1", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SIG_DETAIL_1", "Spread= ", 14, "Times New Roman", g_color_892);
   ObjectSet("SIG_DETAIL_1", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SIG_DETAIL_1", OBJPROP_XDISTANCE, gi_864 + 100);
   ObjectSet("SIG_DETAIL_1", OBJPROP_YDISTANCE, gi_860 + 250);
   
   ObjectDelete("SIG_DETAIL_2");
   ObjectCreate("SIG_DETAIL_2", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SIG_DETAIL_2", dbl2str_spread, 14, "Times New Roman", g_color_896);
   ObjectSet("SIG_DETAIL_2", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SIG_DETAIL_2", OBJPROP_XDISTANCE, gi_864 + 10);
   ObjectSet("SIG_DETAIL_2", OBJPROP_YDISTANCE, gi_860 + 250);
   
   ObjectDelete("SIG_DETAIL_3");
   ObjectCreate("SIG_DETAIL_3", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SIG_DETAIL_3", "Volatility Ratio= ", 14, "Times New Roman", g_color_892);
   ObjectSet("SIG_DETAIL_3", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SIG_DETAIL_3", OBJPROP_XDISTANCE, gi_864 + 65);
   ObjectSet("SIG_DETAIL_3", OBJPROP_YDISTANCE, gi_860 + 295);
   
   ObjectDelete("SIG_DETAIL_4");
   ObjectCreate("SIG_DETAIL_4", OBJ_LABEL, g_window_868, 0, 0);
   ObjectSetText("SIG_DETAIL_4", dbl2str_chg_points, 14, "Times New Roman", color_price_trend);
   ObjectSet("SIG_DETAIL_4", OBJPROP_CORNER, g_corner_856);
   ObjectSet("SIG_DETAIL_4", OBJPROP_XDISTANCE, gi_864 + 10);
   ObjectSet("SIG_DETAIL_4", OBJPROP_YDISTANCE, gi_860 + 295);
   
   // FILTRO DE VOLATILIDAD POR ATR (Seguridad)
   if (isHighVolatility()) {
      Print("ATR excede los ", MaxAllowedATR, " pips. No se abrirán nuevas operaciones.");
      return (0);
   }
   
   //+------------------------------------------------------------------+
   //| ESTRATEGIA 1: FIBONACCI FOCUS (HILO)                             |
   //+------------------------------------------------------------------+
   if (MM == TRUE)
      lotSize_Hilo = GetLotSizeBasedOnBalance();
   else
      lotSize_Hilo = GetLotBasedOnRange();
      
   if (UseTrailingStop) TrailingAlls_Hilo(TrailStart, TrailStop, AveragePrice_Hilo);
   
   if (UseTimeOut_Hilo) {
      if (TimeCurrent() >= TimeLimit_Hilo) {
         CloseThisSymbolAll_Hilo();
         Print("Closed All due_Hilo to TimeOut");
      }
   }
   

   if (LastBarTime_Hilo == Time[0]) return (0);

   PrintFormat("LotSize= %.5f , Time= %s, LastBarTime= %s", lotSize_Hilo, TimeToString(Time[0],TIME_MINUTES), TimeToString(LastBarTime_Hilo,TIME_MINUTES));
   Print("Paso 4");
   
   profit_Hilo = CalculateProfit_Hilo();
   if (UseEquityStop) {
      if (profit_Hilo < 0.0 && CheckStopOutByFloatingLoss(lotSize_Hilo, profit_Hilo)) {
         CloseThisSymbolAll_Hilo();
         Print("Closed All due_Hilo to Stop Out");
         OrderSentFlag_Hilo = FALSE;
      }
   }

   Print("Paso 5");
   
   CurrentTrades_Hilo = CountTrades_Hilo();
   if (CurrentTrades_Hilo == 0) ModifyRequired_Hilo = FALSE;

   Print("Paso 6");
   
   PrintFormat("OrdersTotal()= %d", OrdersTotal());
   
   // Buscar si existen órdenes abiertas de esta estrategia
   for (OrderLoopPos_Hilo = OrdersTotal()-1; OrderLoopPos_Hilo >= 0; OrderLoopPos_Hilo--) {
      cg = OrderSelect(OrderLoopPos_Hilo, SELECT_BY_POS, MODE_TRADES);
      PrintFormat("(OrderSymbol() %s != Symbol() %s || OrderMagicNumber() %d != MagicNumber_Hilo %d", OrderSymbol(), Symbol(),OrderMagicNumber(), MagicNumber_Hilo );
      
      if (OrderSymbol() != Symbol()) continue; 
      Print("Paso por acá...........................");
      if (OrderMagicNumber() == MagicNumber_Hilo) {
         if (OrderType() == OP_BUY) {
            HasBuyOrders_Hilo = TRUE;
            HasSellOrders_Hilo = FALSE;
            break;
         }
         if (OrderType() == OP_SELL) {
            HasBuyOrders_Hilo = FALSE;
            HasSellOrders_Hilo = TRUE;
            break;
         }
      }
      PrintFormat("Orden: %d, HasBuyOrders_Hilo: %b, HasSellOrders_Hilo: %b",OrderLoopPos_Hilo, HasBuyOrders_Hilo, HasSellOrders_Hilo);
   }
   
   // Verificar si se pueden abrir coberturas/martingalas adicionales
   if (CurrentTrades_Hilo > 0 && CurrentTrades_Hilo <= MaxTrades_Hilo) {
      RefreshRates();
      LastBuyPrice_Hilo = FindLastBuyPrice_Hilo();
      LastSellPrice_Hilo = FindLastSellPrice_Hilo();
      if (HasBuyOrders_Hilo && LastBuyPrice_Hilo - Ask >= PipStep * Point) CanOpenNew_Hilo = TRUE;
      if (HasSellOrders_Hilo && Bid - LastSellPrice_Hilo >= PipStep * Point) CanOpenNew_Hilo = TRUE;
   }
   
   if (CurrentTrades_Hilo < 1) {
      HasSellOrders_Hilo = FALSE;
      HasBuyOrders_Hilo = FALSE;
      CanOpenNew_Hilo = TRUE;
      EquityAtStart_Hilo = AccountEquity();
   }
   
   // Abrir operaciones de cobertura
   if (CanOpenNew_Hilo) {
      LastBuyPrice_Hilo = FindLastBuyPrice_Hilo();
      LastSellPrice_Hilo = FindLastSellPrice_Hilo();
      if (HasSellOrders_Hilo) {
         TradeCountForLot_Hilo = CurrentTrades_Hilo;
         NextLotSize_Hilo = NormalizeDouble(lotSize_Hilo * MathPow(LotExponent, TradeCountForLot_Hilo), lotdecimal);
         RefreshRates();
         
         Ticket_Hilo = OpenPendingOrder_Hilo(1, NextLotSize_Hilo, slip, StrategyComment_Hilo + "-" + TradeCountForLot_Hilo, MagicNumber_Hilo, 0, HotPink);
         if (Ticket_Hilo < 0) {
            Print("Error 1: ", GetLastError());
            return (0);
         }
         LastSellPrice_Hilo = FindLastSellPrice_Hilo();
         CanOpenNew_Hilo = FALSE;
         OrderSentFlag_Hilo = TRUE;
      } else if (HasBuyOrders_Hilo) {
         TradeCountForLot_Hilo = CurrentTrades_Hilo;
         NextLotSize_Hilo = NormalizeDouble(lotSize_Hilo * MathPow(LotExponent, TradeCountForLot_Hilo), lotdecimal);
         
         Ticket_Hilo = OpenPendingOrder_Hilo(0, NextLotSize_Hilo, slip, StrategyComment_Hilo + "-" + TradeCountForLot_Hilo, MagicNumber_Hilo, 0, Lime);
         if (Ticket_Hilo < 0) {
            Print("Error 2: ", GetLastError());
            return (0);
         }
         LastBuyPrice_Hilo = FindLastBuyPrice_Hilo();
         CanOpenNew_Hilo = FALSE;
         OrderSentFlag_Hilo = TRUE;
      }
   }
   
   // Abrir orden primaria (si no hay ninguna abierta)
   if (CanOpenNew_Hilo && CurrentTrades_Hilo < 1) {
      ihigh_d1_1 = iHigh(Symbol(), 0, 1);
      ilow_d1_2 = iLow(Symbol(), 0, 2);
      Bid_Hilo = Bid;
      Ask_Hilo = Ask;
      
      if (!HasSellOrders_Hilo && !HasBuyOrders_Hilo) {
         TradeCountForLot_Hilo = CurrentTrades_Hilo;
         NextLotSize_Hilo = lotSize_Hilo;
         
         if (ihigh_d1_1 > ilow_d1_2) {
            if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) > 30.0) {
               Ticket_Hilo = OpenPendingOrder_Hilo(1, NextLotSize_Hilo, slip, StrategyComment_Hilo + "-" + TradeCountForLot_Hilo, MagicNumber_Hilo, 0, HotPink);
               if (Ticket_Hilo < 0) {
                  Print("Error 3: ", GetLastError());
                  return (0);
               }
               LastBuyPrice_Hilo = FindLastBuyPrice_Hilo();
               OrderSentFlag_Hilo = TRUE;
            }
         } else {
            if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) < 70.0) {
               Ticket_Hilo = OpenPendingOrder_Hilo(0, NextLotSize_Hilo, slip, StrategyComment_Hilo + "-" + TradeCountForLot_Hilo, MagicNumber_Hilo, 0, Lime);
               if (Ticket_Hilo < 0) {
                  Print("Error 4: ", GetLastError());
                  return (0);
               }
               LastSellPrice_Hilo = FindLastSellPrice_Hilo();
               OrderSentFlag_Hilo = TRUE;
            }
         }
         if (Ticket_Hilo > 0) TimeLimit_Hilo = TimeCurrent() + 60.0 * (60.0 * TimeOutHours_Hilo);
         CanOpenNew_Hilo = FALSE;
      }
   }
   
   // Calcular precio promedio y equilibrar Take Profits
   CurrentTrades_Hilo = CountTrades_Hilo();
   AveragePrice_Hilo = 0;
   double totalLots_Hilo = 0;
   for (OrderLoopPos_Hilo = OrdersTotal() - 1; OrderLoopPos_Hilo >= 0; OrderLoopPos_Hilo--) {
      cg = OrderSelect(OrderLoopPos_Hilo, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber_Hilo) continue;
      if (OrderType() == OP_BUY || OrderType() == OP_SELL) {
         AveragePrice_Hilo += OrderOpenPrice() * OrderLots();
         totalLots_Hilo += OrderLots();
      }
   }
   if (CurrentTrades_Hilo > 0) AveragePrice_Hilo = NormalizeDouble(AveragePrice_Hilo / totalLots_Hilo, Digits);
   
   if (OrderSentFlag_Hilo) {
      for (OrderLoopPos_Hilo = OrdersTotal() - 1; OrderLoopPos_Hilo >= 0; OrderLoopPos_Hilo--) {
         cg = OrderSelect(OrderLoopPos_Hilo, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber_Hilo) continue;
         
         if (OrderType() == OP_BUY) {
            TakeProfitPrice_Hilo = AveragePrice_Hilo + TakeProfit * Point;
            StopLossPrice_Hilo = AveragePrice_Hilo - StopLossPips_Hilo * Point;
            ModifyRequired_Hilo = TRUE;
         }
         if (OrderType() == OP_SELL) {
            TakeProfitPrice_Hilo = AveragePrice_Hilo - TakeProfit * Point;
            StopLossPrice_Hilo = AveragePrice_Hilo + StopLossPips_Hilo * Point;
            ModifyRequired_Hilo = TRUE;
         }
      }
   }
   
   if (OrderSentFlag_Hilo && ModifyRequired_Hilo) {
      for (OrderLoopPos_Hilo = OrdersTotal() - 1; OrderLoopPos_Hilo >= 0; OrderLoopPos_Hilo--) {
         cg = OrderSelect(OrderLoopPos_Hilo, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber_Hilo) continue;
         
         while (!OrderModify(OrderTicket(), AveragePrice_Hilo, OrderStopLoss(), TakeProfitPrice_Hilo, 0, Yellow)) {
            Sleep(1000);
            RefreshRates();
         }
         OrderSentFlag_Hilo = FALSE;
      }
   }
   
   LastBarTime_Hilo = Time[0];

   //+------------------------------------------------------------------+
   //| ESTRATEGIA 2: SCALPER PRO                                        |
   //+------------------------------------------------------------------+
   if (MM == TRUE)
      lotSize_Scalper = GetLotSizeBasedOnBalance();
   else
      lotSize_Scalper = GetLotBasedOnRange();
      
   if (UseTrailingStop) TrailingAlls_15(TrailStart, TrailStop, AveragePrice_Scalper);
   
   if (UseTimeOut_Scalper) {
      if (TimeCurrent() >= TimeLimit_Scalper) {
         CloseThisSymbolAll_15();
         Print("Closed All due to TimeOut");
      }
   }
   
   if (LastBarTime_Scalper != Time[0]) {
      LastBarTime_Scalper = Time[0];
      profit_Scalper = CalculateProfit_15();
      if (UseEquityStop) {
         if (profit_Scalper < 0.0 && CheckStopOutByFloatingLoss(lotSize_Scalper, profit_Scalper)) {
            CloseThisSymbolAll_15();
            Print("Closed All due to Stop Out");
            OrderSentFlag_Scalper = FALSE;
         }
      }
      
      CurrentTrades_Scalper = CountTrades_15();
      if (CurrentTrades_Scalper == 0) ModifyRequired_Scalper = FALSE;
      
      for (OrderLoopPos_Scalper = OrdersTotal() - 1; OrderLoopPos_Scalper >= 0; OrderLoopPos_Scalper--) {
         cg = OrderSelect(OrderLoopPos_Scalper, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_15) continue;
         
         if (OrderType() == OP_BUY) {
            HasBuyOrders_Scalper = TRUE;
            HasSellOrders_Scalper = FALSE;
            break;
         }
         if (OrderType() == OP_SELL) {
            HasBuyOrders_Scalper = FALSE;
            HasSellOrders_Scalper = TRUE;
            break;
         }
      }
      
      if (CurrentTrades_Scalper > 0 && CurrentTrades_Scalper <= MaxTrades_15) {
         RefreshRates();
         LastBuyPrice_Scalper = FindLastBuyPrice_15();
         LastSellPrice_Scalper = FindLastSellPrice_15();
         if (HasBuyOrders_Scalper && LastBuyPrice_Scalper - Ask >= PipStep * Point) CanOpenNew_Scalper = TRUE;
         if (HasSellOrders_Scalper && Bid - LastSellPrice_Scalper >= PipStep * Point) CanOpenNew_Scalper = TRUE;
      }
      
      if (CurrentTrades_Scalper < 1) {
         HasSellOrders_Scalper = FALSE;
         HasBuyOrders_Scalper = FALSE;
         CanOpenNew_Scalper = TRUE;
         EquityAtStart_Scalper = AccountEquity();
      }
      
      if (CanOpenNew_Scalper) {
         LastBuyPrice_Scalper = FindLastBuyPrice_15();
         LastSellPrice_Scalper = FindLastSellPrice_15();
         if (HasSellOrders_Scalper) {
            TradeCountForLot_Scalper = CurrentTrades_Scalper;
            NextLotSize_Scalper = NormalizeDouble(lotSize_Scalper * MathPow(LotExponent, TradeCountForLot_Scalper), lotdecimal);
            RefreshRates();
            Ticket_Scalper = OpenPendingOrder_15(1, NextLotSize_Scalper, slip, StrategyComment_Scalper + "-" + TradeCountForLot_Scalper, g_magic_176_15, 0, HotPink);
            if (Ticket_Scalper < 0) {
               Print("Error 5: ", GetLastError());
               return (0);
            }
            LastSellPrice_Scalper = FindLastSellPrice_15();
            CanOpenNew_Scalper = FALSE;
            OrderSentFlag_Scalper = TRUE;
         } else if (HasBuyOrders_Scalper) {
            TradeCountForLot_Scalper = CurrentTrades_Scalper;
            NextLotSize_Scalper = NormalizeDouble(lotSize_Scalper * MathPow(LotExponent, TradeCountForLot_Scalper), lotdecimal);
            Ticket_Scalper = OpenPendingOrder_15(0, NextLotSize_Scalper, slip, StrategyComment_Scalper + "-" + TradeCountForLot_Scalper, g_magic_176_15, 0, Lime);
            if (Ticket_Scalper < 0) {
               Print("Error 6: ", GetLastError());
               return (0);
            }
            LastBuyPrice_Scalper = FindLastBuyPrice_15();
            CanOpenNew_Scalper = FALSE;
            OrderSentFlag_Scalper = TRUE;
         }
      }
   }
   
   // Disparador de nuevas barras para Scalper Pro
   if (LastBarTime_ScalperTrigger != iTime(NULL, Timeframe_Scalper, 0)) {
      int total_posSc = OrdersTotal();
      int count_scalper_trades = 0;
      for (int i = total_posSc; i >= 1; i--) {
         cg = OrderSelect(i - 1, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_15) continue;
         count_scalper_trades++;
      }
      
      if (total_posSc == 0 || count_scalper_trades < 1) {
         iclose_scalper_2 = iClose(Symbol(), 0, 2);
         iclose_scalper_1 = iClose(Symbol(), 0, 1);
         Bid_Scalper = Bid;
         Ask_Scalper = Ask;
         TradeCountForLot_Scalper = CurrentTrades_Scalper;
         NextLotSize_Scalper = lotSize_Scalper;
         
         if (iclose_scalper_2 > iclose_scalper_1) {
            Ticket_Scalper = OpenPendingOrder_15(1, NextLotSize_Scalper, slip, StrategyComment_Scalper + "-" + TradeCountForLot_Scalper, g_magic_176_15, 0, HotPink);
            if (Ticket_Scalper < 0) {
               Print("Error 7: ", GetLastError());
               return (0);
            }
            LastBuyPrice_Scalper = FindLastBuyPrice_15();
            OrderSentFlag_Scalper = TRUE;
         } else {
            Ticket_Scalper = OpenPendingOrder_15(0, NextLotSize_Scalper, slip, StrategyComment_Scalper + "-" + TradeCountForLot_Scalper, g_magic_176_15, 0, Lime);
            if (Ticket_Scalper < 0) {
               Print("Error 8: ", GetLastError());
               return (0);
            }
            LastSellPrice_Scalper = FindLastSellPrice_15();
            OrderSentFlag_Scalper = TRUE;
         }
         if (Ticket_Scalper > 0) TimeLimit_Scalper = TimeCurrent() + 60.0 * (60.0 * TimeOutHours_Scalper);
         CanOpenNew_Scalper = FALSE;
      }
      LastBarTime_ScalperTrigger = iTime(NULL, Timeframe_Scalper, 0);
   }
   
   CurrentTrades_Scalper = CountTrades_15();
   AveragePrice_Scalper = 0;
   double totalLots_Scalper = 0;
   for (OrderLoopPos_Scalper = OrdersTotal() - 1; OrderLoopPos_Scalper >= 0; OrderLoopPos_Scalper--) {
      cg = OrderSelect(OrderLoopPos_Scalper, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_15) continue;
      if (OrderType() == OP_BUY || OrderType() == OP_SELL) {
         AveragePrice_Scalper += OrderOpenPrice() * OrderLots();
         totalLots_Scalper += OrderLots();
      }
   }
   if (CurrentTrades_Scalper > 0) AveragePrice_Scalper = NormalizeDouble(AveragePrice_Scalper / totalLots_Scalper, Digits);
   
   if (OrderSentFlag_Scalper) {
      for (OrderLoopPos_Scalper = OrdersTotal() - 1; OrderLoopPos_Scalper >= 0; OrderLoopPos_Scalper--) {
         cg = OrderSelect(OrderLoopPos_Scalper, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_15) continue;
         
         if (OrderType() == OP_BUY) {
            TakeProfitPrice_Scalper = AveragePrice_Scalper + TakeProfit * Point;
            StopLossPrice_Scalper = AveragePrice_Scalper - StopLossPips_Scalper * Point;
            ModifyRequired_Scalper = TRUE;
         }
         if (OrderType() == OP_SELL) {
            TakeProfitPrice_Scalper = AveragePrice_Scalper - TakeProfit * Point;
            StopLossPrice_Scalper = AveragePrice_Scalper + StopLossPips_Scalper * Point;
            ModifyRequired_Scalper = TRUE;
         }
      }
   }
   
   if (OrderSentFlag_Scalper && ModifyRequired_Scalper) {
      for (OrderLoopPos_Scalper = OrdersTotal() - 1; OrderLoopPos_Scalper >= 0; OrderLoopPos_Scalper--) {
         cg = OrderSelect(OrderLoopPos_Scalper, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_15) continue;
         
         while (!OrderModify(OrderTicket(), AveragePrice_Scalper, OrderStopLoss(), TakeProfitPrice_Scalper, 0, Yellow)) {
            Sleep(1000);
            RefreshRates();
         }
         OrderSentFlag_Scalper = FALSE;
      }
   }
   
   //+------------------------------------------------------------------+
   //| ESTRATEGIA 3: TRENDMASTER                                        |
   //+------------------------------------------------------------------+
   if (MM == TRUE)
      lotSize_Trend = GetLotSizeBasedOnBalance();
   else
      lotSize_Trend = GetLotBasedOnRange();
      
   if (UseTrailingStop) TrailingAlls_16(TrailStart, TrailStop, AveragePrice_Trend);
   
   if (UseTimeOut_Trend) {
      if (TimeCurrent() >= TimeLimit_Trend) {
         CloseThisSymbolAll_16();
         Print("Closed All due to TimeOut");
      }
   }
   
   if (LastBarTime_Trend != Time[0]) {
      LastBarTime_Trend = Time[0];
      profit_Trend = CalculateProfit_16();
      if (UseEquityStop) {
         if (profit_Trend < 0.0 && CheckStopOutByFloatingLoss(lotSize_Trend, profit_Trend)) {
            CloseThisSymbolAll_16();
            Print("Closed All due to Stop Out");
            OrderSentFlag_Trend = FALSE;
         }
      }
      
      CurrentTrades_Trend = CountTrades_16();
      if (CurrentTrades_Trend == 0) ModifyRequired_Trend = FALSE;
      
      for (OrderLoopPos_Trend = OrdersTotal() - 1; OrderLoopPos_Trend >= 0; OrderLoopPos_Trend--) {
         cg = OrderSelect(OrderLoopPos_Trend, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_16) continue;
         
         if (OrderType() == OP_BUY) {
            HasBuyOrders_Trend = TRUE;
            HasSellOrders_Trend = FALSE;
            break;
         }
         if (OrderType() == OP_SELL) {
            HasBuyOrders_Trend = FALSE;
            HasSellOrders_Trend = TRUE;
            break;
         }
      }
      
      if (CurrentTrades_Trend > 0 && CurrentTrades_Trend <= MaxTrades_16) {
         RefreshRates();
         LastBuyPrice_Trend = FindLastBuyPrice_16();
         LastSellPrice_Trend = FindLastSellPrice_16();
         if (HasBuyOrders_Trend && LastBuyPrice_Trend - Ask >= PipStep * Point) CanOpenNew_Trend = TRUE;
         if (HasSellOrders_Trend && Bid - LastSellPrice_Trend >= PipStep * Point) CanOpenNew_Trend = TRUE;
      }
      
      if (CurrentTrades_Trend < 1) {
         HasSellOrders_Trend = FALSE;
         HasBuyOrders_Trend = FALSE;
         EquityAtStart_Trend = AccountEquity();
      }
      
      if (CanOpenNew_Trend) {
         LastBuyPrice_Trend = FindLastBuyPrice_16();
         LastSellPrice_Trend = FindLastSellPrice_16();
         if (HasSellOrders_Trend) {
            TradeCountForLot_Trend = CurrentTrades_Trend;
            NextLotSize_Trend = NormalizeDouble(lotSize_Trend * MathPow(LotExponent, TradeCountForLot_Trend), lotdecimal);
            RefreshRates();
            Ticket_Trend = OpenPendingOrder_16(1, NextLotSize_Trend, slip, StrategyComment_Trend + "-" + TradeCountForLot_Trend, g_magic_176_16, 0, HotPink);
            if (Ticket_Trend < 0) {
               Print("Error 9: ", GetLastError());
               return (0);
            }
            LastSellPrice_Trend = FindLastSellPrice_16();
            CanOpenNew_Trend = FALSE;
            OrderSentFlag_Trend = TRUE;
         } else if (HasBuyOrders_Trend) {
            TradeCountForLot_Trend = CurrentTrades_Trend;
            NextLotSize_Trend = NormalizeDouble(lotSize_Trend * MathPow(LotExponent, TradeCountForLot_Trend), lotdecimal);
            Ticket_Trend = OpenPendingOrder_16(0, NextLotSize_Trend, slip, StrategyComment_Trend + "-" + TradeCountForLot_Trend, g_magic_176_16, 0, Lime);
            if (Ticket_Trend < 0) {
               Print("Error 10: ", GetLastError());
               return (0);
            }
            LastBuyPrice_Trend = FindLastBuyPrice_16();
            CanOpenNew_Trend = FALSE;
            OrderSentFlag_Trend = TRUE;
         }
      }
   }
   
   // Disparador de nuevas barras para TrendMaster
   if (LastBarTime_TrendTrigger != iTime(NULL, Timeframe_Trend, 0)) {
      int total_posTr = OrdersTotal();
      int count_trend_trades = 0;
      for (int itr = total_posTr; itr >= 1; itr--) {
         cg = OrderSelect(itr - 1, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_16) continue;
         count_trend_trades++;
      }
      
      if (total_posTr == 0 || count_trend_trades < 1) {
         iclose_scalper_2 = iClose(Symbol(), 0, 2);
         iclose_scalper_1 = iClose(Symbol(), 0, 1);
         Bid_Trend = Bid;
         Ask_Trend = Ask;
         TradeCountForLot_Trend = CurrentTrades_Trend;
         NextLotSize_Trend = lotSize_Trend;
         
         if (iclose_scalper_2 > iclose_scalper_1) {
            if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) > 30.0) {
               Ticket_Trend = OpenPendingOrder_16(1, NextLotSize_Trend, slip, StrategyComment_Trend + "-" + TradeCountForLot_Trend, g_magic_176_16, 0, HotPink);
               if (Ticket_Trend < 0) {
                  Print("Error 11: ", GetLastError());
                  return (0);
               }
               LastBuyPrice_Trend = FindLastBuyPrice_16();
               OrderSentFlag_Trend = TRUE;
            }
         } else {
            if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) < 70.0) {
               Ticket_Trend = OpenPendingOrder_16(0, NextLotSize_Trend, slip, StrategyComment_Trend + "-" + TradeCountForLot_Trend, g_magic_176_16, 0, Lime);
               if (Ticket_Trend < 0) {
                  Print("Error 12: ", GetLastError());
                  return (0);
               }
               LastSellPrice_Trend = FindLastSellPrice_16();
               OrderSentFlag_Trend = TRUE;
            }
         }
         if (Ticket_Trend > 0) TimeLimit_Trend = TimeCurrent() + 60.0 * (60.0 * TimeOutHours_Trend);
         CanOpenNew_Trend = FALSE;
      }
      LastBarTime_TrendTrigger = iTime(NULL, Timeframe_Trend, 0);
   }
   
   CurrentTrades_Trend = CountTrades_16();
   AveragePrice_Trend = 0;
   double totalLots_Trend = 0;
   for (OrderLoopPos_Trend = OrdersTotal() - 1; OrderLoopPos_Trend >= 0; OrderLoopPos_Trend--) {
      cg = OrderSelect(OrderLoopPos_Trend, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_16) continue;
      if (OrderType() == OP_BUY || OrderType() == OP_SELL) {
         AveragePrice_Trend += OrderOpenPrice() * OrderLots();
         totalLots_Trend += OrderLots();
      }
   }
   if (CurrentTrades_Trend > 0) AveragePrice_Trend = NormalizeDouble(AveragePrice_Trend / totalLots_Trend, Digits);
   
   if (OrderSentFlag_Trend) {
      for (OrderLoopPos_Trend = OrdersTotal() - 1; OrderLoopPos_Trend >= 0; OrderLoopPos_Trend--) {
         cg = OrderSelect(OrderLoopPos_Trend, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_16) continue;
         
         if (OrderType() == OP_BUY) {
            TakeProfitPrice_Trend = AveragePrice_Trend + TakeProfit * Point;
            StopLossPrice_Trend = AveragePrice_Trend - StopLossPips_Trend * Point;
            ModifyRequired_Trend = TRUE;
         }
         if (OrderType() == OP_SELL) {
            TakeProfitPrice_Trend = AveragePrice_Trend - TakeProfit * Point;
            StopLossPrice_Trend = AveragePrice_Trend + StopLossPips_Trend * Point;
            ModifyRequired_Trend = TRUE;
         }
      }
   }
   
   if (OrderSentFlag_Trend && ModifyRequired_Trend) {
      for (OrderLoopPos_Trend = OrdersTotal() - 1; OrderLoopPos_Trend >= 0; OrderLoopPos_Trend--) {
         cg = OrderSelect(OrderLoopPos_Trend, SELECT_BY_POS, MODE_TRADES);
         if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_16) continue;
         
         while (!OrderModify(OrderTicket(), AveragePrice_Trend, OrderStopLoss(), TakeProfitPrice_Trend, 0, Yellow)) {
            Sleep(1000);
            RefreshRates();
         }
         OrderSentFlag_Trend = FALSE;
      }
   }
   
   HideTestIndicators(TRUE);
   return (0);
}

//+------------------------------------------------------------------+
//| FUNCIONES AUXILIARES: ESTRATEGIA FIBONACCI FOCUS (HILO)          |
//+------------------------------------------------------------------+

// Contar órdenes de Fibonacci Focus
int CountTrades_Hilo() {
   int count = 0;
   for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
      cg = OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber_Hilo) continue;
      if (OrderType() == OP_SELL || OrderType() == OP_BUY) count++;
   }
   return (count);
}

// Cerrar todas las órdenes de Fibonacci Focus
void CloseThisSymbolAll_Hilo() {
   for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
      cg = OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber_Hilo) {
         if (OrderType() == OP_BUY) cg = OrderClose(OrderTicket(), OrderLots(), Bid, slip, Blue);
         if (OrderType() == OP_SELL) cg = OrderClose(OrderTicket(), OrderLots(), Ask, slip, Red);
         Sleep(1000);
      }
   }
}

// Abrir orden a mercado (Compra/Venta) de Fibonacci Focus
int OpenPendingOrder_Hilo(int type, double lots, int slippage, string comment_str, int magic, int datetime_val, color arrow_color) {
   int ticket = 0;
   int error_code = 0;
   int retry_count = 0;
   int max_retries = 100;
   
   switch (type) {
   case 0: // COMPRA
      for (retry_count = 0; retry_count < max_retries; retry_count++) {
         RefreshRates();
         ticket = OrderSend(Symbol(), OP_BUY, lots, Ask, slippage, 0, 0, comment_str, magic, datetime_val, arrow_color);
         error_code = GetLastError();
         if (error_code == 0) break;
         if (!(error_code == 4 || error_code == 137 || error_code == 146 || error_code == 136)) break;
         Sleep(5000);
      }
      break;
   case 1: // VENTA
      for (retry_count = 0; retry_count < max_retries; retry_count++) {
         RefreshRates();
         ticket = OrderSend(Symbol(), OP_SELL, lots, Bid, slippage, 0, 0, comment_str, magic, datetime_val, arrow_color);
         error_code = GetLastError();
         if (error_code == 0) break;
         if (!(error_code == 4 || error_code == 137 || error_code == 146 || error_code == 136)) break;
         Sleep(5000);
      }
      break;
   }
   PrintFormat("Ticket: %d ", ticket);
   return (ticket);
}

// Calcular beneficio flotante actual de Fibonacci Focus
double CalculateProfit_Hilo() {
   double total_profit = 0;
   for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
      cg = OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber_Hilo) continue;
      if (OrderType() == OP_BUY || OrderType() == OP_SELL) total_profit += OrderProfit();
   }
   return (total_profit);
}

// Trailing Stop dinámico para Fibonacci Focus
void TrailingAlls_Hilo(int trail_start, int trail_stop, double avg_price) {
   int points_diff;
   double stop_loss_val;
   double sl_target;
   
   if (trail_stop != 0) {
      for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
         if (OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber_Hilo) continue;
            
            if (OrderType() == OP_BUY) {
               points_diff = NormalizeDouble((Bid - avg_price) / Point, 0);
               if (points_diff < trail_start) continue;
               stop_loss_val = OrderStopLoss();
               sl_target = Bid - trail_stop * Point;
               if (stop_loss_val == 0.0 || sl_target > stop_loss_val) cg = OrderModify(OrderTicket(), avg_price, sl_target, OrderTakeProfit(), 0, Aqua);
            }
            if (OrderType() == OP_SELL) {
               points_diff = NormalizeDouble((avg_price - Ask) / Point, 0);
               if (points_diff < trail_start) continue;
               stop_loss_val = OrderStopLoss();
               sl_target = Ask + trail_stop * Point;
               if (stop_loss_val == 0.0 || sl_target < stop_loss_val) cg = OrderModify(OrderTicket(), avg_price, sl_target, OrderTakeProfit(), 0, Red);
            }
            Sleep(1000);
         }
      }
   }
}

// Obtener precio de apertura de la última orden de compra
double FindLastBuyPrice_Hilo() {
   double last_price = 0;
   int highest_ticket = 0;
   for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
      cg = OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber_Hilo) continue;
      if (OrderType() == OP_BUY) {
         if (OrderTicket() > highest_ticket) {
            last_price = OrderOpenPrice();
            highest_ticket = OrderTicket();
         }
      }
   }
   return (last_price);
}

// Obtener precio de apertura de la última orden de venta
double FindLastSellPrice_Hilo() {
   double last_price = 0;
   int highest_ticket = 0;
   for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
      cg = OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber_Hilo) continue;
      if (OrderType() == OP_SELL) {
         if (OrderTicket() > highest_ticket) {
            last_price = OrderOpenPrice();
            highest_ticket = OrderTicket();
         }
      }
   }
   return (last_price);
}

//+------------------------------------------------------------------+
//| FUNCIONES AUXILIARES: ESTRATEGIA SCALPER PRO                     |
//+------------------------------------------------------------------+

// Contar órdenes de Scalper Pro
int CountTrades_15() {
   int count = 0;
   for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
      cg = OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_15) continue;
      if (OrderType() == OP_SELL || OrderType() == OP_BUY) count++;
   }
   return (count);
}

// Cerrar todas las órdenes de Scalper Pro
void CloseThisSymbolAll_15() {
   for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
      cg = OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == g_magic_176_15) {
         if (OrderType() == OP_BUY) cg = OrderClose(OrderTicket(), OrderLots(), Bid, slip, Blue);
         if (OrderType() == OP_SELL) cg = OrderClose(OrderTicket(), OrderLots(), Ask, slip, Red);
         Sleep(1000);
      }
   }
}

// Abrir orden a mercado (Compra/Venta) de Scalper Pro
int OpenPendingOrder_15(int type, double lots, int slippage, string comment_str, int magic, int datetime_val, color arrow_color) {
   int ticket = 0;
   int error_code = 0;
   int retry_count = 0;
   int max_retries = 100;
   
   switch (type) {
   case 0: // COMPRA
      for (retry_count = 0; retry_count < max_retries; retry_count++) {
         RefreshRates();
         ticket = OrderSend(Symbol(), OP_BUY, lots, Ask, slippage, 0, 0, comment_str, magic, datetime_val, arrow_color);
         error_code = GetLastError();
         if (error_code == 0) break;
         if (!(error_code == 4 || error_code == 137 || error_code == 146 || error_code == 136)) break;
         Sleep(5000);
      }
      break;
   case 1: // VENTA
      for (retry_count = 0; retry_count < max_retries; retry_count++) {
         RefreshRates();
         ticket = OrderSend(Symbol(), OP_SELL, lots, Bid, slippage, 0, 0, comment_str, magic, datetime_val, arrow_color);
         error_code = GetLastError();
         if (error_code == 0) break;
         if (!(error_code == 4 || error_code == 137 || error_code == 146 || error_code == 136)) break;
         Sleep(5000);
      }
      break;
   }
   return (ticket);
}

// Calcular beneficio flotante actual de Scalper Pro
double CalculateProfit_15() {
   double total_profit = 0;
   for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
      cg = OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_15) continue;
      if (OrderType() == OP_BUY || OrderType() == OP_SELL) total_profit += OrderProfit();
   }
   return (total_profit);
}

// Trailing Stop dinámico para Scalper Pro
void TrailingAlls_15(int trail_start, int trail_stop, double avg_price) {
   int points_diff;
   double stop_loss_val;
   double sl_target;
   
   if (trail_stop != 0) {
      for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
         if (OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_15) continue;
            
            if (OrderType() == OP_BUY) {
               points_diff = NormalizeDouble((Bid - avg_price) / Point, 0);
               if (points_diff < trail_start) continue;
               stop_loss_val = OrderStopLoss();
               sl_target = Bid - trail_stop * Point;
               if (stop_loss_val == 0.0 || sl_target > stop_loss_val) cg = OrderModify(OrderTicket(), avg_price, sl_target, OrderTakeProfit(), 0, Aqua);
            }
            if (OrderType() == OP_SELL) {
               points_diff = NormalizeDouble((avg_price - Ask) / Point, 0);
               if (points_diff < trail_start) continue;
               stop_loss_val = OrderStopLoss();
               sl_target = Ask + trail_stop * Point;
               if (stop_loss_val == 0.0 || sl_target < stop_loss_val) cg = OrderModify(OrderTicket(), avg_price, sl_target, OrderTakeProfit(), 0, Red);
            }
            Sleep(1000);
         }
      }
   }
}

// Obtener precio de apertura de la última orden de compra en Scalper Pro
double FindLastBuyPrice_15() {
   double last_price = 0;
   int highest_ticket = 0;
   for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
      cg = OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_15) continue;
      if (OrderType() == OP_BUY) {
         if (OrderTicket() > highest_ticket) {
            last_price = OrderOpenPrice();
            highest_ticket = OrderTicket();
         }
      }
   }
   return (last_price);
}

// Obtener precio de apertura de la última orden de venta en Scalper Pro
double FindLastSellPrice_15() {
   double last_price = 0;
   int highest_ticket = 0;
   for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
      cg = OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_15) continue;
      if (OrderType() == OP_SELL) {
         if (OrderTicket() > highest_ticket) {
            last_price = OrderOpenPrice();
            highest_ticket = OrderTicket();
         }
      }
   }
   return (last_price);
}

//+------------------------------------------------------------------+
//| FUNCIONES AUXILIARES: ESTRATEGIA TRENDMASTER                     |
//+------------------------------------------------------------------+

// Contar órdenes de TrendMaster
int CountTrades_16() {
   int count = 0;
   for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
      cg = OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_16) continue;
      if (OrderType() == OP_SELL || OrderType() == OP_BUY) count++;
   }
   return (count);
}

// Cerrar todas las órdenes de TrendMaster
void CloseThisSymbolAll_16() {
   for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
      cg = OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == g_magic_176_16) {
         if (OrderType() == OP_BUY) cg = OrderClose(OrderTicket(), OrderLots(), Bid, slip, Blue);
         if (OrderType() == OP_SELL) cg = OrderClose(OrderTicket(), OrderLots(), Ask, slip, Red);
         Sleep(1000);
      }
   }
}

// Abrir orden a mercado (Compra/Venta) de TrendMaster
int OpenPendingOrder_16(int type, double lots, int slippage, string comment_str, int magic, int datetime_val, color arrow_color) {
   int ticket = 0;
   int error_code = 0;
   int retry_count = 0;
   int max_retries = 100;
   
   switch (type) {
   case 0: // COMPRA
      for (retry_count = 0; retry_count < max_retries; retry_count++) {
         RefreshRates();
         ticket = OrderSend(Symbol(), OP_BUY, lots, Ask, slippage, 0, 0, comment_str, magic, datetime_val, arrow_color);
         error_code = GetLastError();
         if (error_code == 0) break;
         if (!(error_code == 4 || error_code == 137 || error_code == 146 || error_code == 136)) break;
         Sleep(5000);
      }
      break;
   case 1: // VENTA
      for (retry_count = 0; retry_count < max_retries; retry_count++) {
         RefreshRates();
         ticket = OrderSend(Symbol(), OP_SELL, lots, Bid, slippage, 0, 0, comment_str, magic, datetime_val, arrow_color);
         error_code = GetLastError();
         if (error_code == 0) break;
         if (!(error_code == 4 || error_code == 137 || error_code == 146 || error_code == 136)) break;
         Sleep(5000);
      }
      break;
   }
   return (ticket);
}

// Calcular beneficio flotante actual de TrendMaster
double CalculateProfit_16() {
   double total_profit = 0;
   for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
      cg = OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_16) continue;
      if (OrderType() == OP_BUY || OrderType() == OP_SELL) total_profit += OrderProfit();
   }
   return (total_profit);
}

// Trailing Stop dinámico para TrendMaster
void TrailingAlls_16(int trail_start, int trail_stop, double avg_price) {
   int points_diff;
   double stop_loss_val;
   double sl_target;
   
   if (trail_stop != 0) {
      for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
         if (OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_16) continue;
            
            if (OrderType() == OP_BUY) {
               points_diff = NormalizeDouble((Bid - avg_price) / Point, 0);
               if (points_diff < trail_start) continue;
               stop_loss_val = OrderStopLoss();
               sl_target = Bid - trail_stop * Point;
               if (stop_loss_val == 0.0 || sl_target > stop_loss_val) cg = OrderModify(OrderTicket(), avg_price, sl_target, OrderTakeProfit(), 0, Aqua);
            }
            if (OrderType() == OP_SELL) {
               points_diff = NormalizeDouble((avg_price - Ask) / Point, 0);
               if (points_diff < trail_start) continue;
               stop_loss_val = OrderStopLoss();
               sl_target = Ask + trail_stop * Point;
               if (stop_loss_val == 0.0 || sl_target < stop_loss_val) cg = OrderModify(OrderTicket(), avg_price, sl_target, OrderTakeProfit(), 0, Red);
            }
            Sleep(1000);
         }
      }
   }
}

// Obtener precio de apertura de la última orden de compra en TrendMaster
double FindLastBuyPrice_16() {
   double last_price = 0;
   int highest_ticket = 0;
   for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
      cg = OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_16) continue;
      if (OrderType() == OP_BUY) {
         if (OrderTicket() > highest_ticket) {
            last_price = OrderOpenPrice();
            highest_ticket = OrderTicket();
         }
      }
   }
   return (last_price);
}

// Obtener precio de apertura de la última orden de venta en TrendMaster
double FindLastSellPrice_16() {
   double last_price = 0;
   int highest_ticket = 0;
   for (int pos = OrdersTotal() - 1; pos >= 0; pos--) {
      cg = OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != g_magic_176_16) continue;
      if (OrderType() == OP_SELL) {
         if (OrderTicket() > highest_ticket) {
            last_price = OrderOpenPrice();
            highest_ticket = OrderTicket();
         }
      }
   }
   return (last_price);
}

//+------------------------------------------------------------------+
//| FUNCIONES GESTIÓN DE RIESGO Y TAMAÑO DE LOTES (SISTEMA MM)       |
//+------------------------------------------------------------------+

// Calcular tamaño de lote dinámico basado en Balance y Volatilidad (ATR)
double GetLotSizeBasedOnBalance() {
   double balance = AccountBalance();
   double lotSize = 0.0;
   
   if (Point <= 0) {
      Print("Error: point <= 0");
      return (0);
   }

   // Obtener el ATR actual
   double atr = iATR(Symbol(), ATR_Timeframe, ATR_Period, 0);
   
   if (isHighVolatility()) {
      PrintFormat("Error: Volatilidad alta %f", atr);
      return (0);
   }
     
   double effectiveStopLoss = GeneralStopLoss;
   double volatilityFactor = 1.0;
   
   // 1. Ajustar Stop Loss basado en ATR si está activo
   if (atr > 0) {
      double atrInPoints = atr / Point;
      effectiveStopLoss = MathMax(GeneralStopLoss, atrInPoints * LotExponent);
   }
   
   // 2. Ajustar por volatilidad promedio histórica
   if (atr > 0) {
      double avgAtr = 0;
      int lookback = 50;
      for (int i = 1; i <= lookback; i++) {
         avgAtr += iATR(Symbol(), ATR_Timeframe, ATR_Period, i);
      }
      avgAtr /= lookback;
      
      // Reducir lote dinámicamente si la volatilidad instantánea sube mucho
      if (avgAtr > 0) {
         volatilityFactor = avgAtr / atr;
         volatilityFactor = MathMin(volatilityFactor, 2.0);  // Límite máximo 2x
         volatilityFactor = MathMax(volatilityFactor, 0.3);  // Mínimo 0.3x
      }
   }
   
   // Calcular lote final ajustado por riesgo y volatilidad
   lotSize = NormalizeDouble(((Risk / 1000 * balance) / effectiveStopLoss) * volatilityFactor, 5);
   
   // Validar límites de lote permitidos
   lotSize = MathMax(lotSize, Lots);
   lotSize = MathMin(lotSize, MaxLots);
   
//   PrintFormat("Balance: %.2f, Lot: %.5f, ATR: %.5f, SL: %.2f, VolFactor: %.2f", 
  //             balance, lotSize, atr, effectiveStopLoss, volatilityFactor);
   return (lotSize);
}

// Comprobación si la volatilidad es demasiado alta para abrir operaciones
bool isHighVolatility() {
    double atr = iATR(Symbol(), ATR_Timeframe, ATR_Period, 0) / Point;
    return (atr > MaxAllowedATR);
}

// Criterio personalizado de protección de flotante por equidad (Stop Out flotante)
bool CheckStopOutByFloatingLoss(double originalLot, double totalProfit) {
    if (originalLot >= 0.04 && totalProfit <= -4000) return true;
    if (originalLot >= 0.03 && totalProfit <= -2800) return true;
    if (originalLot >= 0.02 && totalProfit <= -2000) return true;
    if (originalLot >= 0.01 && totalProfit <= -1200) return true;
    
    return false;
}

// Calcular tamaño de lote por rangos de balance estáticos
double GetLotBasedOnRange() {
   double balance = AccountBalance();
   double lotSize = 0.0;

   if (balance < 5000) {
      lotSize = 0.01;
   }
   else if (balance >= 5000 && balance < 7000) {
      lotSize = 0.02;
   }
   else if (balance >= 7000 && balance < 10000) {
      lotSize = 0.03;
   }
   else if (balance >= 10000) {
      lotSize = 0.04;
   }
   
//   PrintFormat("balance= %.2f y LotSize= %.5f", balance, lotSize);
   return (lotSize);
}
