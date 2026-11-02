//+------------------------------------------------------------------+
//|                                                  TestRunner.mq5 |
//|                                     lm_robot test harness (MQL5)|
//+------------------------------------------------------------------+
#property copyright "lm_robot"
#property version   "1.00"
#property description "Runner minimo de aserciones para los modulos de lm_robot."

#include "../Include/LmRobot/Core/MarketContext.mqh"
#include "../Include/LmRobot/Core/BasketState.mqh"
#include "../Include/LmRobot/Execution/Executor.mqh"
#include "../Include/LmRobot/Risk/RiskPolicy.mqh"
#include "../Include/LmRobot/Risk/DailyLossGuard.mqh"
#include "../Include/LmRobot/Strategies/Signal.mqh"
#include "../Include/LmRobot/Strategies/Scalper.mqh"
#include "../Include/LmRobot/Harness/SignalCsv.mqh"

//--- Fuerza un fallo para verificar que el runner realmente falla.
input bool InjectFailure = false;

int g_passed = 0;
int g_failed = 0;

//+------------------------------------------------------------------+
//| Aserciones                                                       |
//+------------------------------------------------------------------+
void AssertTrue(bool condition, const string name)
  {
   if(condition)
     {
      g_passed++;
      PrintFormat("PASS  %s", name);
     }
   else
     {
      g_failed++;
      PrintFormat("FAIL  %s", name);
     }
  }

void AssertEqualInt(long actual, long expected, const string name)
  {
   if(actual == expected)
     {
      g_passed++;
      PrintFormat("PASS  %s", name);
     }
   else
     {
      g_failed++;
      PrintFormat("FAIL  %s (esperado=%I64d, actual=%I64d)", name, expected, actual);
     }
  }

void AssertEqualDouble(double actual, double expected, double tolerance, const string name)
  {
   if(MathAbs(actual - expected) <= tolerance)
     {
      g_passed++;
      PrintFormat("PASS  %s", name);
     }
   else
     {
      g_failed++;
      PrintFormat("FAIL  %s (esperado=%.10f, actual=%.10f, tolerancia=%.10f)",
                  name, expected, actual, tolerance);
     }
  }

//+------------------------------------------------------------------+
//| Instrumento sintetico de 5 digitos para pruebas.                 |
//+------------------------------------------------------------------+
InstrumentInfo MakeFiveDigitInstrument()
  {
   InstrumentInfo instrument;

   instrument.symbol         = "TEST5";
   instrument.digits         = 5;
   instrument.point          = 0.00001;
   instrument.pipSize        = LmPipSize(5, 0.00001);
   instrument.tickSize       = 0.00001;
   instrument.tickValue      = 1.0;
   instrument.pipValuePerLot = LmPipValuePerLot(1.0, 0.00001, instrument.pipSize);
   instrument.stopsLevel     = 20;
   instrument.freezeLevel    = 0;
   instrument.valid          = true;

   return(instrument);
  }

//+------------------------------------------------------------------+
//| Posicion sintetica para pruebas de la canasta.                   |
//+------------------------------------------------------------------+
BasketPosition MakeBasketPosition(const ulong ticket, const long magic, const string symbol,
                                  const ENUM_POSITION_TYPE type, const double volume,
                                  const double openPrice, const datetime openTime,
                                  const double profit = 0.0, const double swap = 0.0,
                                  const double commission = 0.0)
  {
   BasketPosition position;

   position.ticket     = ticket;
   position.magic      = magic;
   position.symbol     = symbol;
   position.type       = type;
   position.volume     = volume;
   position.openPrice  = openPrice;
   position.openTime   = openTime;
   position.profit     = profit;
   position.swap       = swap;
   position.commission = commission;

   return(position);
  }

//+------------------------------------------------------------------+
//| 3.1 Scan filtrado por simbolo y magic.                           |
//+------------------------------------------------------------------+
void TestBasketScanFiltering()
  {
   BasketPosition positions[4];
   positions[0] = MakeBasketPosition(1, 111, "TEST", POSITION_TYPE_BUY, 0.01, 1.1000,
                                     D'2026.01.02 10:00:00');
   positions[1] = MakeBasketPosition(2, 222, "TEST", POSITION_TYPE_BUY, 0.50, 1.2000,
                                     D'2026.01.02 10:01:00');
   positions[2] = MakeBasketPosition(3, 111, "OTHER", POSITION_TYPE_SELL, 0.50, 1.3000,
                                     D'2026.01.02 10:02:00');
   positions[3] = MakeBasketPosition(4, 111, "TEST", POSITION_TYPE_BUY, 0.02, 1.1010,
                                     D'2026.01.02 10:03:00');

   BasketState basket;
   AssertTrue(LmAggregateBasket("TEST", 111, positions, basket),
              "scan de canasta por simbolo y magic");
   AssertEqualInt(basket.count, 2, "scan ignora posiciones de otro magic y simbolo");
   AssertEqualDouble(basket.volume, 0.03, 1e-9, "scan suma solo el volumen propio");
   AssertEqualDouble(basket.averagePrice, 1.1006666667, 1e-9,
                     "scan ignora el promedio de posiciones ajenas");
   AssertEqualDouble(basket.lastOpenPrice, 1.1010, 1e-12,
                     "scan devuelve el precio de la ultima orden");
   AssertEqualInt((int)basket.direction, (int)BASKET_DIRECTION_BUY,
                  "scan devuelve la direccion de la canasta");
  }

//+------------------------------------------------------------------+
//| 3.2 Promedio ponderado y PnL con profit + swap + commission.     |
//+------------------------------------------------------------------+
void TestBasketAverageAndPnl()
  {
   BasketPosition positions[2];
   positions[0] = MakeBasketPosition(1, 111, "TEST", POSITION_TYPE_BUY, 0.01, 1.0000,
                                     D'2026.01.02 10:00:00', 1.5, 0.1, -0.3);
   positions[1] = MakeBasketPosition(2, 111, "TEST", POSITION_TYPE_BUY, 0.02, 1.0010,
                                     D'2026.01.02 10:05:00', -0.5, -0.2, -0.4);

   BasketState basket;
   LmAggregateBasket("TEST", 111, positions, basket);

   AssertEqualDouble(basket.averagePrice, 1.0006666667, 1e-9,
                     "promedio ponderado 0.01@1.0000 + 0.02@1.0010");
   AssertEqualDouble(NormalizeDouble(basket.averagePrice, 4), 1.0007, 1e-9,
                     "promedio ponderado redondeado a 4 digitos = 1.0007");
   AssertEqualDouble(basket.pnl, 0.2, 1e-9,
                     "PnL de canasta incluye profit + swap + commission");
  }

//+------------------------------------------------------------------+
//| 3.3 Ciclo de vida y reinicio del contador de pasos.              |
//+------------------------------------------------------------------+
void TestBasketLifecycle()
  {
   BasketPosition one[1];
   one[0] = MakeBasketPosition(1, 111, "TEST", POSITION_TYPE_BUY, 0.01, 1.1000,
                               D'2026.01.02 10:00:00');

   BasketPosition many[3];
   many[0] = one[0];
   many[1] = MakeBasketPosition(2, 111, "TEST", POSITION_TYPE_BUY, 0.02, 1.0990,
                                D'2026.01.02 10:05:00');
   many[2] = MakeBasketPosition(3, 111, "TEST", POSITION_TYPE_BUY, 0.03, 1.0980,
                                D'2026.01.02 10:10:00');

   BasketState emptyBasket;
   BasketPosition none[];
   LmAggregateBasket("TEST", 111, none, emptyBasket);

   BasketState basket;
   CBasketTracker tracker;

   AssertEqualInt((int)tracker.State(), (int)BASKET_LIFECYCLE_FLAT,
                  "la canasta inicia plana");
   AssertEqualInt(tracker.StepCount(), 0, "la canasta plana no tiene pasos");

   LmAggregateBasket("TEST", 111, one, basket);
   tracker.Update(basket);
   AssertEqualInt((int)tracker.State(), (int)BASKET_LIFECYCLE_OPEN,
                  "con una posicion la canasta queda abierta");
   AssertEqualInt(tracker.StepCount(), 0, "el primer lote no cuenta como paso");
   AssertTrue(!tracker.AllowsDirection(BASKET_DIRECTION_SELL),
              "canasta abierta no permite la direccion opuesta");

   LmAggregateBasket("TEST", 111, many, basket);
   tracker.Update(basket);
   AssertEqualInt(tracker.StepCount(), 2, "tres posiciones equivalen a dos pasos");
   AssertTrue(tracker.IsOpen(), "la canasta sigue abierta");

   tracker.Update(emptyBasket);
   AssertEqualInt((int)tracker.State(), (int)BASKET_LIFECYCLE_CLOSED,
                  "al cerrarse la canasta pasa a CLOSED");
   AssertEqualInt(tracker.StepCount(), 0,
                  "al cerrar toda la canasta el contador vuelve a cero");

   tracker.Update(emptyBasket);
   AssertEqualInt((int)tracker.State(), (int)BASKET_LIFECYCLE_FLAT,
                  "tras el tick de cierre la canasta queda plana");
   AssertTrue(tracker.CanOpenFirst(), "una canasta plana permite la primera orden");
  }

//+------------------------------------------------------------------+
//| 3.4 Deteccion del paso de grid por distancia en pips.            |
//+------------------------------------------------------------------+
void TestBasketGridStep()
  {
   double pipSize = 0.0001;

   BasketPosition buyPositions[1];
   buyPositions[0] = MakeBasketPosition(1, 111, "TEST", POSITION_TYPE_BUY, 0.01, 1.1000,
                                        D'2026.01.02 10:00:00');
   BasketState buyBasket;
   LmAggregateBasket("TEST", 111, buyPositions, buyBasket);

   AssertEqualDouble(LmGridDistancePips(buyBasket, 1.0978, pipSize), 22.0, 1e-9,
                     "compra que cae 22 pips");
   AssertTrue(LmGridStepReached(buyBasket, 1.0978, 22.0, pipSize),
              "compra que cae alcanza el paso de grid");
   AssertTrue(!LmGridStepReached(buyBasket, 1.0980, 22.0, pipSize),
              "compra que cae 20 pips no alcanza el paso");
   AssertTrue(!LmGridStepReached(buyBasket, 1.1020, 22.0, pipSize),
              "compra que sube no habilita el paso");

   BasketPosition sellPositions[1];
   sellPositions[0] = MakeBasketPosition(2, 111, "TEST", POSITION_TYPE_SELL, 0.01, 1.1000,
                                         D'2026.01.02 10:00:00');
   BasketState sellBasket;
   LmAggregateBasket("TEST", 111, sellPositions, sellBasket);

   AssertTrue(LmGridStepReached(sellBasket, 1.1022, 22.0, pipSize),
              "venta que sube alcanza el paso de grid");
   AssertTrue(!LmGridStepReached(sellBasket, 1.1020, 22.0, pipSize),
              "venta que sube 20 pips no alcanza el paso");
   AssertTrue(!LmGridStepReached(sellBasket, 1.0980, 22.0, pipSize),
              "venta que baja no habilita el paso");
  }

//+------------------------------------------------------------------+
//| Doble de prueba para el backend de ejecucion.                    |
//+------------------------------------------------------------------+
class CTestExecutionBackend : public IExecutionBackend
  {
private:
   bool    m_acceptSend;
   bool    m_acceptModify;
   int     m_sendCalls;
   int     m_modifyCalls;
   double  m_lastVolume;
   ulong   m_tickets[];
   double  m_sl[];
   double  m_tp[];

public:
   CTestExecutionBackend(const bool acceptSend = true, const bool acceptModify = true)
     {
      m_acceptSend   = acceptSend;
      m_acceptModify = acceptModify;
      m_sendCalls    = 0;
      m_modifyCalls  = 0;
      m_lastVolume   = 0.0;
     }

   virtual bool Send(const OrderRequest &request, int &retcode)
     {
      m_sendCalls++;
      m_lastVolume = request.volume;
      retcode = (m_acceptSend ? 10009 : 10004);
      return(m_acceptSend);
     }

   virtual bool Modify(const ulong ticket, const double sl, const double tp, int &retcode)
     {
      int index = ArraySize(m_tickets);
      ArrayResize(m_tickets, index + 1);
      ArrayResize(m_sl, index + 1);
      ArrayResize(m_tp, index + 1);

      m_tickets[index] = ticket;
      m_sl[index]      = sl;
      m_tp[index]      = tp;

      m_modifyCalls++;
      retcode = (m_acceptModify ? 10009 : 10004);
      return(m_acceptModify);
     }

   int    SendCalls()    { return(m_sendCalls); }
   int    ModifyCalls()  { return(m_modifyCalls); }
   double LastVolume()   { return(m_lastVolume); }
   ulong  TicketAt(const int index) { return(m_tickets[index]); }
   double SlAt(const int index)     { return(m_sl[index]); }
   double TpAt(const int index)     { return(m_tp[index]); }
  };

//+------------------------------------------------------------------+
//| Doble de prueba para el proveedor de margen.                     |
//+------------------------------------------------------------------+
class CTestAccountProvider : public IAccountInfoProvider
  {
private:
   double m_freeMargin;
   double m_requiredMargin;

public:
   CTestAccountProvider(const double freeMargin, const double requiredMargin)
     {
      m_freeMargin     = freeMargin;
      m_requiredMargin = requiredMargin;
     }

   virtual double FreeMargin()
     {
      return(m_freeMargin);
     }

   virtual bool CalcMargin(const ENUM_ORDER_TYPE type, const string symbol,
                           const double volume, const double price, double &margin)
     {
      margin = m_requiredMargin;
      return(true);
     }
  };

SymbolLimits MakeExecutionLimits()
  {
   SymbolLimits limits;

   limits.symbol            = "TEST";
   limits.point             = 0.0001;
   limits.volumeStep        = 0.01;
   limits.volumeMin         = 0.01;
   limits.volumeMax         = 1.0;
   limits.stopsLevelPoints  = 10.0;
   limits.freezeLevelPoints = 0.0;
   limits.valid             = true;

   return(limits);
  }

ExecutorConfig MakeExecutionConfig(const int maxAttempts = 3,
                                   const int retryDelayMs = 0,
                                   const int deadlineMs = 1000)
  {
   ExecutorConfig config;

   config.maxAttempts  = maxAttempts;
   config.retryDelayMs = retryDelayMs;
   config.deadlineMs   = deadlineMs;
   config.magic        = 111;

   return(config);
  }

OrderRequest MakeOrderRequest(const ENUM_ORDER_TYPE type, const double volume,
                              const double price, const double sl, const double tp = 0.0)
  {
   OrderRequest request;

   request.symbol  = "TEST";
   request.type    = type;
   request.volume  = volume;
   request.price   = price;
   request.sl      = sl;
   request.tp      = tp;
   request.comment = "test";

   return(request);
  }

//+------------------------------------------------------------------+
//| 4.1 Normalizacion del volumen al step, minimo y maximo.          |
//+------------------------------------------------------------------+
void TestExecutorVolumeNormalization()
  {
   AssertEqualDouble(LmNormalizeVolume(0.017, 0.01, 0.01, 1.0), 0.02, 1e-9,
                     "volumen 0.017 se ajusta al multiplo mas cercano 0.02");
   AssertEqualDouble(LmNormalizeVolume(0.013, 0.01, 0.01, 1.0), 0.01, 1e-9,
                     "volumen 0.013 se ajusta al multiplo mas cercano 0.01");
   AssertEqualDouble(LmNormalizeVolume(0.001, 0.01, 0.01, 1.0), 0.01, 1e-9,
                     "volumen debajo del minimo se acota al minimo");
   AssertEqualDouble(LmNormalizeVolume(2.0, 0.01, 0.01, 1.0), 1.0, 1e-9,
                     "volumen encima del maximo se acota al maximo");
   AssertEqualDouble(LmNormalizeVolume(0.26, 0.1, 0.1, 0.25), 0.2, 1e-9,
                     "el maximo se ajusta al multiplo valido inferior");
   AssertEqualDouble(LmNormalizeVolume(0.02, 0.0, 0.01, 1.0), 0.0, 1e-9,
                     "step invalido devuelve cero");

   SymbolLimits limits = MakeExecutionLimits();
   CTestExecutionBackend backend;
   CTestAccountProvider accounts(1000.0, 10.0);
   CExecutor executor;
   AssertTrue(executor.Init(&backend, &accounts, limits, MakeExecutionConfig()),
              "executor inicializado para normalizacion");

   OrderRequest request = MakeOrderRequest(ORDER_TYPE_BUY, 0.017, 1.1000, 1.0990);
   ExecutionReport report;
   AssertEqualInt((int)executor.Send(request, report), (int)EXECUTION_STATUS_OK,
                  "orden con volumen no multiple se envia normalizada");
   AssertEqualDouble(report.normalizedVolume, 0.02, 1e-9,
                     "el reporte expone el volumen normalizado");
   AssertEqualDouble(backend.LastVolume(), 0.02, 1e-9,
                     "el backend recibe el volumen normalizado");
  }

//+------------------------------------------------------------------+
//| 4.2 Rechazo de ordenes sin SL o con SL dentro del stops level.   |
//+------------------------------------------------------------------+
void TestExecutorStopLossValidation()
  {
   string reason = "";

   AssertTrue(LmValidateStopLoss(ORDER_TYPE_BUY, 1.1000, 1.0990, 10.0, 0.0001, reason),
              "SL de compra a 10 puntos es valido");
   AssertTrue(!LmValidateStopLoss(ORDER_TYPE_BUY, 1.1000, 0.0, 10.0, 0.0001, reason),
              "compra sin SL se rechaza");
   AssertTrue(reason != "", "el rechazo sin SL registra el motivo");
   AssertTrue(!LmValidateStopLoss(ORDER_TYPE_BUY, 1.1000, 1.0995, 10.0, 0.0001, reason),
              "SL de compra dentro del stops level se rechaza");
   AssertTrue(reason != "", "el rechazo por stops level registra el motivo");
   AssertTrue(LmValidateStopLoss(ORDER_TYPE_SELL, 1.1000, 1.1010, 10.0, 0.0001, reason),
              "SL de venta a 10 puntos es valido");
   AssertTrue(!LmValidateStopLoss(ORDER_TYPE_SELL, 1.1000, 1.1005, 10.0, 0.0001, reason),
              "SL de venta dentro del stops level se rechaza");

   SymbolLimits limits = MakeExecutionLimits();
   CTestExecutionBackend backend;
   CTestAccountProvider accounts(1000.0, 10.0);
   CExecutor executor;
   executor.Init(&backend, &accounts, limits, MakeExecutionConfig());

   OrderRequest noStop = MakeOrderRequest(ORDER_TYPE_BUY, 0.01, 1.1000, 0.0);
   ExecutionReport report;
   AssertEqualInt((int)executor.Send(noStop, report), (int)EXECUTION_STATUS_INVALID_STOP,
                  "el executor rechaza la orden sin stop loss");
   AssertEqualInt(backend.SendCalls(), 0, "la orden sin stop loss no se envia");
   AssertTrue(report.reason != "", "el executor registra el motivo del rechazo");

   OrderRequest tightStop = MakeOrderRequest(ORDER_TYPE_BUY, 0.01, 1.1000, 1.0995);
   AssertEqualInt((int)executor.Send(tightStop, report), (int)EXECUTION_STATUS_INVALID_STOP,
                  "el executor rechaza el stop dentro del stops level");
   AssertEqualInt(backend.SendCalls(), 0, "la orden con stop invalido no se envia");
  }

//+------------------------------------------------------------------+
//| 4.3 Reintentos acotados por cantidad y por deadline.             |
//+------------------------------------------------------------------+
void TestExecutorRetryLimits()
  {
   SymbolLimits limits = MakeExecutionLimits();
   CTestAccountProvider accounts(1000.0, 10.0);
   OrderRequest request = MakeOrderRequest(ORDER_TYPE_BUY, 0.01, 1.1000, 1.0990);
   ExecutionReport report;

   CTestExecutionBackend alwaysRejects(false, true);
   CExecutor executor;
   executor.Init(&alwaysRejects, &accounts, limits, MakeExecutionConfig(3, 0, 1000));
   AssertEqualInt((int)executor.Send(request, report), (int)EXECUTION_STATUS_RETRY_EXHAUSTED,
                  "un backend que rechaza siempre agota los reintentos");
   AssertEqualInt(report.attempts, 3, "el executor respeta el maximo de intentos");
   AssertEqualInt(alwaysRejects.SendCalls(), 3, "el backend recibe exactamente tres intentos");

   CTestExecutionBackend deadlineRejects(false, true);
   CExecutor deadlineExecutor;
   deadlineExecutor.Init(&deadlineRejects, &accounts, limits, MakeExecutionConfig(100, 10, 1));
   AssertEqualInt((int)deadlineExecutor.Send(request, report),
                  (int)EXECUTION_STATUS_RETRY_EXHAUSTED,
                  "un deadline vencido corta los reintentos");
   AssertTrue(report.attempts < 100, "el deadline limita los intentos antes del maximo");
   AssertTrue(deadlineRejects.SendCalls() < 100, "el backend no recibe los cien intentos");
  }

//+------------------------------------------------------------------+
//| 4.4 Modificacion de SL y TP de toda la canasta.                  |
//+------------------------------------------------------------------+
void TestExecutorBasketProtection()
  {
   BasketPosition positions[3];
   positions[0] = MakeBasketPosition(1, 111, "TEST", POSITION_TYPE_BUY, 0.01, 1.1000,
                                     D'2026.01.02 10:00:00');
   positions[1] = MakeBasketPosition(2, 111, "TEST", POSITION_TYPE_BUY, 0.02, 1.0990,
                                     D'2026.01.02 10:05:00');
   positions[2] = MakeBasketPosition(3, 111, "TEST", POSITION_TYPE_BUY, 0.03, 1.0980,
                                     D'2026.01.02 10:10:00');

   SymbolLimits limits = MakeExecutionLimits();
   CTestExecutionBackend backend(true, true);
   CTestAccountProvider accounts(1000.0, 10.0);
   CExecutor executor;
   executor.Init(&backend, &accounts, limits, MakeExecutionConfig());

   ExecutionReport report;
   AssertEqualInt((int)executor.ModifyBasket(positions, 1.0900, 1.1100, report),
                  (int)EXECUTION_STATUS_OK,
                  "la proteccion de la canasta se aplica a todas las posiciones");
   AssertEqualInt(report.modifiedCount, 3, "se modifican las tres posiciones");
   AssertEqualInt(backend.ModifyCalls(), 3, "el backend recibe una modificacion por posicion");

   for(int i = 0; i < 3; i++)
     {
      AssertEqualInt((int)backend.TicketAt(i), i + 1,
                     StringFormat("posicion %d modificada por ticket", i + 1));
      AssertEqualDouble(backend.SlAt(i), 1.0900, 1e-12,
                        StringFormat("posicion %d comparte el SL", i + 1));
      AssertEqualDouble(backend.TpAt(i), 1.1100, 1e-12,
                        StringFormat("posicion %d comparte el TP", i + 1));
     }
  }

//+------------------------------------------------------------------+
//| 4.5 Verificacion de margen libre antes de enviar.                |
//+------------------------------------------------------------------+
void TestExecutorMarginCheck()
  {
   AssertTrue(LmHasEnoughMargin(10.0, 10.0), "margen libre igual al requerido alcanza");
   AssertTrue(LmHasEnoughMargin(5.0, 10.0), "margen libre mayor al requerido alcanza");
   AssertTrue(!LmHasEnoughMargin(10.0, 5.0), "margen libre insuficiente se detecta");

   SymbolLimits limits = MakeExecutionLimits();
   OrderRequest request = MakeOrderRequest(ORDER_TYPE_BUY, 0.01, 1.1000, 1.0990);
   ExecutionReport report;

   CTestExecutionBackend noMarginBackend;
   CTestAccountProvider noMargin(5.0, 10.0);
   CExecutor noMarginExecutor;
   noMarginExecutor.Init(&noMarginBackend, &noMargin, limits, MakeExecutionConfig());
   AssertEqualInt((int)noMarginExecutor.Send(request, report),
                  (int)EXECUTION_STATUS_NO_MARGIN,
                  "la orden sin margen se rechaza");
   AssertEqualInt(noMarginBackend.SendCalls(), 0,
                  "la canasta no se altera cuando falta margen");
   AssertTrue(report.reason != "", "el rechazo por margen registra el motivo");

   CTestExecutionBackend fundedBackend;
   CTestAccountProvider funded(1000.0, 10.0);
   CExecutor fundedExecutor;
   fundedExecutor.Init(&fundedBackend, &funded, limits, MakeExecutionConfig());
   AssertEqualInt((int)fundedExecutor.Send(request, report), (int)EXECUTION_STATUS_OK,
                  "la orden con margen suficiente se envia");
   AssertEqualInt(fundedBackend.SendCalls(), 1, "el backend recibe la orden con margen");
  }

//+------------------------------------------------------------------+
//| 5.1 Lote inicial por riesgo y clamp al broker.                   |
//+------------------------------------------------------------------+
void TestRiskInitialLot()
  {
   AssertEqualDouble(LmInitialLot(10000.0, 0.5, 40.0, 10.0, 0.01, 0.01, 100.0),
                     0.12, 1e-9,
                     "lote inicial 10000, 0.5%, 40 pips y 10 por pip = 0.12");
   AssertEqualDouble(LmInitialLot(100.0, 0.5, 40.0, 10.0, 0.01, 0.01, 100.0),
                     0.01, 1e-9,
                     "un lote debajo del minimo se eleva al minimo del broker");
   AssertEqualDouble(LmInitialLot(1000000.0, 0.5, 40.0, 10.0, 0.01, 0.01, 0.20),
                     0.20, 1e-9,
                     "un lote encima del maximo se acota al maximo del broker");
   AssertEqualDouble(LmInitialLot(10000.0, 0.5, 0.0, 10.0, 0.01, 0.01, 100.0),
                     0.0, 1e-9,
                     "un stop loss cero no produce lote");

   RiskConfig config = LmDefaultRiskConfig();
   config.maxLotPerOrder        = 1.0;
   config.maxVolumePerStrategy  = 1.0;

   RiskStepPlan plan;
   AssertTrue(LmPlanInitialOrder(config, 10000.0, 10.0, 0.01, 0.01, 100.0, plan),
              "la primera orden cabe en el presupuesto de canasta");
   AssertEqualDouble(plan.volume, 0.12, 1e-9,
                     "la primera orden usa el lote calculado por riesgo");
   AssertEqualInt((int)plan.decision, (int)RISK_DECISION_OPEN_FIRST,
                  "la primera orden se marca como apertura");

   RiskConfig tiny = LmDefaultRiskConfig();
   AssertTrue(!LmPlanInitialOrder(tiny, 100.0, 10.0, 0.01, 0.01, 100.0, plan),
              "el minimo del broker que excede el presupuesto rechaza la apertura");
   AssertEqualInt((int)plan.decision, (int)RISK_DECISION_REJECT,
                  "la apertura rechazada no se envia");
   AssertTrue(plan.reason != "", "el rechazo de apertura registra el motivo");
  }

//+------------------------------------------------------------------+
//| 5.2 Perdida proyectada y rechazo del paso de grid.               |
//+------------------------------------------------------------------+
void TestRiskProjectedLoss()
  {
   AssertEqualDouble(LmProjectedLoss(0.30, 40.0, 10.0), 120.0, 1e-9,
                     "perdida proyectada de 0.30 lotes a 40 pips");
   AssertEqualDouble(LmBasketLossBudget(10000.0, 2.0), 200.0, 1e-9,
                     "presupuesto del 2% sobre 10000");
   AssertTrue(LmFitsBasketBudget(200.0, 10000.0, 2.0),
              "una perdida igual al presupuesto cabe");
   AssertTrue(!LmFitsBasketBudget(200.01, 10000.0, 2.0),
              "una perdida encima del presupuesto no cabe");

   RiskConfig config = LmDefaultRiskConfig();
   config.maxLotPerOrder       = 10.0;
   config.maxVolumePerStrategy = 10.0;
   config.maxGridSteps         = 10;

   RiskStepPlan plan;
   AssertTrue(LmPlanGridOrder(config, 10000.0, 10.0, 0.30, 1, 0.10,
                              0.01, 0.01, 100.0, plan),
              "un paso dentro del presupuesto se acepta");
   AssertEqualDouble(plan.volume, 0.10, 1e-9,
                     "el paso aceptado conserva su volumen");
   AssertEqualDouble(plan.projectedLoss, 160.0, 1e-9,
                     "la perdida proyectada suma el volumen existente");
   AssertEqualInt((int)plan.decision, (int)RISK_DECISION_OPEN_GRID,
                  "el paso aceptado se marca como grid");

   AssertTrue(!LmPlanGridOrder(config, 10000.0, 10.0, 0.45, 1, 0.10,
                               0.01, 0.01, 100.0, plan),
              "un paso que excede el 2% del balance se rechaza");
   AssertEqualInt((int)plan.decision, (int)RISK_DECISION_REJECT,
                  "el paso rechazado no se envia");
   AssertEqualDouble(plan.volume, 0.0, 1e-9,
                     "el paso rechazado no expone volumen");
   AssertTrue(plan.reason != "", "el rechazo por presupuesto registra el motivo");
  }

//+------------------------------------------------------------------+
//| 5.3 Topes independientes de volumen por orden, canasta y pasos.  |
//+------------------------------------------------------------------+
void TestRiskVolumeAndStepCaps()
  {
   AssertEqualDouble(LmCapVolumePerOrder(0.50, 0.10), 0.10, 1e-9,
                     "el tope por orden recorta el volumen");
   AssertEqualDouble(LmCapVolumePerOrder(0.05, 0.10), 0.05, 1e-9,
                     "un volumen debajo del tope por orden no se altera");
   AssertEqualDouble(LmCapVolumePerBasket(0.20, 0.25, 0.30), 0.05, 1e-9,
                     "el tope por canasta usa solo el remanente");
   AssertEqualDouble(LmCapVolumePerBasket(0.10, 0.30, 0.30), 0.0, 1e-9,
                     "una canasta llena no admite mas volumen");
   AssertTrue(LmMaxStepsReached(4, 4), "el tope de pasos se alcanza en el maximo");
   AssertTrue(!LmMaxStepsReached(3, 4), "un paso debajo del maximo sigue habilitado");
   AssertEqualDouble(LmGridLot(0.02, 1.5, 2), 0.045, 1e-9,
                     "lote del paso 2 con multiplicador 1.5");

   RiskConfig config = LmDefaultRiskConfig();
   config.maxBasketLossPct     = 100.0;
   config.maxVolumePerStrategy = 10.0;
   config.maxGridSteps         = 10;

   RiskStepPlan plan;
   config.maxLotPerOrder = 0.10;
   AssertTrue(LmPlanGridOrder(config, 10000.0, 10.0, 0.0, 1, 0.50,
                              0.01, 0.01, 100.0, plan),
              "el paso se acepta tras aplicar el tope por orden");
   AssertEqualDouble(plan.volume, 0.10, 1e-9,
                     "el tope por orden limita el paso de grid");

   config.maxLotPerOrder       = 10.0;
   config.maxVolumePerStrategy = 0.30;
   AssertTrue(LmPlanGridOrder(config, 10000.0, 10.0, 0.25, 2, 0.20,
                              0.01, 0.01, 100.0, plan),
              "el paso se acepta tras aplicar el tope por canasta");
   AssertEqualDouble(plan.volume, 0.05, 1e-9,
                     "el tope por canasta limita el paso de grid");

   config.maxVolumePerStrategy = 10.0;
   config.maxGridSteps         = 4;
   AssertTrue(!LmPlanGridOrder(config, 10000.0, 10.0, 0.20, 4, 0.10,
                               0.01, 0.01, 100.0, plan),
              "con el tope de pasos alcanzado no se planifica otro paso");
   AssertEqualInt((int)plan.decision, (int)RISK_DECISION_REJECT,
                  "el tope de pasos rechaza el paso");
  }

//+------------------------------------------------------------------+
//| Store en memoria que simula el reinicio del terminal.            |
//+------------------------------------------------------------------+
class CTestDailyStore : public IDailyStateStore
  {
private:
   string m_keys[];
   double m_values[];

public:
   virtual bool Load(const string key, double &value)
     {
      for(int i = 0; i < ArraySize(m_keys); i++)
        {
         if(m_keys[i] == key)
           {
            value = m_values[i];
            return(true);
           }
        }

      value = 0.0;
      return(false);
     }

   virtual bool Save(const string key, const double value)
     {
      for(int i = 0; i < ArraySize(m_keys); i++)
        {
         if(m_keys[i] == key)
           {
            m_values[i] = value;
            return(true);
           }
        }

      int index = ArraySize(m_keys);
      ArrayResize(m_keys, index + 1);
      ArrayResize(m_values, index + 1);

      m_keys[index]   = key;
      m_values[index] = value;
      return(true);
     }
  };

//+------------------------------------------------------------------+
//| 5.4 Limite diario persistente por cuenta y dia del servidor.     |
//+------------------------------------------------------------------+
void TestDailyLossGuard()
  {
   CTestDailyStore store;
   CDailyLossGuard guard;
   AssertTrue(guard.Init(&store, 123456, 4.0), "la guarda diaria se inicializa");

   DailyLossState state;
   datetime day1 = D'2026.03.10 08:00:00';

   AssertTrue(guard.Evaluate(day1, 10000.0, state),
              "la primera evaluacion del dia registra la equidad");
   AssertEqualDouble(state.startEquity, 10000.0, 1e-9,
                     "la equidad de inicio del dia queda guardada");
   AssertTrue(!state.blocked, "sin caida no se bloquean las aperturas");

   AssertTrue(guard.Evaluate(day1, 9601.0, state), "evaluacion con caida pequena");
   AssertTrue(!state.blocked, "una caida debajo del 4% no bloquea");

   AssertTrue(guard.Evaluate(day1, 9590.0, state), "evaluacion con caida sobre el limite");
   AssertTrue(state.blocked, "una caida superior al 4% bloquea las aperturas");
   AssertTrue(guard.IsBlocked(), "la guarda conserva el bloqueo");

   //--- Reinicio simulado: misma persistencia, nueva instancia.
   CDailyLossGuard restarted;
   AssertTrue(restarted.Init(&store, 123456, 4.0), "la guarda diaria se reinicia");
   AssertTrue(restarted.Evaluate(day1, 10000.0, state),
              "tras el reinicio la equidad se recupera");
   AssertTrue(state.blocked,
              "el bloqueo diario sobrevive al reinicio aunque la equidad se recupere");
   AssertEqualDouble(state.startEquity, 10000.0, 1e-9,
                     "la equidad de inicio sobrevive al reinicio");

   //--- Nuevo dia del servidor: se habilita una nueva referencia.
   AssertTrue(restarted.Evaluate(D'2026.03.11 00:01:00', 10000.0, state),
              "la evaluacion del dia siguiente funciona");
   AssertTrue(!state.blocked, "el dia siguiente vuelve a habilitar aperturas");
   AssertEqualDouble(state.startEquity, 10000.0, 1e-9,
                     "el dia siguiente registra su propia equidad de inicio");

   //--- Otra cuenta no hereda el estado de la primera.
   CDailyLossGuard other;
   AssertTrue(other.Init(&store, 999999, 4.0), "la guarda de otra cuenta se inicializa");
   AssertTrue(other.Evaluate(day1, 9590.0, state), "la otra cuenta se evalua");
   AssertTrue(!state.blocked, "el bloqueo no se comparte entre cuentas");

   //--- Claves y formulas auxiliares.
   AssertTrue(LmDailyStartKey(123456, day1) !=
              LmDailyStartKey(123456, D'2026.03.11 00:01:00'),
              "la clave de inicio cambia con el dia del servidor");
   AssertTrue(LmDailyStartKey(123456, day1) != LmDailyStartKey(999999, day1),
              "la clave de inicio cambia con la cuenta");
   AssertEqualDouble(LmDailyDropPct(10000.0, 9600.0), 4.0, 1e-9,
                     "la caida porcentual diaria se calcula sobre la equidad inicial");
   AssertTrue(LmDailyLimitReached(4.0, 4.0), "el limite se alcanza en el umbral");
  }

//+------------------------------------------------------------------+
//| 5.5 La gestion tiene prioridad sobre las aperturas.              |
//+------------------------------------------------------------------+
void TestRiskManagementPriority()
  {
   AssertTrue(LmCanManagePositions(true),
              "la gestion se permite con el limite diario activo");
   AssertTrue(LmCanManagePositions(false),
              "la gestion se permite sin el limite diario");

   AssertTrue(!LmCanOpenNew(true, false, false, true),
              "el limite diario bloquea solo las aperturas");
   AssertTrue(!LmCanOpenNew(false, true, false, true),
              "el spread maximo bloquea las aperturas");
   AssertTrue(!LmCanOpenNew(false, false, true, true),
              "la volatilidad alta bloquea las aperturas");
   AssertTrue(!LmCanOpenNew(false, false, false, false),
              "la sesion cerrada bloquea las aperturas");
   AssertTrue(LmCanOpenNew(false, false, false, true),
              "sin guards activos se permiten aperturas");

   BasketPosition positions[2];
   positions[0] = MakeBasketPosition(1, 111, "TEST", POSITION_TYPE_BUY, 0.01, 1.1000,
                                     D'2026.01.02 10:00:00');
   positions[1] = MakeBasketPosition(2, 111, "TEST", POSITION_TYPE_BUY, 0.02, 1.0990,
                                     D'2026.01.02 10:05:00');

   SymbolLimits limits = MakeExecutionLimits();
   CTestExecutionBackend backend(true, true);
   CTestAccountProvider accounts(1000.0, 10.0);
   CExecutor executor;
   executor.Init(&backend, &accounts, limits, MakeExecutionConfig());

   ExecutionReport report;
   AssertEqualInt((int)executor.ModifyBasket(positions, 1.0900, 1.1100, report),
                  (int)EXECUTION_STATUS_OK,
                  "la proteccion por SL se aplica igual con el limite diario activo");
   AssertEqualInt(report.modifiedCount, 2,
                  "la gestion alcanza toda la canasta aunque las aperturas esten bloqueadas");
  }

//+------------------------------------------------------------------+
//| 6.4 Senal pura de Scalper Pro y determinismo.                    |
//+------------------------------------------------------------------+
void TestScalperSignal()
  {
   AssertEqualInt((int)LmScalperSignal(1.1000, 1.0990), (int)SIGNAL_SELL,
                  "close[2] > close[1] devuelve SELL");
   AssertEqualInt((int)LmScalperSignal(1.0990, 1.1000), (int)SIGNAL_BUY,
                  "close[2] < close[1] devuelve BUY");
   AssertEqualInt((int)LmScalperSignal(1.1000, 1.1000), (int)SIGNAL_BUY,
                  "close[2] == close[1] devuelve BUY");

   ENUM_SIGNAL_DIRECTION first  = LmScalperSignal(1.1000, 1.0990);
   ENUM_SIGNAL_DIRECTION second = LmScalperSignal(1.1000, 1.0990);
   AssertEqualInt((int)second, (int)first,
                  "dos evaluaciones con las mismas entradas son deterministas");

   AssertTrue(LmSignalDirectionName(SIGNAL_SELL) == "SELL",
              "el nombre de SELL es estable para el CSV");
   AssertEqualInt((int)LmSignalDirectionFromName("NONE"), (int)SIGNAL_NONE,
                  "NONE se puede leer del CSV");
   AssertTrue(LmTimeframeName(PERIOD_H1) == "H1",
              "el timeframe H1 se escribe sin el prefijo PERIOD_");
  }

//+------------------------------------------------------------------+
//| 6.2 Exportacion CSV con fecha, estrategia, direccion y timeframe.|
//+------------------------------------------------------------------+
void TestSignalCsvExport()
  {
   string filename = "lm_robot_test_signal_export.csv";
   FileDelete(filename);

   datetime times[3];
   times[0] = D'2026.01.02 10:00:00';
   times[1] = D'2026.01.02 11:00:00';
   times[2] = D'2026.01.02 12:00:00';

   ENUM_SIGNAL_DIRECTION directions[3];
   directions[0] = SIGNAL_BUY;
   directions[1] = SIGNAL_SELL;
   directions[2] = SIGNAL_NONE;

   int written = 0;
   AssertTrue(LmExportSignalSeries(times, directions, 0, 3, "Scalper", "H1",
                                   filename, written),
              "la exportacion CSV escribe la serie de senales");
   AssertEqualInt(written, 3, "se escriben las tres filas solicitadas");

   CSignalCsvReader reader;
   AssertTrue(reader.Load(filename), "el CSV exportado se puede leer");
   AssertEqualInt(reader.Count(), 3, "el CSV contiene una fila por senal");

   SignalRow row;
   AssertTrue(reader.RowAt(2, row), "la tercera fila esta disponible");
   AssertEqualInt((int)row.direction, (int)SIGNAL_NONE,
                  "la exportacion conserva las senales NONE");
   AssertTrue(row.strategy == "Scalper", "la fila conserva la estrategia");
   AssertTrue(row.timeframe == "H1", "la fila conserva el timeframe");
   AssertTrue(row.time == times[2], "la fila conserva la fecha del servidor");

   FileDelete(filename);
  }

//+------------------------------------------------------------------+
//| 6.3 Comparador CSV: coincidencias, faltantes, sobrantes.         |
//+------------------------------------------------------------------+
void TestSignalCsvComparator()
  {
   string referenceFile = "lm_robot_test_signal_ref.csv";
   string sameFile      = "lm_robot_test_signal_same.csv";
   string diffFile      = "lm_robot_test_signal_diff.csv";

   FileDelete(referenceFile);
   FileDelete(sameFile);
   FileDelete(diffFile);

   CSignalCsvWriter reference;
   AssertTrue(reference.Open(referenceFile), "se crea el CSV de referencia");
   reference.WriteRow(D'2026.01.02 10:00:00', "Scalper", SIGNAL_SELL, "H1");
   reference.WriteRow(D'2026.01.02 11:00:00', "Scalper", SIGNAL_BUY,  "H1");
   reference.WriteRow(D'2026.01.02 12:00:00', "Scalper", SIGNAL_NONE, "H1");
   reference.Close();

   CSignalCsvWriter same;
   AssertTrue(same.Open(sameFile), "se crea el CSV identico");
   same.WriteRow(D'2026.01.02 10:00:00', "Scalper", SIGNAL_SELL, "H1");
   same.WriteRow(D'2026.01.02 11:00:00', "Scalper", SIGNAL_BUY,  "H1");
   same.WriteRow(D'2026.01.02 12:00:00', "Scalper", SIGNAL_NONE, "H1");
   same.Close();

   CSignalCsvWriter diff;
   AssertTrue(diff.Open(diffFile), "se crea el CSV alterado");
   diff.WriteRow(D'2026.01.02 10:00:00', "Scalper", SIGNAL_SELL, "H1");
   diff.WriteRow(D'2026.01.02 11:00:00', "Scalper", SIGNAL_NONE, "H1");
   diff.WriteRow(D'2026.01.02 13:00:00', "Scalper", SIGNAL_BUY,  "H1");
   diff.Close();

   CSignalComparison comparison;
   AssertTrue(LmCompareSignalCsvFiles(referenceFile, sameFile, comparison),
              "el comparador lee dos CSV identicos");
   AssertEqualInt(comparison.referenceCount, 3, "la referencia tiene tres filas");
   AssertEqualInt(comparison.actualCount, 3, "el CSV nuevo tiene tres filas");
   AssertEqualInt(comparison.matches, 3, "las tres filas coinciden");
   AssertEqualInt(comparison.missing, 0, "no hay filas faltantes");
   AssertEqualInt(comparison.extra, 0, "no hay filas sobrantes");
   AssertEqualInt(comparison.mismatched, 0, "no hay direcciones diferentes");
   AssertTrue(comparison.parity, "dos CSV identicos declaran paridad");

   AssertTrue(LmCompareSignalCsvFiles(referenceFile, diffFile, comparison),
              "el comparador lee el CSV alterado");
   AssertEqualInt(comparison.matches, 1, "solo la primera fila coincide");
   AssertEqualInt(comparison.mismatched, 1, "se detecta una direccion diferente");
   AssertEqualInt(comparison.missing, 1, "se detecta una fila faltante");
   AssertEqualInt(comparison.extra, 1, "se detecta una fila sobrante");
   AssertTrue(!comparison.parity, "el CSV alterado no declara paridad");
   AssertTrue(ArraySize(comparison.details) >= 3,
              "el reporte detalla cada diferencia");

   FileDelete(referenceFile);
   FileDelete(sameFile);
   FileDelete(diffFile);
  }

//+------------------------------------------------------------------+
//| 2.1 Deteccion de pip.                                            |
//+------------------------------------------------------------------+
void TestPipDetection()
  {
   double point5 = 0.00001;
   double point4 = 0.0001;
   double point3 = 0.001;
   double point2 = 0.01;

   AssertEqualDouble(LmPipSize(5, point5), point5 * 10.0, 1e-12,
                     "pip en simbolo de 5 digitos = 10 puntos");
   AssertEqualDouble(LmPipSize(4, point4), point4, 1e-12,
                     "pip en simbolo de 4 digitos = 1 punto");
   AssertEqualDouble(LmPipSize(3, point3), point3 * 10.0, 1e-12,
                     "pip en simbolo de 3 digitos = 10 puntos");
   AssertEqualDouble(LmPipSize(2, point2), point2, 1e-12,
                     "pip en simbolo de 2 digitos = 1 punto");

   AssertEqualDouble(LmPipsToPoints(20.0, LmPipSize(5, point5), point5), 200.0, 1e-9,
                     "20 pips en 5 digitos = 200 puntos");
   AssertEqualDouble(LmPipsToPoints(20.0, LmPipSize(4, point4), point4), 20.0, 1e-9,
                     "20 pips en 4 digitos = 20 puntos");
  }

//+------------------------------------------------------------------+
//| 2.2 Valor del pip por lote.                                      |
//+------------------------------------------------------------------+
void TestPipValuePerLot()
  {
   double pipValue5 = LmPipValuePerLot(1.0, 0.00001, LmPipSize(5, 0.00001));
   double pipValue4 = LmPipValuePerLot(10.0, 0.0001, LmPipSize(4, 0.0001));

   AssertEqualDouble(pipValue5, 10.0, 1e-9,
                     "valor del pip por lote en simbolo de 5 digitos");
   AssertEqualDouble(pipValue4, 10.0, 1e-9,
                     "valor del pip por lote en simbolo de 4 digitos");
   AssertEqualDouble(LmPipValuePerLot(1.0, 0.0, 0.0001), 0.0, 1e-12,
                     "valor del pip con tick size invalido = 0");
  }

//+------------------------------------------------------------------+
//| 2.3 Snapshot de un tick reutilizado por varios consumidores.     |
//+------------------------------------------------------------------+
void TestMarketSnapshot()
  {
   InstrumentInfo instrument = MakeFiveDigitInstrument();
   CMarketContext context;

   AssertTrue(context.InitFromInstrument(instrument, 3.0, 25.0),
              "contexto de prueba inicializado desde el instrumento");
   AssertTrue(context.RefreshFromTick(1.10000, 1.10020, D'2026.01.02 10:00:00'),
              "snapshot del tick construido");

   MarketSnapshot consumerA = context.Snapshot();
   MarketSnapshot consumerB = context.Snapshot();

   AssertEqualDouble(consumerA.bid, consumerB.bid, 1e-12,
                     "dos consumidores del tick leen el mismo bid");
   AssertEqualDouble(consumerA.ask, consumerB.ask, 1e-12,
                     "dos consumidores del tick leen el mismo ask");
   AssertEqualDouble(consumerA.bid, 1.10000, 1e-12, "bid del snapshot");
   AssertEqualDouble(consumerA.ask, 1.10020, 1e-12, "ask del snapshot");
   AssertEqualDouble(consumerA.spreadPips, 2.0, 1e-9, "spread del snapshot en pips");
   AssertEqualInt(context.Refreshes(), 1, "el tick se leyo una sola vez");
   AssertEqualDouble(context.Bid(), 1.10000, 1e-12,
                     "el getter reutiliza el bid leido");
   AssertEqualInt(context.Refreshes(), 1,
                  "los getters no vuelven a leer el mercado");
  }

//+------------------------------------------------------------------+
//| 2.5 Flags de spread maximo y volatilidad alta.                   |
//+------------------------------------------------------------------+
void TestMarketFlags()
  {
   AssertTrue(!LmSpreadBlocked(2.0, 3.0), "spread debajo del maximo no bloquea");
   AssertTrue(LmSpreadBlocked(4.0, 3.0), "spread encima del maximo bloquea");
   AssertTrue(!LmSpreadBlocked(3.0, 3.0), "spread igual al maximo no bloquea");

   AssertTrue(!LmHighVolatility(true, 20.0, 25.0), "ATR debajo del maximo no alerta");
   AssertTrue(LmHighVolatility(true, 30.0, 25.0), "ATR encima del maximo alerta");
   AssertTrue(!LmHighVolatility(false, 30.0, 25.0), "sin lectura de ATR no hay alerta");

   InstrumentInfo instrument = MakeFiveDigitInstrument();
   CMarketContext context;
   context.InitFromInstrument(instrument, 3.0, 25.0);

   context.RefreshFromTick(1.10000, 1.10020, D'2026.01.02 10:00:00');
   AssertTrue(!context.SpreadBlocked(), "snapshot con spread en rango no bloquea");

   context.RefreshFromTick(1.10000, 1.10040, D'2026.01.02 10:01:00');
   AssertTrue(context.SpreadBlocked(), "snapshot con spread alto bloquea");
  }

//+------------------------------------------------------------------+
//| 2.4 Handles creados una vez y liberados al desinicializar.       |
//+------------------------------------------------------------------+
void TestMarketHandles()
  {
   CMarketContext context;

   bool initialized = context.Init(_Symbol, _Period, 14, _Period, 14, 3.0, 30.0);
   AssertTrue(initialized, "handles RSI/ATR creados en la inicializacion");
   AssertTrue(context.RsiHandle() != INVALID_HANDLE, "handle RSI valido");
   AssertTrue(context.AtrHandle() != INVALID_HANDLE, "handle ATR valido");

   int creations = context.HandleCreations();
   for(int i = 0; i < 10; i++)
      context.RefreshFromTick(1.10000, 1.10010, D'2026.01.02 10:00:00');

   AssertEqualInt(context.HandleCreations(), creations,
                  "diez ticks no crean handles nuevos");
   AssertEqualInt(context.Refreshes(), 10, "diez ticks contabilizados");

   context.ReleaseHandles();
   AssertTrue(context.RsiHandle() == INVALID_HANDLE && context.AtrHandle() == INVALID_HANDLE,
              "handles liberados en la desinicializacion");
  }

//+------------------------------------------------------------------+
//| Casos de prueba. Crece con cada modulo del motor.                |
//+------------------------------------------------------------------+
void RunTests()
  {
   AssertTrue(true, "assert true pasa");
   AssertTrue(!false, "assert negado pasa");
   AssertEqualInt(2 + 2, 4, "aritmetica entera");
   AssertEqualDouble(0.1 + 0.2, 0.3, 0.0000001, "aritmetica de punto flotante");

   TestPipDetection();
   TestPipValuePerLot();
   TestMarketSnapshot();
   TestMarketFlags();
   TestMarketHandles();
   TestBasketScanFiltering();
   TestBasketAverageAndPnl();
   TestBasketLifecycle();
   TestBasketGridStep();
   TestExecutorVolumeNormalization();
   TestExecutorStopLossValidation();
   TestExecutorRetryLimits();
   TestExecutorBasketProtection();
   TestExecutorMarginCheck();
   TestRiskInitialLot();
   TestRiskProjectedLoss();
   TestRiskVolumeAndStepCaps();
   TestDailyLossGuard();
   TestRiskManagementPriority();
   TestScalperSignal();
   TestSignalCsvExport();
   TestSignalCsvComparator();

   if(InjectFailure)
      AssertTrue(false, "fallo inyectado a proposito");
  }

//+------------------------------------------------------------------+
//| Resultado                                                        |
//+------------------------------------------------------------------+
bool Report()
  {
   int total = g_passed + g_failed;
   PrintFormat("----------------------------------------");
   PrintFormat("RESULT: %s  (%d/%d aserciones, %d fallidas)",
               (g_failed == 0 ? "PASS" : "FAIL"), g_passed, total, g_failed);
   PrintFormat("----------------------------------------");
   return (g_failed == 0);
  }

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_passed = 0;
   g_failed = 0;

   RunTests();

   if(!Report())
      return (INIT_FAILED);

   return (INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
  }
//+------------------------------------------------------------------+
