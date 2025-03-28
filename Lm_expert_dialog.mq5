//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#property strict

#include "SymbolInfoDialog.mqh"

input int DialogWidth = 250;    // Dialog width
input int DialogHeight = 350;   // Dialog height

CSymbolInfoDialog SymbolDialog;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Calculate position to center the dialog on the chart
    long chart_width = (long)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
    long chart_height = (long)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
    
//    int x1 = (int)(chart_width/2 - DialogWidth/2);
//    int y1 = (int)(chart_height/2 - DialogHeight/2);
    int x1 = 20;
    int y1 = 30; 
    int x2 = x1 + DialogWidth;
    int y2 = y1 + DialogHeight;
    
    // Create the dialog
    if(!SymbolDialog.Create(0, "SymbolInfoDialog", 0, x1, y1, x2, y2))
    {
        Print("Failed to create dialog!");
        return(INIT_FAILED);
    }
    
    // Make dialog visible
    SymbolDialog.Run();
    
    // Update with initial values
    UpdateDialogValues();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    SymbolDialog.Destroy(reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    static datetime last_update = 0;
    
    // Update values once per second to avoid flickering
    if(TimeCurrent() > last_update)
    {
        UpdateDialogValues();
        last_update = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Update dialog values                                             |
//+------------------------------------------------------------------+
void UpdateDialogValues()
{
    SymbolDialog.UpdateValues(_Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), SymbolInfoDouble(_Symbol, SYMBOL_BID));
}