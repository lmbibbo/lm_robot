//+------------------------------------------------------------------+
//|                                              CodigoRefactorizado.mq5 |
//|                    Port MQL4 -> MQL5 de CodigoRefactorizado.mq4   |
//|                                                                  |
//| IMPORTANTE: requiere cuenta con MODO HEDGING (no Netting).       |
//| La martingala abre varias posiciones BUY (o SELL) simultÃ¡neas    |
//| con TP individual; en Netting las posiciones se fusionan.        |
//+------------------------------------------------------------------+
#property copyright "lm_robot"
#property version   "1.00"
#property description "Port MQL5 del CodigoRefactorizado.mq4"

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES DE TRADING                                    |
//+------------------------------------------------------------------+
CTrade trade;
MqlTick tick;

//+------------------------------------------------------------------+
//| PARÃMETROS GENERALES                                             |
//+------------------------------------------------------------------+
input double Lots = 0.01;
input double GeneralStopLoss = 200;
input int    lotdecimal = 5;
input double PipStepATRMultiplier = 2.0;
input double MaxLots = 9.0;
input bool   MM = true;
input double Risk = 1.0;
input double TakeProfit = 80.0;
input bool   UseEquityStop = false;
input double TotalEquityRisk = 20.0;
input double slip = 3.0;

//+------------------------------------------------------------------+
//| CONFIGURACIÃ“N POR ESTRATEGIA                                     |
//+------------------------------------------------------------------+

// --- Fibonacci Focus ---
input string SETT_FIBO = "--- Fibonacci Focus ---";
input int    MaxTrades_Hilo = 20;
input double Risk_Hilo_Input = 1.0;      // 0.5=conservador, 1.0=default, 2.0=agresivo
input int    Magic_Hilo = 10278;
input int    Timeframe_Hilo = PERIOD_M1;
double StopLossPips_Hilo = 40.0;
string Comment_Hilo = "Fibonacci Focus/2019";

// --- Scalper Pro ---
input string SETT_SCALPER = "--- Scalper Pro ---";
input int    MaxTrades_Scalper = 20;
input int    Magic_Scalper = 22324;
input double Risk_Scalper_Input = 1.0;   // 0.5=conservador, 1.0=default, 2.0=agresivo
int Timeframe_Scalper = PERIOD_M1;
string Comment_Scalper = "Scalper Pro/2019";
input bool   UseTimeOut_Scalper = false;
input double TimeOutHours_Scalper = 48.0;

// --- TrendMaster ---
input string SETT_TREND = "--- TrendMaster ---";
input int    MaxTrades_Trend = 20;
input int    Magic_Trend = 23794;
input double Risk_Trend_Input = 1.0;     // 0.5=conservador, 1.0=default, 2.0=agresivo
int Timeframe_Trend = PERIOD_H1;
double StopLossPips_Trend = 40.0;
string Comment_Trend = "TrendMaster/2019";

//+------------------------------------------------------------------+
//| VARIABLES DE ESTADO (compartidas, sin duplicar por estrategia)   |
//+------------------------------------------------------------------+

// RiskMultiplier efectivos en runtime (se sincronizan con la
// GlobalVariable "Risk_Scalper"/"Risk_Hilo"/"Risk_Trend" en OnTick,
// por lo que se pueden ajustar en caliente sin re-adjuntar el EA).
double RiskMultiplier_Scalper = 1.0;
double RiskMultiplier_Hilo = 1.0;
double RiskMultiplier_Trend = 1.0;

// --- ProtecciÃ³n ATR ---
input double MaxAllowedATR = 150.0;
input int    ATR_Period = 14;
input int    ATR_Timeframe = PERIOD_M1;

//+------------------------------------------------------------------+
//| ESTRUCTURA: RESULTADO DEL SCAN DE POSICIONES (1 solo loop)       |
//+------------------------------------------------------------------+
// En lugar de llamar CountTrades + FindLastBuy/FindLastSell +
// calcular avgPrice + calcular profit por separado (cada uno con su
// propio loop), esta estructura almacena TODO en una sola pasada.
struct StrategyState
  {
   int    trades;             // NÂ° de posiciones abiertas
   double avgPrice;           // Precio promedio SIMPLE (Î£ open / N)
   double avgPricePonderado;  // Precio promedio PONDERADO por lotes (Î£ openÃ—lotes / Î£ lotes)
   double totalLots;          // Suma de lotes
   bool   hasBuy;
   bool   hasSell;
   double lastBuyPrice;       // Precio de la Ãºltima compra (mayor ticket)
   double lastSellPrice;      // Precio de la Ãºltima venta (mayor ticket)
   double profit;             // Profit flotante total
   int    lastBuyTicket;
   int    lastSellTicket;
  };

//+------------------------------------------------------------------+
//| Escanea todas las posiciones abiertas del magic indicado y       |
//| llena el StrategyState con: trades, avgPrice, avgPricePonderado, |
//| totalLots, hasBuy/hasSell, lastBuyPrice/lastSellPrice, profit.   |
//| Un solo loop reemplaza CountTrades + FindLastBuy/FindLastSell    |
//| + CalculateProfit + CalculateAvgPrice del cÃ³digo original.       |
//+------------------------------------------------------------------+
void ScanOrders(int magic, StrategyState &st)
  {
   st.trades = 0;
   st.avgPrice = 0;
   st.avgPricePonderado = 0;
   st.totalLots = 0;
   st.hasBuy = false;
   st.hasSell = false;
   st.lastBuyPrice = 0;
   st.lastSellPrice = 0;
   st.profit = 0;
   st.lastBuyTicket = 0;
   st.lastSellTicket = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) == "")
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY || ptype == POSITION_TYPE_SELL)
        {
         st.trades++;
         st.avgPrice += PositionGetDouble(POSITION_PRICE_OPEN);
         st.avgPricePonderado += PositionGetDouble(POSITION_PRICE_OPEN) * PositionGetDouble(POSITION_VOLUME);
         st.totalLots += PositionGetDouble(POSITION_VOLUME);
         st.profit += PositionGetDouble(POSITION_PROFIT);

         if(ptype == POSITION_TYPE_BUY)
           {
            st.hasBuy = true;
            long tk = PositionGetInteger(POSITION_TICKET);
            if(tk > st.lastBuyTicket)
              {
               st.lastBuyTicket = (int)tk;
               st.lastBuyPrice = PositionGetDouble(POSITION_PRICE_OPEN);
              }
           }
         else
            if(ptype == POSITION_TYPE_SELL)
              {
               st.hasSell = true;
               long tk = PositionGetInteger(POSITION_TICKET);
               if(tk > st.lastSellTicket)
                 {
                  st.lastSellTicket = (int)tk;
                  st.lastSellPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                 }
              }
        }
     }

   if(st.trades > 0)
      st.avgPrice = NormalizeDouble(st.avgPrice / st.trades, _Digits);
   if(st.trades > 0 && st.totalLots > 0)
      st.avgPricePonderado = NormalizeDouble(st.avgPricePonderado / st.totalLots, _Digits);
  }

//+------------------------------------------------------------------+
//| FUNCIONES AUXILIARES COMUNES                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| iTime / iClose / GetATR: wrappers MQL5 sobre CopyTime/CopyClose/ |
//| CopyBuffer (MQL5 no tiene iTime()/iClose()/iATR() de MQL4).     |
//+------------------------------------------------------------------+
datetime iTime(string sym, int tf, int shift)
  {
   datetime arr[];
   if(CopyTime(sym, (ENUM_TIMEFRAMES)tf, shift, 1, arr) < 1)
      return (0);
   return (arr[0]);
  }

double iClose(string sym, int tf, int shift)
  {
   double arr[];
   if(CopyClose(sym, (ENUM_TIMEFRAMES)tf, shift, 1, arr) < 1)
      return (0);
   return (arr[0]);
  }

struct ATRCacheItem
  {
   int tf;
   int period;
   int handle;
  };

ATRCacheItem g_atrCache[8];
int g_atrCacheCount = 0;

double GetATR(int tf, int period, int shift)
  {
   int h = INVALID_HANDLE;
   for(int i = 0; i < g_atrCacheCount; i++)
      if(g_atrCache[i].tf == tf && g_atrCache[i].period == period)
        {
         h = g_atrCache[i].handle;
         break;
        }
   if(h == INVALID_HANDLE && g_atrCacheCount < 8)
     {
      h = iATR(_Symbol, (ENUM_TIMEFRAMES)tf, period);
      g_atrCache[g_atrCacheCount].tf = tf;
      g_atrCache[g_atrCacheCount].period = period;
      g_atrCache[g_atrCacheCount].handle = h;
      g_atrCacheCount++;
     }
   if(h == INVALID_HANDLE)
      return (0);
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(h, 0, shift, 1, buf) < 1)
      return (0);
   return (buf[0]);
  }

//+------------------------------------------------------------------+
//| Retorna el LotExponent segÃºn timeframe (tabla fija).             |
//| Timeframes cortos â†’ exponente bajo, largos â†’ exponente alto.     |
//| Ajusta por riskMultiplier: a mayor riesgo, mayor exponente.      |
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
   return (NormalizeDouble(MathMax(1.01, base * r), 4));
  }

//+------------------------------------------------------------------+
//| Calcula PipStep dinÃ¡mico basado en ATR del timeframe indicado.   |
//| PipStep = ATR_en_puntos * PipStepATRMultiplier.                  |
//| Ajusta por riskMultiplier: a mayor riesgo, menor PipStep.        |
//| MÃ­nimo 10 puntos para evitar grids demasiado densos.             |
//+------------------------------------------------------------------+
double GetPipStepByTimeframe(int tf, double riskMultiplier)
  {
   double atr = GetATR(tf, 14, 0);
   double pipStep = MathMax(10, atr / _Point * PipStepATRMultiplier);
   double r = MathMax(0.5, MathMin(2.0, riskMultiplier));
   return (NormalizeDouble(pipStep / r, 1));
  }

//+------------------------------------------------------------------+
//| Retorna TakeProfit en puntos segÃºn timeframe (tabla fija).       |
//| Timeframes cortos â†’ TP ajustado, largos â†’ TP amplio.            |
//+------------------------------------------------------------------+
int GetTakeProfitByTimeframe(int tf)
  {
   switch(tf)
     {
      case PERIOD_M1:
         return (30);
      case PERIOD_M5:
         return (50);
      case PERIOD_M15:
         return (70);
      case PERIOD_M30:
         return (80);
      case PERIOD_H1:
         return (100);
      case PERIOD_H4:
         return (150);
      case PERIOD_D1:
         return (300);
      default:
         return (80);
     }
  }

// Contar posiciones de Fibonacci Focus (para panel visual)
int CountTrades_Hilo()
  {
   int count = 0;
   for(int pos = PositionsTotal() - 1; pos >= 0; pos--)
     {
      if(PositionGetSymbol(pos) == "")
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != Magic_Hilo)
         continue;
      long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY || ptype == POSITION_TYPE_SELL)
         count++;
     }
   return (count);
  }

// Contar posiciones de Scalper Pro (para panel visual)
int CountTrades_Scalper()
  {
   int count = 0;
   for(int pos = PositionsTotal() - 1; pos >= 0; pos--)
     {
      if(PositionGetSymbol(pos) == "")
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != Magic_Scalper)
         continue;
      long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY || ptype == POSITION_TYPE_SELL)
         count++;
     }
   return (count);
  }

// Contar posiciones de TrendMaster (para panel visual)
int CountTrades_Trend()
  {
   int count = 0;
   for(int pos = PositionsTotal() - 1; pos >= 0; pos--)
     {
      if(PositionGetSymbol(pos) == "")
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != Magic_Trend)
         continue;
      long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY || ptype == POSITION_TYPE_SELL)
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
      case PERIOD_M1:
         return ("M1");
      case PERIOD_M5:
         return ("M5");
      case PERIOD_M15:
         return ("M15");
      case PERIOD_M30:
         return ("M30");
      case PERIOD_H1:
         return ("H1");
      case PERIOD_H4:
         return ("H4");
      case PERIOD_D1:
         return ("D1");
      case PERIOD_W1:
         return ("W1");
      default:
         return ("?");
     }
  }

//+------------------------------------------------------------------+
//| Retorna TRUE si el ATR actual supera MaxAllowedATR.             |
//| Se usa en GetLotSizeBasedOnBalance para reducir lote en alta     |
//| volatilidad.                                                     |
//+------------------------------------------------------------------+
bool isHighVolatility()
  {
   double atr = GetATR(ATR_Timeframe, ATR_Period, 0) / _Point;
   return (atr > MaxAllowedATR);
  }

//+------------------------------------------------------------------+
//| Cierra todas las posiciones abiertas del magic number indicado.  |
//| Recorre de atrÃ¡s hacia adelante para evitar problemas de         |
//| Ã­ndice al cerrar.                                                |
//+------------------------------------------------------------------+
void CloseAllOrders(int magic)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) == "")
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(!trade.PositionClose((ulong)PositionGetInteger(POSITION_TICKET), (ulong)slip))
         Print("CloseAllOrders: error ", trade.ResultRetcode());
      Sleep(1000);
     }
  }

//+------------------------------------------------------------------+
//| EnvÃ­a una orden de mercado (0=BUY, 1=SELL). Reintenta hasta     |
//| 100 veces si el broker devuelve errores de conexiÃ³n.            |
//| Retorna ticket o 0 si falla.                                     |
//| Abre con TP por orden (como EXPERIMENTAL: TakeLong/TakeShort     |
//| relativo al precio del momento) â†’ el TP del open siempre es       |
//| vÃ¡lido para el broker.                                           |
//+------------------------------------------------------------------+
int SendOrder(int type, double lots, string comment, int magic, color arrow, double tpDist)
  {
   // arrow se conserva por paridad con MQL4 (MQL5 no usa flechas)
   for(int retry = 0; retry < 100; retry++)
     {
      SymbolInfoTick(_Symbol, tick);
      trade.SetExpertMagicNumber(magic);
      trade.SetDeviationInPoints((ulong)slip);
      double tp_open = 0;
      bool ok = false;
      if(type == 0)  // BUY
        {
         tp_open = tick.ask + tpDist * _Point;
         ok = trade.Buy(lots, _Symbol, tick.ask, 0.0, tp_open, comment);
        }
      else            // SELL
        {
         tp_open = tick.bid - tpDist * _Point;
         ok = trade.Sell(lots, _Symbol, tick.bid, 0.0, tp_open, comment);
        }

      if(ok)
         return ((int)trade.ResultOrder());

      int err = (int)trade.ResultRetcode();
      bool transient = (err == TRADE_RETCODE_REQUOTE ||
                        err == TRADE_RETCODE_PRICE_CHANGED ||
                        err == TRADE_RETCODE_TIMEOUT ||
                        err == TRADE_RETCODE_CONNECTION ||
                        err == TRADE_RETCODE_PRICE_OFF ||
                        err == TRADE_RETCODE_LOCKED);
      if(!transient)
        {
         Print("SendOrder error ", err, " type=", type, " lots=", lots);
         break;
        }
      Sleep(5000);
     }
   return (0);
  }

//+------------------------------------------------------------------+
//| Modifica SOLO el TakeProfit de una posiciÃ³n. VersiÃ³n minimalista |
//| igual que CÃ³digoOriginal / THE_ALGORITHM_PRO_EXPERIMENTAL.       |
//| SL se conserva, reintento con Sleep(1000) + tick fresco.         |
//+------------------------------------------------------------------+
void SetTakeProfit(int ticket, double tp)
  {
   if(!PositionSelectByTicket(ticket))
     {
      Print("SetTakeProfit: ticket no encontrado ", ticket);
      return;
     }
   while(!trade.PositionModify((ulong)ticket, PositionGetDouble(POSITION_SL), tp))
     {
      Sleep(1000);
      SymbolInfoTick(_Symbol, tick);
     }
  }

//+------------------------------------------------------------------+
//| FUNCIONES DE GESTIÃ“N DE RIESGO Y MM                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Retorna TRUE si la pÃ©rdida flotante total supera umbrales        |
//| definidos segÃºn el lote original. Medida de protecciÃ³n contra    |
//| pÃ©rdidas excesivas.                                              |
//+------------------------------------------------------------------+
bool CheckStopOutByFloatingLoss(double originalLot, double totalProfit)
  {
   if(originalLot >= 0.04 && totalProfit <= -4000)
      return (true);
   if(originalLot >= 0.03 && totalProfit <= -2800)
      return (true);
   if(originalLot >= 0.02 && totalProfit <= -2000)
      return (true);
   if(originalLot >= 0.01 && totalProfit <= -1200)
      return (true);
   return (false);
  }

//+------------------------------------------------------------------+
//| Calcula el lote Ã³ptimo segÃºn AccountBalance y Risk%.            |
//| Incluye ajuste por volatilidad (ATR): si el ATR actual es       |
//| mayor que el promedio, reduce el lote (y viceversa).            |
//| Si la volatilidad supera MaxAllowedATR, retorna 0 (no opera).   |
//| Usa GetLotExponentByTimeframe(tf, riskMultiplier) en vez del    |
//| LotExponent fijo de los inputs.                                 |
//+------------------------------------------------------------------+
double GetLotSizeBasedOnBalance(int tf, double riskMultiplier)
  {
   if(_Point <= 0)
      return (0);
   if(isHighVolatility())
     {
      Print("GetLotSize: Volatilidad alta, lote=0");
      return (0);
     }
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double atr = GetATR(ATR_Timeframe, ATR_Period, 0);
   double stopLoss = GeneralStopLoss;

   if(atr > 0)
     {
      double atrPoints = atr / _Point;
      stopLoss = MathMax(GeneralStopLoss, atrPoints * GetLotExponentByTimeframe(tf, riskMultiplier));
     }
   double lot = NormalizeDouble((Risk / 1000.0 * balance) / stopLoss, 5);
   if(atr > 0)
     {
      double avgAtr = 0;
      for(int i = 1; i <= 50; i++)
         avgAtr += GetATR(ATR_Timeframe, ATR_Period, i);
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
//| Calcula lote fijo segÃºn rango de balance (sin MM).              |
//| balance < 5000 â†’ 0.01, < 7000 â†’ 0.02, < 10000 â†’ 0.03,           |
//| >= 10000 â†’ 0.04.                                                 |
//+------------------------------------------------------------------+
double GetLotBasedOnRange()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance < 5000)
      return (0.01);
   if(balance < 7000)
      return (0.02);
   if(balance < 10000)
      return (0.03);
   return (0.04);
  }

//+------------------------------------------------------------------+
//| Crea una etiqueta OBJ_LABEL en el panel y avanza el cursor Y.   |
//+------------------------------------------------------------------+
void PanelLabel(string name, string text, int &y, int s, color clr)
  {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_CORNER, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   y += s;
  }

//+------------------------------------------------------------------+
//| Dibuja el panel informativo con OBJ_LABEL. Se llama desde        |
//| OnInit() (para que aparezca al adjuntar el EA aunque no haya     |
//| ticks) y desde OnTick() para actualizar valores en cada tick.    |
//+------------------------------------------------------------------+
void DrawPanel()
  {
// Mercado abierto = terminal permite operar Y se siguen formando
// barras M1 (si la Ãºltima barra tiene mÃ¡s de 5 min, estÃ¡ cerrado).
   bool marketOpen = (MQLInfoInteger(MQL_TRADE_ALLOWED) > 0 &&
                      TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) > 0);
   if(marketOpen && TimeCurrent() - iTime(_Symbol, PERIOD_M1, 0) > 300)
      marketOpen = false;
   string status = marketOpen ? "ABIERTO" : "CERRADO";
   color clr = marketOpen ? Lime : Red;

   ObjectsDeleteAll(0, "panel_");
   int y = 10, s = 18;
   PanelLabel("panel_h1", "___________________________________________________", y, s, White);
   PanelLabel("panel_broker", "Broker                     : " + AccountInfoString(ACCOUNT_COMPANY), y, s, White);
   PanelLabel("panel_time", "Time                        : " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), y, s, White);
   PanelLabel("panel_market", "Market                    : " + status, y, s, clr);
   PanelLabel("panel_spread", "Spread                     : " + IntegerToString(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)), y, s, White);
   PanelLabel("panel_h2", "___________________________________________________", y, s, White);
   PanelLabel("panel_name", "Name                       : " + AccountInfoString(ACCOUNT_NAME), y, s, White);
   PanelLabel("panel_acc", "Account                    : " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)), y, s, White);
   PanelLabel("panel_cur", "Currency                   : " + AccountInfoString(ACCOUNT_CURRENCY), y, s, White);
   PanelLabel("panel_h3", "___________________________________________________", y, s, White);
   PanelLabel("panel_scalper", "Scalper Pro [" + TfToString(Timeframe_Scalper) + "] : " + IntegerToString(CountTrades_Scalper()), y, s, White);
   int atr14Pts = (int)(GetATR(Timeframe_Scalper, 14, 0) / _Point);
   PanelLabel("panel_risk", "RiskScalper  [" + TfToString(Timeframe_Scalper) + "]: " + DoubleToString(RiskMultiplier_Scalper, 2), y, s, White);
   PanelLabel("panel_pipstep", "PipStep      [" + TfToString(Timeframe_Scalper) + "]: " + DoubleToString(GetPipStepByTimeframe(Timeframe_Scalper, RiskMultiplier_Scalper), 1) + " pts", y, s, White);
   PanelLabel("panel_lotexp", "LotExponent  [" + TfToString(Timeframe_Scalper) + "]: " + DoubleToString(GetLotExponentByTimeframe(Timeframe_Scalper, RiskMultiplier_Scalper), 3), y, s, White);
   PanelLabel("panel_tp", "TakeProfit   [" + TfToString(Timeframe_Scalper) + "]: " + IntegerToString(GetTakeProfitByTimeframe(Timeframe_Scalper)) + " pts", y, s, White);
   PanelLabel("panel_atr", "ATR(14)      [" + TfToString(Timeframe_Scalper) + "]: " + DoubleToString(GetATR(Timeframe_Scalper, 14, 0), _Digits) + " (" + IntegerToString(atr14Pts) + " pts)", y, s, White);
   PanelLabel("panel_fibo", "Fibonacci Focus [" + TfToString(Timeframe_Hilo) + "] : " + IntegerToString(CountTrades_Hilo()), y, s, White);
   PanelLabel("panel_trend", "TrendMaster [" + TfToString(Timeframe_Trend) + "] : " + IntegerToString(CountTrades_Trend()), y, s, White);
   PanelLabel("panel_all", "ALL ORDERS                   : " + IntegerToString(PositionsTotal()), y, s, White);
   PanelLabel("panel_h4", "___________________________________________________", y, s, White);
   PanelLabel("panel_bal", "BALANCE                    : " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2), y, s, White);
   PanelLabel("panel_eq", "EQUITY                       : " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2), y, s, White);
   PanelLabel("panel_h5", "___________________________________________________", y, s, White);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| OnInit()                                                          |
//+------------------------------------------------------------------+
int OnInit()
  {
// Sincronizar RiskMultiplier de runtime con los inputs y con las
// GlobalVariables (si el usuario ya las creÃ³, se respeta su valor).
   RiskMultiplier_Scalper = Risk_Scalper_Input;
   RiskMultiplier_Hilo = Risk_Hilo_Input;
   RiskMultiplier_Trend = Risk_Trend_Input;
   if(!GlobalVariableCheck("Risk_Hilo"))
      GlobalVariableSet("Risk_Hilo", RiskMultiplier_Hilo);
   if(!GlobalVariableCheck("Risk_Scalper"))
      GlobalVariableSet("Risk_Scalper", RiskMultiplier_Scalper);
   if(!GlobalVariableCheck("Risk_Trend"))
      GlobalVariableSet("Risk_Trend", RiskMultiplier_Trend);

   DrawPanel();
   PrintFormat("Market check: tradeAllowed=%d now=%s lastM1=%s diffSec=%d",
               MQLInfoInteger(MQL_TRADE_ALLOWED),
               TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
               TimeToString(iTime(_Symbol, PERIOD_M1, 0), TIME_DATE|TIME_SECONDS),
               TimeCurrent() - iTime(_Symbol, PERIOD_M1, 0));
   return (INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit()                                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "panel_");
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

// 4. Escanear Ã³rdenes UNA vez
// StrategyState st;
// ScanOrders(Magic_Hilo, st);

// 5. Si hay trades, verificar grid (PipStep)

// 6. Si no hay trades, decidir direcciÃ³n y abrir primera orden

// 7. Si se abriÃ³ orden, calcular SL/TP sobre avgPrice y modificar

// 8. Coverage: asegurar TP en todas las Ã³rdenes

// (detalles se completarÃ¡n en la implementaciÃ³n final)
  }

//+------------------------------------------------------------------+
//| ESTRATEGIA 2: SCALPER PRO                                        |
//| Grid unidireccional con apertura por cambio de barra.           |
//| - Primer trade: direcciÃ³n segÃºn iClose[2] vs iClose[1]          |
//| - Trades siguientes: cuando PipStep se alcanza                   |
//| - SL/TP se asignan vÃ­a SetTakeProfit con OrderOpenPrice() como     |
//|   precio (no altera precio de apertura)                         |
//| - Coverage (lÃ­neas finales): actualiza TP de TODAS las Ã³rdenes  |
//|   al avgPrice actual cada tick                                   |
//+------------------------------------------------------------------+
void RunScalperPro()
  {
   static datetime s_lastBar = 0;
   static datetime s_lastBarTrigger = 0;
   static bool s_orderSent = false;
   static datetime s_timeLimit = 0;
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
      s_orderSent = false;
      s_timeLimit = 0;
     }

   datetime chartBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(s_lastBar != chartBar)
     {
      s_lastBar = chartBar;

      if(UseEquityStop && st.trades > 0 && CheckStopOutByFloatingLoss(lotSize, st.profit))
        {
         CloseAllOrders(Magic_Scalper);
         s_orderSent = false;
         return;
        }

      //============================================================//
      // [MARTINGALA] NUEVA ORDEN â€” grid por PipStep                 //
      // Se aÃ±ade UNA orden mÃ¡s al grid SOLO si ya existen trades    //
      // (st.trades > 0) y el precio se alejÃ³ PipStep del Ãºltimo     //
      // trade. Este bloque NUNCA abre la primera orden.             //
      //============================================================//
      bool canOpen = false;
      if(st.trades > 0 && st.trades <= MaxTrades_Scalper)
        {
         SymbolInfoTick(_Symbol, tick);
         if(st.hasBuy && st.lastBuyPrice - tick.ask >= GetPipStepByTimeframe(Timeframe_Scalper, RiskMultiplier_Scalper) * _Point)
            canOpen = true;
         if(st.hasSell && tick.bid - st.lastSellPrice >= GetPipStepByTimeframe(Timeframe_Scalper, RiskMultiplier_Scalper) * _Point)
            canOpen = true;
        }

      if(canOpen)
        {
         double nextLot = NormalizeDouble(lotSize * MathPow(GetLotExponentByTimeframe(Timeframe_Scalper, RiskMultiplier_Scalper), st.trades), lotdecimal);
         if(st.hasSell)
           {
            g_ticket = SendOrder(1, nextLot, Comment_Scalper + "-" + IntegerToString(st.trades), Magic_Scalper, HotPink, GetTakeProfitByTimeframe(Timeframe_Scalper)); // [MARTINGALA] nueva orden SELL (PipStep)
           }
         else
            if(st.hasBuy)
              {
               g_ticket = SendOrder(0, nextLot, Comment_Scalper + "-" + IntegerToString(st.trades), Magic_Scalper, Lime, GetTakeProfitByTimeframe(Timeframe_Scalper)); // [MARTINGALA] nueva orden BUY (PipStep)
              }
         if(g_ticket > 0)
           {
            s_orderSent = true;
            if(UseTimeOut_Scalper)
               s_timeLimit = TimeCurrent() + (int)(3600 * TimeOutHours_Scalper);
           }
        }
     }

//============================================================//
// [MARTINGALA] PRIMERA ORDEN â€” Ãºnico punto de entrada inicial //
// Se abre SOLO cuando NO hay trades (st.trades < 1), en la    //
// nueva barra del timeframe de la estrategia.                 //
//============================================================//
   datetime currentBarScalper = iTime(_Symbol, Timeframe_Scalper, 0);
   if(s_lastBarTrigger != currentBarScalper)
     {
      s_lastBarTrigger = currentBarScalper;
      if(st.trades < 1)
        {
         g_close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
         g_close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
         if(g_close2 > g_close1)
            g_ticket = SendOrder(1, lotSize, Comment_Scalper + "-0", Magic_Scalper, HotPink, GetTakeProfitByTimeframe(Timeframe_Scalper)); // [MARTINGALA] PRIMERA orden SELL
         else
            g_ticket = SendOrder(0, lotSize, Comment_Scalper + "-0", Magic_Scalper, Lime, GetTakeProfitByTimeframe(Timeframe_Scalper)); // [MARTINGALA] PRIMERA orden BUY
         if(g_ticket > 0)
           {
            s_orderSent = true;
            if(UseTimeOut_Scalper)
               s_timeLimit = TimeCurrent() + (int)(3600 * TimeOutHours_Scalper);
           }
        }
     }

   ScanOrders(Magic_Scalper, st);

//============================================================//
// [COVERAGE] Mantenimiento del TP â€” SOLO se ejecuta el tick   //
// en que se abriÃ³ una orden nueva (s_orderSent = gi_588 del   //
// experimental, one-shot). Realinea el TP de TODAS las        //
// posiciones Scalper al objetivo del basket:                  //
//   tpc = avgPricePonderado Â± TP*Point                        //
// avgPricePonderado es ponderado por LOTES (Î£ openÃ—lotes/Î£l): //
// asegura que al cerrar todo el basket en ese TP, la ganancia //
// de la Ãºltima orden (la mÃ¡s grande) cubra las pÃ©rdidas de    //
// las anteriores (TP â‰¥ breakeven ponderado).                  //
// SOLO se protege el mÃ­nimo: si el target queda bajo el       //
// precio actual + stopLevel, se clampa a Ask+stl / Bid-stl.   //
//============================================================//
   if(s_orderSent && st.trades > 0 && GetTakeProfitByTimeframe(Timeframe_Scalper) > 0)
     {
      double stl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
      for(int pos = PositionsTotal() - 1; pos >= 0; pos--)
        {
         if(PositionGetSymbol(pos) == "")
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
            PositionGetInteger(POSITION_MAGIC) != Magic_Scalper)
            continue;
         SymbolInfoTick(_Symbol, tick);
         double tpc = 0;
         bool clamped = false;
         long ptype = PositionGetInteger(POSITION_TYPE);
         if(ptype == POSITION_TYPE_BUY)
           {
            tpc = st.avgPricePonderado + GetTakeProfitByTimeframe(Timeframe_Scalper) * _Point;
            if(tpc < tick.ask + stl)
              {
               tpc = tick.ask + stl;
               clamped = true;
              }
           }
         else
            if(ptype == POSITION_TYPE_SELL)
              {
               tpc = st.avgPricePonderado - GetTakeProfitByTimeframe(Timeframe_Scalper) * _Point;
               if(tpc > tick.bid - stl)
                 {
                  tpc = tick.bid - stl;
                  clamped = true;
                 }
              }
            else
               continue;
         if(tpc > 0 && MathAbs(PositionGetDouble(POSITION_TP) - tpc) > _Point / 2)
           {
            bool modOK = trade.PositionModify((ulong)PositionGetInteger(POSITION_TICKET),
                                              PositionGetDouble(POSITION_SL),
                                              NormalizeDouble(tpc, _Digits));
            PrintFormat("Scalper coverage TP -> ticket=%d type=%s Price=%.6f SL=%.6f avgPrice=%.6f avgPond=%.6f oldTP=%.6f newTP=%.6f Ask=%.6f Bid=%.6f clamp=%d result=%d",
                        PositionGetInteger(POSITION_TICKET), (ptype == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                        PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_SL),
                        st.avgPrice, st.avgPricePonderado,
                        PositionGetDouble(POSITION_TP), tpc, tick.ask, tick.bid, clamped, modOK);
            if(!modOK)
               Print("Error in PositionModify. Error code=", trade.ResultRetcode());
            else
               Print("Position modified successfully.");
           }
        }
      s_orderSent = false;
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
// - ScanOrders(Magic_Trend, st)   â† un solo loop
// - Grid: verificar PipStep si hay trades
// - Primer trade: decidir direcciÃ³n + RSI filter
// - SL/TP sobre avgPrice y modificar

  }

//+------------------------------------------------------------------+
//| OnTick() â€” Punto de entrada principal del EA.                   |
//| Muestra panel informativo en pantalla y ejecuta las estrategias. |
//+------------------------------------------------------------------+
void OnTick()
  {
// Leer los RiskMultiplier desde GlobalVariables (se pueden ajustar en
// caliente desde el terminal). Si la GV no existe, se usa el input.
   if(GlobalVariableCheck("Risk_Scalper"))
      RiskMultiplier_Scalper = GlobalVariableGet("Risk_Scalper");
   if(GlobalVariableCheck("Risk_Hilo"))
      RiskMultiplier_Hilo = GlobalVariableGet("Risk_Hilo");
   if(GlobalVariableCheck("Risk_Trend"))
      RiskMultiplier_Trend = GlobalVariableGet("Risk_Trend");

   DrawPanel();

   RunScalperPro();
  }
