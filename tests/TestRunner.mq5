//+------------------------------------------------------------------+
//|                                                  TestRunner.mq5 |
//|                                     lm_robot test harness (MQL5)|
//+------------------------------------------------------------------+
#property copyright "lm_robot"
#property version   "1.00"
#property description "Runner minimo de aserciones para los modulos de lm_robot."

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
//| Casos de prueba. Crece con cada modulo del motor.                |
//+------------------------------------------------------------------+
void RunTests()
  {
   AssertTrue(true, "assert true pasa");
   AssertTrue(!false, "assert negado pasa");
   AssertEqualInt(2 + 2, 4, "aritmetica entera");
   AssertEqualDouble(0.1 + 0.2, 0.3, 0.0000001, "aritmetica de punto flotante");

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
