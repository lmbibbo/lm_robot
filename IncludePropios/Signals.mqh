//+------------------------------------------------------------------+
//|                                                      Signals.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include "Indicator.mqh"
#include "Defines.mqh"

class Signals
{
private:
   Indicator trend;     // Indicador de tendencia
   Indicator ind_magic; // Indicador mágico
   Indicator tunel;     // Indicador de túnel
   Indicator rsi;       // Indicador RSI
   /*double Ask;          // Precio de compra
   double Bid;          // Precio de venta
   double Spread;       // Diferencia entre ask y bid
   double Point;        // Punto
   double Lot;          // Lote
   double Stoploss;     // Stop loss
   double Takeprofit;   // Take profit
   double Slippage;     // Deslizamiento
   double Magic;        // Número mágico
   double Volume;       // Volumen*/

public:
   Signals();            // Constructor
   ~Signals();           // Destructor
   bool CheckTunel();    // Verifica el túnel
   bool CheckRsi();      // Verifica el RSI
   bool CheckRsiClose(); // Verifica el Close usando RSI
   bool CheckMagic();    // Verifica el indicador mágico
   bool CheckTrend(bool OpenSameDir);

};
//+------------------------------------------------------------------+
//| Constructor                                                                 |
//+------------------------------------------------------------------+
Signals::Signals()
{
   if (trend.init("Linha de tendncia - Marcel Moura"))
   {
      Print("ERROR - Linha de tendncia - Marcel Moura");
   }
   if (ind_magic.init("Indicador Mgico - Marcel Moura"))
   {
      Print("ERROR - Indicador Mgico - Marcel Moura");
   }
   if (rsi.init("RSi - Marcel Moura"))
   {
      Print("ERROR - RSi - Marcel Moura");
   }

   if (tunel.init("Tunel de Vegas - Marcel Moura"))
   {
      Print("ERROR - Tunel de Vegas - Marcel Moura");
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signals::~Signals()
{
}
//+------------------------------------------------------------------+

bool Signals::CheckTrend(bool OpenSameDir )
{
   bool TrendSignal = false;
   // Add your implementation here
   //--- check trend tres positivos
   double trend0 = trend.Value(0);
   double trend1 = trend.Value(1);
   double trend2 = trend.Value(2);

   if (trend0 == EMPTY_VALUE)
   {
      //--- failed to get indicator value, check failed
      return (false);
   }

   if (trend0 == 0 && trend1 == 0 && trend2 == 0 ) // tres ceros en la tendencia indican señal de venta
   {
      if(!OpenSameDir && ExtPrevSignalOpen== SIGNAL_BUY)
         return true;
        
      ExtPatternDetected = true;
      ExtSignalOpen = SIGNAL_SELL;
//      ExtSignalOpen = SIGNAL_SELL_SELL_SELL;
      ExtPatternInfo="\r\nTres valores en 0 de Trend es señal de venta";
      ExtDirection = DIRECTION_SELL;
      ExtSignalClose = CLOSE_LONG;
      return (true);
   }
/*   else if (trend0 == 0 && trend1 == 0)
   {
      ExtPatternDetected = true;
      ExtSignalOpen = SIGNAL_SELL;
//      ExtSignalOpen = SIGNAL_SELL_SELL;
      ExtPatternInfo="\r\nDos valores en 0 de Trend es señal de venta";
      ExtDirection = DIRECTION_SELL;
      return (true);
   }
/*   else if (trend0 == 0)
   {
      ExtPatternDetected = true;
      ExtSignalOpen = SIGNAL_SELL;
      ExtPatternInfo="\r\nUn valor en 0 de Trend es señal de venta";
      ExtDirection = DIRECTION_SELL;
      return (true);
   }*/
   if (trend0 > 0 && trend1 > 0 && trend2 > 0 ) // Dos valores positivos es señal de compra
   {
      if(!OpenSameDir && ExtPrevSignalOpen== SIGNAL_SELL)
         return true;
        
      ExtPatternDetected = true;
      ExtSignalOpen = SIGNAL_BUY;
//      ExtSignalOpen = SIGNAL_BUY_BUY_BUY;
      ExtPatternInfo="\r\nTres valores positivos es señal de compra";
      ExtDirection = DIRECTION_BUY;
      ExtSignalClose = CLOSE_SHORT;
      return (true);
   }
 /*  else if (trend0 > 0 && trend1 > 0) // Dos valores positivos es señal de compra
   {
      ExtPatternDetected = true;
      ExtSignalOpen = SIGNAL_BUY;
//      ExtSignalOpen = SIGNAL_BUY_BUY;
      ExtPatternInfo="\r\nDos valores positivos es señal de compra";
      ExtDirection = DIRECTION_BUY;
      ExtSignalClose = CLOSE_LONG;

      return (true);
   }
  else if (trend0 > 0) // Dos valores positivos es señal de compra
   {
      ExtPatternDetected = true;
      ExtSignalOpen = SIGNAL_BUY;
      ExtPatternInfo="\r\nUn valor positivo es señal de compra";
      ExtDirection = DIRECTION_BUY;
      return (true);
   }*/
   return (TrendSignal);
}

bool Signals::CheckTunel()
{  
   // Implement the logic for checkTunel here
   return true; 
}

bool Signals::CheckRsi()
{
   // Implement the logic for checkRsi here 
   //--- get the value of the stochastic indicator to confirm the signal
  double signal = rsi.Value(0);
  if (signal == EMPTY_VALUE)
  {
    //--- failed to get indicator value, check failed
    return (false);
  }

  //--- check the Buy signal
  if (ExtSignalOpen >= SIGNAL_BUY && (signal > 60))
  {
    ExtConfirmed = true;
    ExtPatternInfo += "\r\n   Confirmed: RSI>60";
  }

  //--- check the Sell signal
  if (ExtSignalOpen <= SIGNAL_SELL && (signal < 40))
  {
    ExtConfirmed = true;
    ExtPatternInfo += "\r\n   Confirmed: RSI<40";
  }

   return ExtConfirmed;
}


bool Signals::CheckRsiClose()
{
   double RSI1 = rsi.Value(0);
   double RSI2 = rsi.Value(1);
  //--- check if there is a signal to close a long position
  if (RSI1 < 60)
  {
    //--- there is a signal to close a long position
    ExtSignalClose = CLOSE_LONG;
    ExtDirection = DIRECTION_BUY;
    return true;
  }

  //--- check if there is a signal to close a short position
  if (RSI1 > 40)
  {
    //--- there is a signal to close a short position
    ExtSignalClose = CLOSE_SHORT;
    ExtDirection = DIRECTION_SELL;
    return true;
  }
  
  return false;
}


bool Signals::CheckMagic()
{
   // Implement the logic for checkMagic here
   return true;
}


