#include <Trade/Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Propios\Indicator.mqh>

#define SIGNAL_BUY    1             // Buy signal
#define SIGNAL_NOT    0             // no trading signal
#define SIGNAL_SELL  -1             // Sell signal

CTrade ExtTrade;
CSymbolInfo ExtSymbolInfo;

input uint InpSL      =300;         // Stop Loss in points
input uint InpTP      =200;         // Take Profit in points
input double InpLot     = 0.01;      // Lote como procentaje del Balance

Indicator tunel;
Indicator trend;
Indicator rsi;
Indicator setas;
Indicator ind_magic;
int buffer_num;
double trend_signal_ant[];

int signal = SIGNAL_NOT;
int signal_ant = SIGNAL_NOT;

int OnInit() {
   
 
    if (ind_magic.init("Indicador Mgico - Marcel Moura")) {
        Print("ERROR - Indicador Mgico - Marcel Moura");
        return(INIT_FAILED);
    }
    
   
    if (trend.init("Linha de tendncia - Marcel Moura")) {
        Print("ERROR - Linha de tendncia - Marcel Moura");
        return(INIT_FAILED);
    }
    
 /*   if (setas.init("Parmetros de entrada - setas - Marcel Moura")) {
        Print("ERROR - Parmetros de entrada - setas - Marcel Moura");
        return(INIT_FAILED);
    }    */
    
    if (rsi.init("RSi - Marcel Moura")) {
        Print("ERROR - RSi - Marcel Moura");
        return(INIT_FAILED);
    }
          
    if (tunel.init("Tunel de Vegas - Marcel Moura")){
        Print("ERROR - Tunel de Vegas - Marcel Moura");
        return(INIT_FAILED);
    }
    
    return(INIT_SUCCEEDED);
}

void OnTick() {
    
    double ind_magic_signal[];
    ArraySetAsSeries(ind_magic_signal, true);
    double trend_signal[];
    ArraySetAsSeries(trend_signal, true);

    ArraySetAsSeries(trend_signal_ant, true);
    double setas_signal[];
    ArraySetAsSeries(setas_signal, true);
    double rsi_signal[];
    ArraySetAsSeries(rsi_signal, true);
    double actual_trend;
    double tren_ant=-1;
 
    string salida = "@" +trend.getName();
    // Copiar los valores del buffer del indicador al array
    
    ArrayResize(trend_signal, trend.getBuffer_num());
    for(int i=0;i<trend.getBuffer_num();i++)
    {
       double signaly[];
       int copied = CopyBuffer(trend.getHandle(), i, 0, 1, signaly); // Intentar copiar 1 valor
       trend_signal[i]=signaly[0];
    }
  
    if(!CompareDoubleArrays(trend_signal, trend_signal_ant))
    {
         int s1=ArraySize(trend_signal);
            if(s1 == 0) {
               Print("Error: Trend signal vacío! ");
            }
         imprimir(trend.getName(), trend_signal);
         // Definir el array de destino con el mismo tamaño
         
         if(ArraySize(trend_signal_ant)>0)
         {
             actual_trend = trend_signal[0];
             tren_ant = trend_signal_ant[0];
             if(tren_ant > 0 && actual_trend > 0){
                 Print("!Deberíamos Comprar!   Signal_ant: ", signal_ant);
                 signal=SIGNAL_BUY;    
                 if(signal_ant != SIGNAL_BUY)
                   {
                       //closePositions();
                       if (!operar(signal))
                       {
                           Print("Falló la compra");
                       }
                       signal_ant=SIGNAL_BUY;
                   }
             } 
             if(actual_trend == 0 && tren_ant== 0) {
                 Print("!Deberíamos vender!  Signal_ant: ", signal_ant );
                 signal=SIGNAL_SELL; 
                 if(signal_ant != SIGNAL_SELL)
                   {
                       //closePositions();
                       if (!operar(signal))
                       {
                           Print("Falló la venta");
                       }               
                       signal_ant = SIGNAL_SELL;
                   }
              }
         }             
         ArrayResize(trend_signal_ant, ArraySize(trend_signal));
         // Copiar los elementos del array de origen al array de destino
         int elementosCopiados = ArrayCopy(trend_signal_ant, trend_signal);
    }

    salida = "@" +tunel.getName();
    for(int i=0;i<tunel.getBuffer_num();i++)
        {
          double signal_array[];
          int copied = CopyBuffer(tunel.getHandle(), i, 0, 1, signal_array); // Intentar copiar 1 valor
          salida= salida + "@" + IntegerToString(i) + "@" + DoubleToString(signal_array[0]);
        }

 //     Print(salida);
    salida = "@" +rsi.getName();

    for(int i=0;i<rsi.getBuffer_num();i++)
        {
          double signalu[];
          int copied = CopyBuffer(tunel.getHandle(), i, 0, 1, signalu); // Intentar copiar 1 valor
          salida= salida + "@" + IntegerToString(i) + "@" + DoubleToString(signalu[0]);
        }

   //   Print(salida);
      /*salida = setas.getName();
   
      for(int i=0;i<setas.getBuffer_num();i++)
        {
          double signal[];
          int copied = CopyBuffer(setas.getHandle(), i, 0, 1, signal); // Intentar copiar 1 valor
          salida= salida + "@" + IntegerToString(i) + "@" + DoubleToString(signal[0]);
        }

      Print(salida);*/
      salida = "@" +ind_magic.getName();
   
      for(int i=0;i<ind_magic.getBuffer_num();i++)
        {
          double signale[];
          int copied = CopyBuffer(ind_magic.getHandle(), i, 0, 1, signale); // Intentar copiar 1 valor
          salida= salida + "@" + IntegerToString(i) + "@" + DoubleToString(signale[0]);
        }
   
   
    /*       
    if(actual_trend!= tren_ant ) {
      //Print("Indicador Mgico: ", ind_magic_signal[0]);
      Print("Linha de tendncia: ", actual_trend, "    Anterior: ", tren_ant);
      // Print("Parmetros de entrada - setas: ", setas_signal[0]);
      //Print("RSi: ", rsi_signal[0]);
 
      if(actual_trend == 0 && tren_ant!=-1) {
         Print("Deberíamos vender!");
      }
      else{ 
         if(tren_ant == 0){
            Print("Deberíamos Comprar");
         }     
      }
      tren_ant = actual_trend;   
      
    }
    // Recorrer el array e imprimir los valores
   if (tunel_signal[0] == 1 && PositionsTotal() == 0) { // Buy signal
        double sl = SymbolInfoDouble(_Symbol, SYMBOL_BID) - 50 * _Point;
        double tp = SymbolInfoDouble(_Symbol, SYMBOL_BID) + 100 * _Point;
        trade.Buy(0.1, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), sl, tp, "lm_Ex5 Robot Buy");
    }
    else if (tunel_signal[0] == -1 && PositionsTotal() == 0) { // Sell signal
        double sl = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + 50 * _Point;
        double tp = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - 100 * _Point;
        trade.Sell(0.1, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), sl, tp, "Ex5 Robot Sell");
    }*/
}

bool CompareDoubleArrays(const double &array1[], const double &array2[], double tolerance = 1e-4)
{
    // Verificar si los arrays tienen el mismo tamaño
    int s1=ArraySize(array1);
    int s2=ArraySize(array2);
    
    if (s1 != s2)
    {
       Print("S1: ", s1, "S2: ", s2);
       return false;
    }

    if (s1 == 0) {
      return false;
    }
    // Comparar los valores de los arrays
    for (int i = 0; i < 4; i++)
    {
        if (MathAbs(array1[i] - array2[i]) > tolerance)
        {
            return false;
        }
    }
    // Si no se encontraron diferencias
    return true;
}

void imprimir(string name, const double &array[])
{
   string salida = "@" +name;
   
   int s1=ArraySize(array);
   if(s1 == 0) {
      salida = salida + "Caca... Nada para imprimir";
   }
   
   for(int i=0;i<ArraySize(array);i++)
   {
      salida= salida + "@" + IntegerToString(i) + "@" + DoubleToString(array[i]);
   }
   
   Print(salida);
   
}

bool operar(int operaci)
  {
   ExtSymbolInfo.Refresh();
   ExtSymbolInfo.RefreshRates();

   double price=0;
//--- Stop Loss and Take Profit are not set by default
   double stoploss=0.0;
   double takeprofit=0.0;

   int    digits=ExtSymbolInfo.Digits();
   double point=ExtSymbolInfo.Point();
   double spread=ExtSymbolInfo.Ask()-ExtSymbolInfo.Bid();
   
   Print("Operando....");
  
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double lote = balance * InpLot;
   
      return true;
   
   if(operaci == SIGNAL_BUY)
    {
      price=NormalizeDouble(ExtSymbolInfo.Ask(), digits);
      
      //--- if Stop Loss is set
      if(InpSL>0)
        {
         if(spread>=InpSL*point)
           {
            PrintFormat("StopLoss (%d points) <= current spread = %.4f points. Spread value will be used", InpSL, spread/point);
            stoploss = NormalizeDouble(price-spread, digits);
           }
         else
            stoploss = NormalizeDouble(price-InpSL*point, digits);
        }
      //--- if Take Profit is set*/
      if(InpTP>0)
        {
         if(spread>=InpTP*point)
           {
            PrintFormat("TakeProfit (%d points) < current spread = %.0f points. Spread value will be used", InpTP, spread/point);
            takeprofit = NormalizeDouble(price+spread, digits);
           }
         else
            takeprofit = NormalizeDouble(price+InpTP*point, digits);
        }

      PrintFormat("Comprando el Lote: %.5f con Precio: %.5f StopLoss: %.4f y TakeProfit: %.4f", lote, price, stoploss, takeprofit);

      if(!ExtTrade.Buy(lote, Symbol(), price, stoploss, takeprofit))
        {
         PrintFormat("Failed %s buy %G at %G (sl=%G tp=%G) failed. Ask=%G error=%d",
                     Symbol(), lote, price, stoploss, takeprofit, ExtSymbolInfo.Ask(), GetLastError());
         return(false);
        }
     }
     else {
     if(operaci == SIGNAL_SELL)
        {
         price=NormalizeDouble(ExtSymbolInfo.Bid(), digits);
         
         //--- if Stop Loss is set
         if(InpSL>0)
           {
            if(spread>=InpSL*point)
              {
               PrintFormat("StopLoss (%d points) <= current spread = %.0f points. Spread value will be used", InpSL, spread/point);
               stoploss = NormalizeDouble(price+spread, digits);
              }
            else
               stoploss = NormalizeDouble(price+InpSL*point, digits);
          }
         //--- if Take Profit is set
         if(InpTP>0)
           {
            if(spread>=InpTP*point)
              {
               PrintFormat("TakeProfit (%d points) < current spread = %.0f points. Spread value will be used", InpTP, spread/point);
               takeprofit = NormalizeDouble(price-spread, digits);
              }
            else
               takeprofit = NormalizeDouble(price-InpTP*point, digits);
           }
         PrintFormat("Vendiendo el Lote: %.5f con Precio: %.5f StopLoss: %.4f y TakeProfit: %.4f", lote, price, stoploss, takeprofit);

         if(!ExtTrade.Sell(lote, Symbol(), price,  stoploss, takeprofit))
           {
            PrintFormat("Failed %s sell at %G (sl=%G tp=%G) failed. Bid=%G error=%d",
                        Symbol(), price, stoploss, takeprofit, ExtSymbolInfo.Bid(), GetLastError());
            ExtTrade.PrintResult();
            Print("   ");
            return(false);
           }
      }
     }
     
   return true;
  }

void closePositions() {
//--- check all positions and close ours based on the signal
   int positions=PositionsTotal();
   Print("Cerrando las Operaciones");
   for(int i=positions-1; i>=0; i--)
     {
      Print("Cerrando operación: ", i);
      ulong ticket=PositionGetTicket(i);
      if(ticket!=0)
        {
         //--- get the name of the symbol and the position id (magic)
         string symbol=PositionGetString(POSITION_SYMBOL);
         long   magic =PositionGetInteger(POSITION_MAGIC);
         //--- if they correspond to our values
         if(symbol==Symbol())
           {
               ExtTrade.PositionClose(ticket);
               ExtTrade.PrintResult();
               Print("   ");
           }
        }
     }
 }