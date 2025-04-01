
#define SIGNAL_BUY 1        // Buy signal
#define SIGNAL_NOT 0        // no trading signal
#define SIGNAL_SELL -1      // Sell signal
/*#define SIGNAL_BUY_BUY 2    // Buy Buy signal
#define SIGNAL_SELL_SELL -2 // Sell Sell signal
#define SIGNAL_BUY_BUY_BUY 3    // Buy Buy Buy signal
#define SIGNAL_SELL_SELL_SELL -3 // Sell Sell Sell signal

*/
#define DIRECTION_BUY 1
#define DIRECTION_NOT 0
#define DIRECTION_SELL -1

#define CLOSE_LONG 2   // signal to close Long
#define CLOSE_SHORT -2 // signal to close Short

//--- Input parameters
input int InpAverBodyPeriod = 12;                // period for calculating average candlestick size
input int InpMAPeriod = 5;                       // Trend MA period
input int InpPeriodRSI = 37;                     // RSI period
input ENUM_APPLIED_PRICE InpPrice = PRICE_CLOSE; // Price type
input bool ManualClose = true;                  // Manual close?
input bool OpenSameDir = true;                   //Open Same Direction?
input bool InpEstado = false;                   //Star Estado en False. No opera de entrada


//--- trade parameters
input uint InpDuration = 100; // position holding time in bars
input uint InpMantain = 4;   // Position Mantian during the close position
input uint InpSL = 120;       // Stop Loss in points
input uint InpTP = 150;       // Take Profit in points
input double InpRisk = 1.5;      // Risk in % of the account balance
input uint InpSread = 50; // Trailing Spread valid in points
input uint InpSlippage = 10;  // slippage in points
//--- money management parameters
input double InpLot = 0.1; // lot.5
//--- Expert ID
input long InpMagicNumber = 17504288; // Magic Number

//--- global variables
int ExtAvgBodyPeriod;            // average candlestick calculation period
int ExtSignalOpen = 0;           // Buy/Sell signal
int ExtPrevSignalOpen = 0;       // Buy/Sell signal
int ExtSignalClose = 0;          // signal to close a position
string ExtPatternInfo = "";      // current pattern information
int ExtDirection = 0;        // position opening direction
bool ExtPatternDetected = false; // pattern detected
bool ExtConfirmed = false;       // pattern confirmed
bool ExtCloseByTime = false;      // requires closing by time
bool ExtCheckPassed = true;      // status checking error

//---  indicator handles
/*
int ExtIndicatorHandle = INVALID_HANDLE;
int ExtTrendMAHandle = INVALID_HANDLE;
int TrendIndicatorHandle = INVALID_HANDLE;
*/