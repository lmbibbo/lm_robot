//+------------------------------------------------------------------+
//|                                                  TestRunner.mq5 |
//|                                     lm_robot test harness (MQL5)|
//+------------------------------------------------------------------+
#property copyright "lm_robot"
#property version   "1.00"
#property description "Runner minimo de aserciones para los modulos de lm_robot."

#include "../Include/LmRobot/Core/MarketContext.mqh"
#include "../Include/LmRobot/Core/BasketState.mqh"

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
