//+------------------------------------------------------------------+
//|                                    BullishBearish Harami RSI.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

input int DialogWidth = 300;  // Dialog width
input int DialogHeight = 200; // Dialog height

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <../IncludePropios/Indicator.mqh>
#include <../IncludePropios/Signals.mqh>
#include <../IncludePropios/Defines.mqh>
#include <../IncludePropios/MiPosition.mqh>
#include <../IncludePropios/MyDialogOperator.mqh>

datetime lastBarTime = 0; // Variable global para almacenar el tiempo de la última barra procesada
Signals miSignal;
MyDialog miDialog;

bool OpenSameDirection= InpOpenSameDirection; // Variable global para almacenar el estado del botón OpenSameDirection
bool AutomaticClose = InpAutomaticClose;
//--- service objects
CTrade ExtTrade;
CSymbolInfo ExtSymbolInfo;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  Print("InpSL=", InpSL);
  Print("InpTP=", InpTP);
  //--- set parameters for trading operations
  ExtTrade.SetDeviationInPoints(InpSlippage);    // slippage
  ExtTrade.SetExpertMagicNumber(InpMagicNumber); // Expert Advisor ID
  ExtTrade.LogLevel(LOG_LEVEL_ERRORS);           // logging level

  ExtAvgBodyPeriod = InpAverBodyPeriod;
  //    int x1 = (int)(chart_width/2 - DialogWidth/2);
  //    int y1 = (int)(chart_height/2 - DialogHeight/2);
  int x1 = 20;
  int y1 = 30;
  int x2 = x1 + DialogWidth;
  int y2 = y1 + DialogHeight;

  // Create the dialog
  if (!miDialog.Create(0, "Operando...", 0, x1, y1, x2, y2))
  {
    Print("Failed to create dialog!");
    return (INIT_FAILED);
  }

  // Make dialog visible
  miDialog.Run();

  miDialog.SetEstado(InpEstado); // Inicializa el estado del botón a "true";
  miDialog.SetAutomaticClose(AutomaticClose); // Inicializa el estado del botón a "true";
  miDialog.SetOpenSameDirection(OpenSameDirection); // Inicializa el estado del botón a "true";
  //--- OK
  //  PrintFormat("@@@ExtSignalOpen@ ExtDirection@ ask@ bid@Open(0)@ High(0)@ Low(0)@ Close(0)@ Magic@@@@@@@@Tunel@@@@@@@@@@@Rsi");
  return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  //--- release indicator handle
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
  //--- controlando del evento
  miDialog.ChartEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  datetime currentBarTime = TimeCurrent();
  
  miDialog.UpdateValues(_Symbol);
  AutomaticClose = miDialog.GetAutomaticClose(); // Actualiza el estado del botón a "true";
  OpenSameDirection = miDialog.GetOpenSameDirection(); // Actualiza el estado del botón a "true";

  if (currentBarTime != lastBarTime && miDialog.GetEstado())
  {
    //--- check if the current bar is different from the last processed bar
    //--- if so, process the new bar
    //--- update the last processed bar time
    //--- and check for a new signal
    //--- if there is a signal, open a position in the direction of the signal
    //--- if there is a signal to close, close the position in the direction of the signal

    //--- update the last processed bar time
    {
      lastBarTime = currentBarTime; // Actualiza la última barra procesada

      //--- Phase 1 - check the emergence of a new bar and update the status
      //--- get the current state of environment on the new bar
      // namely, set the values of global variables:
      // ExtPatternDetected - pattern detection
      // ExtConfirmed - pattern confirmation
      // ExtSignalOpen - signal to open
      // ExtSignalClose - signal to close
      // ExtPatternInfo - current pattern information
      CheckState();

      //--- Phase 2 - if there is a signal and no position in this direction
      if (ExtSignalOpen != 0 && !PositionExist(ExtSignalOpen))
      {
        // Print("Signal to open position ", ExtDirection);

        if (PositionOpen() && PositionExist(ExtSignalOpen))
          ExtSignalOpen = SIGNAL_NOT;
      }

      //--- Phase 3 - close if there is a signal to close
      if (ExtSignalClose != 0 && PositionExist(ExtSignalClose))
      {
        // Print("Signal to close position ", ExtDirection);
        CloseBySignal(ExtSignalClose);
        if (!PositionExist(ExtSignalClose))
          ExtSignalClose = SIGNAL_NOT;
      }

      //--- Phase 4 - close upon expiration
      if (ExtCloseByTime && PositionExpiredByTimeExist())
      {
        CloseByTime();
        ExtCloseByTime = PositionExpiredByTimeExist();
      }
    }
  }
}

//+------------------------------------------------------------------+
//|  Get the current environment and check for a pattern             |
//+------------------------------------------------------------------+
bool CheckState()
{
  //--- check if there is a pattern
  if (!CheckPattern())
  {
    // Print("Error, failed to check pattern");
    return (false);
  }
  //--- check for confirmation
  if (!CheckConfirmation())
  {
    // Print("Error, failed to check pattern confirmation");
    return (false);
  }
  //--- if there is no confirmation, cancel the signal

  if (!ExtConfirmed)
    ExtSignalOpen = SIGNAL_NOT;

  //--- check if there is a signal to close a position
  if (!CheckCloseSignal())
  {
    // Print("Error, failed to check the closing signal");
    return (false);
  }

  CheckSl_Tp();

  //--- if positions are to be closed after certain holding time in bars
  if (InpDuration)
    ExtCloseByTime = true; // set flag to close upon expiration

  //--- all checks done
  return (true);
}
//+------------------------------------------------------------------+
//| Open a position in the direction of the signal                   |
//+------------------------------------------------------------------+
bool PositionOpen()
{
  ExtSymbolInfo.Refresh();
  ExtSymbolInfo.RefreshRates();

  double price = 0;
  //--- Stop Loss and Take Profit are not set by default
  double stoploss = 0.0;
  double takeprofit = 0.0;

  int digits = ExtSymbolInfo.Digits();
  double point = ExtSymbolInfo.Point();
  double spread = ExtSymbolInfo.Ask() - ExtSymbolInfo.Bid();

  double Balance = AccountInfoDouble(ACCOUNT_BALANCE);

  if (spread > InpSread * point)
  {
    PrintFormat("Spread is greater than the allowed value (%d points). Spread = %.0f points", InpSread, spread / point);
    return (false);
  }

  //--- uptrend
  if (ExtSignalOpen >= SIGNAL_BUY)
  {
    price = NormalizeDouble(ExtSymbolInfo.Ask(), digits);
    //--- if Stop Loss is set
    if (InpSL > 0)
    {
      if (spread >= InpSL * point)
      {
        PrintFormat("StopLoss (%d points) <= current spread = %.0f points. Spread value will be used", InpSL, spread / point);
        stoploss = NormalizeDouble(price - spread, digits);
      }
      else
        stoploss = NormalizeDouble(price - InpSL * point, digits);
    }
    //--- if Take Profit is set
    if (InpTP > 0)
    {
      if (spread >= InpTP * point)
      {
        PrintFormat("TakeProfit (%d points) < current spread = %.0f points. Spread value will be used", InpTP, spread / point);
        takeprofit = NormalizeDouble(price + spread, digits);
      }
      else
        takeprofit = NormalizeDouble(price + InpTP * point, digits);
    }

    bool op = ExtTrade.Buy(LotCalculate(InpRisk, stoploss, price, Balance, point), Symbol(), price, stoploss, takeprofit);
    if (op)
    {
      ExtSignalClose = CLOSE_SHORT;
      ExtPrevSignalOpen = SIGNAL_BUY;
    }
    else
    {
      PrintFormat("Failed %s buy %G at %G (sl=%G tp=%G) failed. Ask=%G error=%d",
                  Symbol(), LotCalculate(InpRisk, stoploss, price, Balance, point), price, stoploss, takeprofit, ExtSymbolInfo.Ask(), GetLastError());
      return (false);
    }
  }

  //--- downtrend
  if (ExtSignalOpen <= SIGNAL_SELL)
  {
    price = NormalizeDouble(ExtSymbolInfo.Bid(), digits);
    //--- if Stop Loss is set
    if (InpSL > 0)
    {
      if (spread >= InpSL * point)
      {
        PrintFormat("StopLoss (%d points) <= current spread = %.0f points. Spread value will be used", InpSL, spread / point);
        stoploss = NormalizeDouble(price + spread, digits);
      }
      else
        stoploss = NormalizeDouble(price + InpSL * point, digits);
    }
    //--- if Take Profit is set
    if (InpTP > 0)
    {
      if (spread >= InpTP * point)
      {
        PrintFormat("TakeProfit (%d points) < current spread = %.0f points. Spread value will be used", InpTP, spread / point);
        takeprofit = NormalizeDouble(price - spread, digits);
      }
      else
        takeprofit = NormalizeDouble(price - InpTP * point, digits);
    }

    bool op1 = ExtTrade.Sell(LotCalculate(InpRisk, stoploss, price, Balance, point), Symbol(), price, stoploss, takeprofit);
    if (op1)
    {
      ExtSignalClose = CLOSE_LONG;
      ExtPrevSignalOpen = SIGNAL_SELL;
    }
    else
    {
      PrintFormat("Failed %s sell at %G (sl=%G tp=%G) failed. Bid=%G error=%d",
                  Symbol(), price, stoploss, takeprofit, ExtSymbolInfo.Bid(), GetLastError());
      ExtTrade.PrintResult();
      Print("   ");
      return (false);
    }
  }

  return (true);
}
//+------------------------------------------------------------------+
//|  Close a position based on the specified signal                  |
//+------------------------------------------------------------------+
void CloseBySignal(int type_close)
{
  //--- if there is no signal to close, return successful completion
  if (type_close == SIGNAL_NOT)
    return;
  //--- if there are no positions opened by our EA
  if (PositionExist(ExtSignalClose) == 0)
    return;

  if (!AutomaticClose)
    return;

  //--- closing direction
  long type;
  switch (type_close)
  {
  case CLOSE_SHORT:
    type = POSITION_TYPE_SELL;
    break;
  case CLOSE_LONG:
    type = POSITION_TYPE_BUY;
    break;
  default:
    Print("Error! Signal to close not detected");
    return;
  }

  //--- check all positions and close ours based on the signal
  int positions = PositionsTotal();
  for (int i = positions - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (ticket != 0)
    {
      //--- get the name of the symbol and the position id (magic)
      string symbol = PositionGetString(POSITION_SYMBOL);
      long magic = PositionGetInteger(POSITION_MAGIC);
      //--- if they correspond to our values
      if (symbol == Symbol() && magic == InpMagicNumber)
      {
        datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
        //--- check position holding time in bars
        uint check = BarsHold(open_time);

        if (PositionGetInteger(POSITION_TYPE) == type && check >= InpMantain)
        {
          ExtTrade.PositionClose(ticket, InpSlippage);
          ExtTrade.PrintResult();
        }
      }
    }
  }
}
//+------------------------------------------------------------------+
//|  Close positions upon holding time expiration in bars            |
//+------------------------------------------------------------------+
void CloseByTime()
{
  //--- if there are no positions opened by our EA
  if (PositionExist(ExtSignalOpen) == 0)
    return;

  //--- check all positions and close ours based on the holding time in bars
  int positions = PositionsTotal();
  for (int i = positions - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (ticket != 0)
    {
      //--- get the name of the symbol and the position id (magic)
      string symbol = PositionGetString(POSITION_SYMBOL);
      long magic = PositionGetInteger(POSITION_MAGIC);
      //--- if they correspond to our values
      if (symbol == Symbol() && magic == InpMagicNumber)
      {
        //--- position opening time
        datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
        //--- check position holding time in bars
        if (BarsHold(open_time) >= (int)InpDuration)
        {
          Print("\r\nTime to close position #", ticket);
          ExtTrade.PositionClose(ticket, InpSlippage);
          ExtTrade.PrintResult();
          Print("   ");
        }
      }
    }
  }
}
//+------------------------------------------------------------------+
//| Returns true if there are open positions                         |
//+------------------------------------------------------------------+
bool PositionExist(int signal_direction)
{
  bool check_type = (signal_direction != SIGNAL_NOT);

  //--- what positions to search
  ENUM_POSITION_TYPE search_type = WRONG_VALUE;
  if (check_type)
  {
    if (signal_direction > 0)
    {
      search_type = POSITION_TYPE_BUY;
    }
    else
    {
      search_type = POSITION_TYPE_SELL;
    }
  }
  else
    return false;

  //--- go through the list of all positions
  int positions = PositionsTotal();
  for (int i = 0; i < positions; i++)
  {
    if (PositionGetTicket(i) != 0)
    {
      //--- if the position type does not match, move on to the next one
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if (check_type && (type != search_type))
        continue;
      //--- get the name of the symbol and the expert id (magic number)
      string symbol = PositionGetString(POSITION_SYMBOL);
      long magic = PositionGetInteger(POSITION_MAGIC);
      //--- if they correspond to our values
      if (symbol == Symbol() && magic == InpMagicNumber)
      {
        //--- yes, this is the right position, stop the search
        return (true);
      }
    }
  }

  //--- open position not found
  return (false);
}
//+------------------------------------------------------------------+
//| Returns true if there are open positions with expired time       |
//+------------------------------------------------------------------+
bool PositionExpiredByTimeExist()
{
  //--- go through the list of all positions
  int positions = PositionsTotal();
  for (int i = 0; i < positions; i++)
  {
    if (PositionGetTicket(i) != 0)
    {
      //--- get the name of the symbol and the expert id (magic number)
      string symbol = PositionGetString(POSITION_SYMBOL);
      long magic = PositionGetInteger(POSITION_MAGIC);
      //--- if they correspond to our values
      if (symbol == Symbol() && magic == InpMagicNumber)
      {
        //--- position opening time
        datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
        //--- check position holding time in bars
        int check = BarsHold(open_time);
        //--- id the value is -1, the check completed with an error
        if (check == -1 || (BarsHold(open_time) >= (int)InpDuration))
          return (true);
      }
    }
  }

  //--- open position not found
  return (false);
}
//+------------------------------------------------------------------+
//| Checks position closing time in bars                             |
//+------------------------------------------------------------------+
int BarsHold(datetime open_time)
{
  //--- first run a basic simple check
  if (TimeCurrent() - open_time < PeriodSeconds(_Period))
  {
    //--- opening time is inside the current bar
    return (0);
  }
  //---
  MqlRates bars[];
  if (CopyRates(_Symbol, _Period, open_time, TimeCurrent(), bars) == -1)
  {
    Print("Error. CopyRates() failed, error = ", GetLastError());
    return (-1);
  }
  //--- check position holding time in bars
  return (ArraySize(bars));
}
//+------------------------------------------------------------------+
//| Returns the open price of the specified bar                      |
//+------------------------------------------------------------------+
double Open(int index)
{
  double val = iOpen(_Symbol, _Period, index);
  //--- if the current check state was successful and an error was received
  if (ExtCheckPassed && val == 0)
    ExtCheckPassed = false; // switch the status to failed

  return (val);
}
//+------------------------------------------------------------------+
//| Returns the close price of the specified bar                     |
//+------------------------------------------------------------------+
double Close(int index)
{
  double val = iClose(_Symbol, _Period, index);
  //--- if the current check state was successful and an error was received
  if (ExtCheckPassed && val == 0)
    ExtCheckPassed = false; // switch the status to failed

  return (val);
}
//+------------------------------------------------------------------+
//| Returns the low price of the specified bar                       |
//+------------------------------------------------------------------+
double Low(int index)
{
  double val = iLow(_Symbol, _Period, index);
  //--- if the current check state was successful and an error was received
  if (ExtCheckPassed && val == 0)
    ExtCheckPassed = false; // switch the status to failed

  return (val);
}
//+------------------------------------------------------------------+
//| Returns the high price of the specified bar                      |
//+------------------------------------------------------------------+
double High(int index)
{
  double val = iHigh(_Symbol, _Period, index);
  //--- if the current check state was successful and an error was received
  if (ExtCheckPassed && val == 0)
    ExtCheckPassed = false; // switch the status to failed

  return (val);
}
//+------------------------------------------------------------------+
//| Returns the middle body price for the specified bar              |
//+------------------------------------------------------------------+
double MidPoint(int index)
{
  return (High(index) + Low(index)) / 2.;
}
//+------------------------------------------------------------------+
//| Returns the middle price of the range for the specified bar      |
//+------------------------------------------------------------------+
double MidOpenClose(int index)
{
  return ((Open(index) + Close(index)) / 2.);
}
//+------------------------------------------------------------------+
//| Returns the average candlestick body size for the specified bar  |
//+------------------------------------------------------------------+
double AvgBody(int index)
{
  double sum = 0;
  for (int i = index; i < index + ExtAvgBodyPeriod; i++)
  {
    sum += MathAbs(Open(i) - Close(i));
  }
  return (sum / ExtAvgBodyPeriod);
}
//+------------------------------------------------------------------+
//| Returns true in case of successful pattern check                 |
//+------------------------------------------------------------------+
bool CheckPattern()
{
  ExtPatternDetected = false;
  //--- check if there is a pattern
  ExtSignalOpen = SIGNAL_NOT;
  ExtPatternInfo = "\r\nPattern not detected";
  ExtDirection = DIRECTION_NOT;

  ExtPatternDetected = miSignal.CheckTrend(OpenSameDirection);
  //--- check the all signals
  if (!ExtPatternDetected)
  {
    Print("Error, failed to check the trend");
  }

  //--- result of checking
  return (ExtPatternDetected);
}
//+------------------------------------------------------------------+
//| Returns true in case of successful confirmation check            |
//+------------------------------------------------------------------+
bool CheckConfirmation()
{
  ExtConfirmed = false;
  //--- if there is no pattern, do not search for confirmation
  if (!ExtPatternDetected)
    return (false);

  ExtConfirmed = miSignal.CheckRsi();
  //--- successful completion of the check
  return (ExtConfirmed);
}
//+------------------------------------------------------------------+
//| Check if there is a signal to close                              |
//+------------------------------------------------------------------+
bool CheckCloseSignal()
{
  //--- if there is a signal to enter the market, do not check the signal to close
  int positions = PositionsTotal();
  if (positions == 0)
    return false;

  return miSignal.CheckRsiClose();
}

bool CheckSl_Tp()
{
  //--- closing direction
  ExtSymbolInfo.Refresh();
  ExtSymbolInfo.RefreshRates();

  int digits = ExtSymbolInfo.Digits();
  double point = ExtSymbolInfo.Point();
  double ask = ExtSymbolInfo.Ask();
  double bid = ExtSymbolInfo.Bid();
  double spread = ask - bid;
  double newStopLoss, newTakeProfit;
  /*  long type;
    string typeDesc = "";
    switch (ExtSignalOpen)
    {
    case SIGNAL_SELL:
      type = POSITION_TYPE_SELL;
      typeDesc = "Venta";
      // Para una posición de venta, el SL debe estar por encima del precio actual
      // newStopLoss = ask - InpSL * point;   // puntos por encima del precio actual
      // newTakeProfit = ask - InpTP * point; // puntos por debajo del precio actual
      break;
    case SIGNAL_BUY:
      type = POSITION_TYPE_BUY;
      // Para una posición de compra, el SL debe estar por debajo del precio actual
      typeDesc = "Compra";
     //    newStopLoss = bid + InpTP * point;   // 100 puntos por debajo del precio actual
     //    newTakeProfit = bid + InpSL * point; // 200 puntos por encima del precio actual
      break;
    default:
      Print("Error! Signal to close not detected");
      return false;
    }
  */
  //--- check all positions and close ours based on the signal
  int positions = PositionsTotal();
  MiPosition array_position[];
  ArrayResize(array_position, positions);
  for (int i = 0; i < positions; i++)
  {
    ulong ticket = PositionGetTicket(i);
    if (ticket != 0)
    {
      if (!PositionSelectByTicket(ticket))
      {
        PrintFormat("PositionSelectByTicket(%I64u) failed. Error %d", ticket, GetLastError());
        return false;
      }
      array_position[i].LoadFromTicket(ticket);
    }
  }

  for (ulong i = 0; i < array_position.Size(); i++)
  {
    if (array_position[i].IsOk(Symbol(), InpMagicNumber))
    {
      newStopLoss = array_position[i].GetStopLoss();
      newTakeProfit = array_position[i].GetTakeProfit();
      double price = array_position[i].GetPrice();
      if (array_position[i].GetType() == POSITION_TYPE_BUY)
      {
        if (InpSL > 0)
          newStopLoss = NormalizeDouble(MathMax(newStopLoss, bid - InpSL * point), digits);
        if (InpTP > 0)
          //               newTakeProfit = NormalizeDouble(ask + InpTP * point, digits);
          newTakeProfit = NormalizeDouble(MathMin(newTakeProfit, ask + InpTP * point), digits);
        //               newTakeProfit = NormalizeDouble(MathMin(newTakeProfit, bid + InpTP * point), digits);
      }
      if (array_position[i].GetType() == POSITION_TYPE_SELL)
      {
        if (InpSL > 0)
          newStopLoss = NormalizeDouble(MathMin(newStopLoss, ask + InpSL * point), digits);
        if (InpTP > 0)
          //               newTakeProfit = NormalizeDouble(bid - InpTP * point, digits);
          newTakeProfit = NormalizeDouble(MathMax(newTakeProfit, bid - InpTP * point), digits);
        //               newTakeProfit = NormalizeDouble(MathMax(newTakeProfit, ask - InpTP* point), digits);
      }
      if ((newStopLoss != array_position[i].GetStopLoss()) || (newTakeProfit != array_position[i].GetTakeProfit()))
      {
        if (!ExtTrade.PositionModify(array_position[i].GetTicket(), newStopLoss, newTakeProfit))
        {
          Print("Error al modificar la posición. Código de error: ", ExtTrade.ResultRetcode());
        }
      }
    }
  }

  return true;
}

double LotCalculate(double risk, double stoploss, double price, double balance, double point)
{
  //--- calculate the lot size based on the risk percentage and stop loss in points
  //--- risk - risk percentage of the account balance
  //--- stoploss - stop loss in points
  //--- price - current price of the symbol
  //--- stoploss1 - stop loss in points for the previous position

  if (point <= 0 || (price-stoploss) <= 0)
  {
    Print("Error: point <= 0 or stoploss <= 0");
    return (0);
  }
  
  return (risk * balance) / (10 * MathAbs(price-stoploss) / point);


}