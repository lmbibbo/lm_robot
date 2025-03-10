//+------------------------------------------------------------------+
//|                                                    Indicator.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

#include <Object.mqh>
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+

class Indicator: public CObject
{
   private:
      int handle;
      int buffer_num;
      string name;
      
   public:
      
      string getName(){
         return name;
      }
      
      int getBuffer_num(){
         return buffer_num;
      }
      
      int getHandle(){
         return handle;
      }
      
      int init(string theName){
         name = theName;
         handle = iCustom(_Symbol, _Period, name);
         if (handle == INVALID_HANDLE) {
            Print("Error al Conectar: " , name);
            return(INIT_FAILED);
         }
         buffer_num = 0;
         while (true) {
            double signali[];
            int copied = CopyBuffer(handle, buffer_num, 0, 1, signali); // Intentar copiar 1 valor
            //Print(buffer_num, " búferes de: ",theName,  "= ", signal[0]);
            if (copied <= 0) {
               Print("Total: ", buffer_num);
               break;
            }
            buffer_num++;
        }
        return(INIT_SUCCEEDED); 
      }
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   
      Indicator::Indicator()
      {
      }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
      Indicator::~Indicator(void)
      {
         IndicatorRelease(handle);
      }   
      
      double Value(int index)
      {
         double indicator_values[];
         if(CopyBuffer(getHandle(), 0, index, 1, indicator_values)<0)
         {
         //--- if the copying fails, report the error code
            PrintFormat("Failed to copy data from the RSI indicator, error code %d", GetLastError());
            return(EMPTY_VALUE);
         }
         return(indicator_values[0]);
     }   
  
};  

