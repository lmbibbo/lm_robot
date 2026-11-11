# Design

## Context

Ver `proposal.md - Why`. El estado actual que condiciona el enfoque:

- `RiskPct` se copia a `RuntimeConfig.risk.riskPct` en `OnInit` y `CLmRuntime` solo expone `Config()` por valor (Runtime.mqh:1047). No hay setter.
- `OpenFirst` y `OpenGrid` leen `m_config.risk` en cada llamada y `OpenGrid` recalcula el lote base con `LmPlanInitialOrder` antes de aplicar `LotMultiplier^paso` (Runtime.mqh:753, 815-826). Por eso cambiar `m_config.risk.riskPct` ya afecta al próximo paso sin tocar lo abierto.
- El dimensionamiento ya considera la volatilidad: `LmEffectiveSlPips` amplía el SL con el ATR y `LmVolatilityFactor(atrPips, avgAtrPips, volFactorMin, volFactorMax)` ajusta el lote por la razón `ATR_medio / ATR_actual` (RiskPolicy.mqh:89-116, 280-332). `CLmRuntime` obtiene `atrPips` y `atrAvgPips` desde `m_market` y los pasa a `LmPlanInitialOrder` (Runtime.mqh:749-755, 798-818).
- `RiskConfig` ya contiene `volFactorMin`, `volFactorMax` y `atrLookback` (RiskPolicy.mqh:26-30, 71-75). El ATR se lee desde la barra cerrada (`CopyBuffer(..., 1, lookback, ...)`), así que dentro de una barra no cambia (MarketContext.mqh:142-173).
- El panel es una proyección pura (`DashboardState` + `LmDashboardLines`) y `CChartDashboardRenderer` crea solo `OBJ_LABEL` con el prefijo `LMROBOT_PANEL_`; `Clear()` borra todo objeto con ese prefijo (Dashboard.mqh:453-462).
- `CDashboard` compara estados con `LmDashboardStateEquals`, así que un cambio de riesgo solo redibuja si el riesgo es parte del estado.
- `EA/LmRobot.mq5` no tiene `OnChartEvent`.

## Goals / Non-Goals

**Goals:**

- Un único riesgo vivo por instancia, propiedad de `CLmRuntime`, usado por todo el dimensionamiento.
- Dos modalidades excluyentes: `Manual`, con control de dos botones de paso fijo 0.5 y rango 0.5–10, y `Auto`, con riesgo derivado de la volatilidad relativa.
- Conmutación en caliente entre modalidades, conservando el riesgo vivo como base y sin reiniciar el EA.
- En modo `Auto`, evitar el doble ajuste por volatilidad: el porcentaje de riesgo ya transporta la señal.
- Refresco inmediato del panel tras un clic, sin lógica de trading en el handler de eventos.
- Lógica de ajuste y de riesgo automático probable sin depender del gráfico.

**Non-Goals:**

- No se agregan inputs de paso o rango (`RiskStepPct` queda fuera): el paso y el rango son constantes del control manual.
- El modo conmutado en caliente no se persiste: al reiniciar, la modalidad vuelve al input `RiskMode`.
- No hay persistencia por cuenta/magic ni sincronización entre instancias del EA.
- No se agranda ni se reduce el volumen de posiciones ya abiertas.
- No se agregan aún otras variables a la modalidad automática (spread, drawdown, sesión); quedan para cambios posteriores.
- No se modifica el comportamiento de `MaxBasketLossPct` ni de los demás guards.

## Decisions

### 1. La modalidad y el riesgo base viven en `RiskConfig`

`RiskPolicy.mqh` agrega la modalidad y separa el riesgo base del riesgo vivo:

```cpp
enum ENUM_LM_RISK_MODE
  {
   LM_RISK_MANUAL = 0,
   LM_RISK_AUTO   = 1
  };

struct RiskConfig
  {
   // ...
   ENUM_LM_RISK_MODE riskMode;      // modalidad vigente; el input es solo el valor inicial
   double            riskBasePct;   // base del calculo automatico; se captura al entrar en Auto
   double            autoRiskMaxPct; // tope maximo del riesgo automatico (input)
   double            riskPct;       // riesgo vivo usado para dimensionar
   // ...
  };
```

`LmDefaultRiskConfig` completa `riskMode = LM_RISK_AUTO`, `riskBasePct = riskPct`, `autoRiskMaxPct = 6.0` y `riskPct` con el valor por defecto actual. `OnInit` asigna `riskMode` desde el input `RiskMode` (también `Auto` por defecto) y `riskBasePct = riskPct = RiskPct`; `riskBasePct` no se toca mientras la modalidad es manual. Al iniciar en `Auto`, la base es el input `RiskPct` y el primer `ProcessTick` aplica la política automática. Los tests que ejercitan el control manual deben fijar `riskMode = LM_RISK_MANUAL` de forma explícita, porque la configuración por defecto ya no es manual.

- **Por qué**: el dimensionamiento y el panel ya consumen `config.risk`; mantener una sola fuente de verdad evita duplicar estado entre EA, runtime y panel.
- **Alternativa descartada**: variable de riesgo en el EA reinyectada en el runtime cada tick. Duplica estado y abre una ventana donde el panel y el sizing discrepan.

### 2. Política automática como función pura en `RiskPolicy.mqh`

```cpp
double LmAutoRiskPct(const double basePct,
                     const double atrPips,
                     const double avgAtrPips,
                     const double minFactor,
                     const double maxFactor,
                     const double maxRiskPct);
```

La función aplica la política ya existente y acota el resultado:

```
factor_vol = LmVolatilityFactor(atrPips, avgAtrPips, minFactor, maxFactor)
tope       = clamp(maxRiskPct, 0.5, 10.0)
riesgo     = clamp(basePct * factor_vol, 0.5, tope)
riesgo     = MathRound(riesgo * 100.0) / 100.0
```

`LmVolatilityFactor` ya devuelve `1.0` cuando falta `atrPips` o `avgAtrPips`, de modo que sin lectura válida el riesgo automático queda en `clamp(basePct, 0.5, tope)`. El acotado final garantiza que el riesgo automático siempre sea operable y visible con dos decimales. El mínimo permanece fijo en 0.5; solo el tope superior es configurable mediante el input `AutoRiskMaxPct`, cuyo rango válido es 0.5–10.0 y se valida en `OnInit`. La función sanea el tope a ese mismo rango para no depender de la validación del EA.

- **Por qué**: reutiliza la misma noción de volatilidad relativa que ya usa el lote, es testeable sin gráfico y no depende del estado del runtime.
- **Alternativa descartada**: calcular el riesgo inline en `ProcessTick`. Se duplicaría con el panel y con los tests, y sería difícil verificar los topes y el redondeo.

### 3. `CLmRuntime` recalcula el riesgo automático en cada tick

`ProcessTick` ejecuta, antes de procesar las estrategias:

```cpp
if(m_config.risk.riskMode == LM_RISK_AUTO)
  {
   double atrPips    = m_market.AtrPips();
   double atrAvgPips = m_market.AtrAvgPips();
   double riskPct    = LmAutoRiskPct(m_config.risk.riskBasePct,
                                     atrPips, atrAvgPips,
                                     m_config.risk.volFactorMin,
                                     m_config.risk.volFactorMax,
                                     m_config.risk.autoRiskMaxPct);
   m_config.risk.riskPct = riskPct;
  }
```

Como el ATR se lee de la última barra cerrada, el riesgo automático es estable dentro de una barra y solo cambia cuando cambia esa lectura. En modo `Manual` el bloque no se ejecuta y `riskPct` conserva el valor ajustado por los botones.

`bool SetRiskPct(const double pct)` valida `pct > 0` y finito, escribe `m_config.risk.riskPct` y **devuelve `false` sin escribir cuando `riskMode == LM_RISK_AUTO`**. El ajuste manual no puede pisar la política automática.

- **Por qué**: el riesgo automático es una propiedad del runtime, no del handler de eventos, y se actualiza con la misma cadencia que el resto del estado de mercado.
- **Alternativa descartada**: recalcular solo en `RefreshPanel`. El panel se refresca por eventos y podría mostrar un riesgo distinto del que usa el sizing.

### 4. Conmutación de modalidad en caliente con continuidad

`CLmRuntime` expone `bool SetRiskMode(const ENUM_LM_RISK_MODE mode)`:

- **Manual → Auto**: captura `m_config.risk.riskBasePct = m_config.risk.riskPct` y recalcula `m_config.risk.riskPct` con `LmAutoRiskPct` usando la lectura de ATR vigente y el tope `autoRiskMaxPct`. Si no hay ATR válido, el factor es `1.0` y el riesgo queda en la base acotada a 0.5–`AutoRiskMaxPct`.
- **Auto → Manual**: deja `m_config.risk.riskPct` en el último valor automático y habilita los botones `+`/`-` desde ese valor.
- Mientras permanece en `Auto`, `riskBasePct` queda fijo en el valor capturado al entrar; cada tick recalcula desde esa base y **no** desde el resultado automático anterior, para que el ajuste no se componga.
- La conmutación no envía órdenes, no cierra posiciones y no redimensiona lo abierto; solo cambia la fuente del riesgo para las órdenes futuras. El handler del EA refresca el panel después del cambio.

- **Por qué**: el operador espera que el riesgo no salte al alternar. La base capturada al entrar en Auto conserva la intención del ajuste manual, y el último valor automático es el punto de partida natural al volver a manual.
- **Alternativa descartada**: usar siempre el input `RiskPct` como base del modo automático. Es más simple, pero descarta el ajuste manual y produce un salto de riesgo al conmutar.
- **Trade-off**: conmutar repetidamente no acumula volatilidad, pero el riesgo automático depende de la base capturada en cada entrada; el panel muestra el valor vigente para que la transición sea visible.

### 5. En modo automático el lote no vuelve a aplicar volatilidad

`LmPlanInitialOrder` calcula `factor_volatilidad` internamente a partir de `atrPips`/`avgAtrPips`. En modo automático el runtime le pasa `avgAtrPips = atrPips`, con lo que la razón es `1.0` y el lote no vuelve a ajustarse por volatilidad. En modo manual sigue pasando el `atrAvgPips` real y conserva el comportamiento actual. La distancia `SL_efectivo` se sigue derivando del ATR en ambos modos.

El mismo criterio aplica a las dos llamadas de dimensionamiento: la apertura inicial y el recálculo del lote base dentro de `OpenGrid`.

- **Por qué**: el riesgo automático ya expresa la volatilidad mediante `factor_vol`; aplicarla otra vez en el lote duplicaría el efecto y haría que un régimen volátil redujera el tamaño dos veces.
- **Alternativa descartada**: agregar un parámetro `applyVolFactor` a `LmPlanInitialOrder`. Cambia la firma de la política y obliga a propagar el flag; igualar `avgAtrPips` reutiliza la función existente sin ramas nuevas en el cálculo.
- **Trade-off**: en modo automático el lote ya no sube cuando la volatilidad baja por debajo de la media. Es intencional: el riesgo sube en su lugar.

### 6. Ajuste manual como función pura en `Dashboard.mqh`

Constantes y helpers junto al panel (sin cambios respecto del control ya implementado):

```cpp
#define LM_RISK_MIN_PCT   0.5
#define LM_RISK_MAX_PCT   10.0
#define LM_RISK_STEP_PCT  0.5

bool LmRiskInControlRange(const double riskPct);
bool LmRiskCanStep(const double riskPct, const int direction);
double LmNextRiskPct(const double riskPct, const int direction);
int    LmRiskButtonDirection(const string objectName); // -1, +1 o 0
bool   LmRiskModeButton(const string objectName);      // true si es el boton de modo
```

`LmNextRiskPct` redondea a dos decimales (`MathRound(v * 100.0) / 100.0`), compara con tolerancia y devuelve el valor actual cuando el paso queda fuera de rango o el riesgo está fuera del rango operable. `direction` es `-1` o `+1`.

- **Por qué**: el handler del EA y los tests comparten exactamente la misma regla; no hace falta simular clics para probar límites y redondeo.
- **Alternativa descartada**: lógica inline en `OnChartEvent`. No es testeable sin gráfico y se duplicaría con el renderer para decidir el atenuado.

### 7. El estado del panel incluye modalidad, riesgo y habitabilidad

`DashboardState` agrega:

```cpp
ENUM_LM_RISK_MODE riskMode;  // modalidad mostrada
double riskPct;              // riesgo vivo mostrado
bool   riskInRange;          // 0.5 <= riskPct <= 10
bool   canDecrease;          // riskMode == LM_RISK_MANUAL && riskInRange && riskPct > 0.5
bool   canIncrease;          // riskMode == LM_RISK_MANUAL && riskInRange && riskPct < 10.0
```

`LmBuildDashboardState` y `LmBuildPortfolioDashboardState` reciben el riesgo desde `config.risk` (como ya reciben `RiskConfig`) y copian la modalidad y el riesgo al estado. `LmDashboardStateEquals` compara `riskMode`, `riskPct` y los tres flags, de modo que un clic o un cambio de modalidad siempre redibuja aunque la canasta no haya cambiado.

El panel agrega una línea de riesgo: en modo único queda como línea 9 (`lines[8]`), después del PnL; en portafolio va después de la línea de PnL (`lines[3 + rowCount]`). Textos:

- `Riesgo: 4.00% (manual)`
- `Riesgo: 2.35% (auto)`

La leyenda `(fuera de 0.5-10: control deshabilitado)` se agrega solo en modo manual cuando el riesgo está fuera de rango. En modo automático el valor siempre queda dentro de 0.5–`AutoRiskMaxPct` por la política, así que la leyenda no aplica.

### 8. Botones `OBJ_BUTTON` administrados por el renderer

`CChartDashboardRenderer` crea tres botones con nombres estables dentro del prefijo existente:

- `LMROBOT_PANEL_BTN_RISK_DOWN` (texto `-`)
- `LMROBOT_PANEL_BTN_RISK_MODE` (texto `Modo: Manual` o `Modo: Auto` según `riskMode`)
- `LMROBOT_PANEL_BTN_RISK_UP` (texto `+`)

Se crean en el primer render si no existen (igual que las etiquetas), se ubican en una fila debajo de la última línea (`y = 18 + lineCount * 16 + 6`). Los botones `-` y `+` miden 22x18 px; el botón de modo es más ancho (unos 92x18 px) para mostrar la etiqueta y se ubica entre ambos. `ObjectCount()` y `CreatedCount()` ya los contarán porque usan el prefijo; `Clear()` los elimina.

MQL5 no tiene una propiedad "disabled" para `OBJ_BUTTON`: el atenuado se implementa con `OBJPROP_BGCOLOR`/`OBJPROP_COLOR` grises cuando `canDecrease`/`canIncrease` es falso. Como esos flags ya incluyen la modalidad, en modo `Auto` los botones `+`/`-` quedan atenuados, mientras que el botón de modo permanece siempre habilitado. El handler descarta el clic de `+`/`-` en automático y desmarca todos los botones con `OBJPROP_STATE = false` después de cada clic para que no queden apretados.

- **Por qué**: reutiliza el ciclo de vida, el prefijo y la limpieza que ya existen; no hay que tocar `OnDeinit`.
- **Alternativa descartada**: `CButton` de `<Controls\Button.mqh>` dentro de un `CAppDialog`. Introduce un diálogo y otro modelo de eventos para tres botones que ya encajan en el renderer actual.

### 9. `OnChartEvent` delega, respeta la modalidad y refresca el panel

En `EA/LmRobot.mq5`:

```cpp
void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK)
      return;

   if(LmRiskModeButton(sparam))
     {
      ENUM_LM_RISK_MODE current = g_runtime.Config().risk.riskMode;
      g_runtime.SetRiskMode(current == LM_RISK_MANUAL ? LM_RISK_AUTO
                                                      : LM_RISK_MANUAL);
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      RefreshPanel();
      return;
     }

   int direction = LmRiskButtonDirection(sparam); // -1, +1 o 0
   if(direction == 0)
      return;

   if(g_runtime.Config().risk.riskMode == LM_RISK_AUTO)
     {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      return;
     }

   double current = g_runtime.Config().risk.riskPct;
   double next    = LmNextRiskPct(current, direction);
   if(next != current)
      g_runtime.SetRiskPct(next);

   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   RefreshPanel();
}
```

`RefreshPanel()` extrae el bloque que hoy está al final de `OnTick` (leer `Config()`, armar `StrategyView[]`, construir el estado y llamar a `g_dashboard.Update`). `OnTick` lo reutiliza. El handler no envía órdenes ni modifica posiciones; solo cambia el riesgo o la modalidad y redibuja.

- **Por qué**: el clic se refleja de inmediato aunque el símbolo tenga pocos ticks, y la lógica de trading sigue concentrada en `ProcessTick`.
- **Backtesting**: en el tester sin modo visual no hay clics; la modalidad inicial se elige por input y el riesgo automático se recalcula en `ProcessTick`, así que las corridas siguen siendo reproducibles.

### 10. Sin persistencia y sin recorte del input en modo manual

`OnInit` asigna `config.risk.riskMode = RiskMode`, `config.risk.riskPct = RiskPct`, `config.risk.riskBasePct = RiskPct` y `config.risk.autoRiskMaxPct = AutoRiskMaxPct` sin recortar `RiskPct`. Al reiniciar, `RuntimeConfig` se reconstruye desde los inputs: la modalidad vuelve a la del input (`Auto` por defecto, aunque se haya conmutado en caliente), en modo manual el riesgo vuelve al valor original y en modo automático vuelve a partir de `RiskPct`, acotado por `AutoRiskMaxPct`, y se recalcula en el primer tick. No se crea variable global ni clave por cuenta/magic. Si `RiskPct` está fuera de 0.5–10 en modo manual, `riskInRange` es falso, ambos botones quedan atenuados y `LmNextRiskPct` devuelve el valor sin cambios. `AutoRiskMaxPct` se valida en `OnInit` dentro de 0.5–10.0; fuera de ese rango el EA no inicia.

## Risks / Trade-offs

- **Con `Auto` por defecto, un `RiskPct` calibrado fuera de 0.5–10 se lleva al rango 0.5–`AutoRiskMaxPct` al arrancar** → es el rango declarado de la modalidad automática; para conservar riesgos finos (0.08, 0.80) hay que iniciar el EA con `RiskMode=Manual`. Se documenta en `docs/riesgo.md`.
- **Un `AutoRiskMaxPct` menor que `RiskPct` recorta el riesgo automático desde el primer tick** → el tope manda sobre la base; el panel muestra el valor efectivo y el operador puede subir el input o pasar a `Manual`. El tope no se ajusta en caliente desde el panel.
- **La conmutación en caliente no se persiste** → al reiniciar vuelve al input `RiskMode`; es intencional para que las corridas calibradas arranquen siempre desde la configuración declarada.
- **Conmutar arrastra el riesgo vivo como base** → pasar a automático desde un riesgo manual alto puede mantener un riesgo más alto del habitual hasta que el ATR lo ajuste; el panel muestra el valor vigente y el operador puede volver a manual o reiniciar.
- **Subir riesgo a mitad de canasta puede bloquear el próximo paso** → `MaxBasketLossPct` rechaza, no recorta. Se documenta en `docs/riesgo.md` y en el escenario "Presupuesto de canasta agotado"; no se cambia el guard en este cambio.
- **El paso fijo de 0.5 es enorme para riesgos calibrados bajos** → el input fuera de rango deja el control deshabilitado y no se altera el dimensionamiento; para operar con riesgos finos se sigue usando el input.
- **Los botones no se pueden deshabilitar de verdad en MQL5** → se atenúan y el handler ignora el clic; el estado del panel es la fuente de verdad.
- **Doble clic rápido en modo manual** → cada evento recalcula desde `Config()` y aplica un solo paso; dos eventos aplican dos pasos, que es el comportamiento esperado.
- **El riesgo automático solo cambia por barra cerrada** → es intencional para evitar que el sizing reaccione al ruido intrabar; si se necesita más reactividad, se evalúa en un cambio posterior.
- **Pruebas del panel dependen del gráfico** → los helpers puros cubren la regla manual, la política automática y la conmutación; los tests de objetos se actualizan a 9 líneas + 3 botones (12 objetos) en modo único y `rowCount + 4` líneas + 3 botones en portafolio.

## Migration Plan

1. Agregar el enum `ENUM_LM_RISK_MODE`, los campos `riskMode`/`riskBasePct`/`autoRiskMaxPct` a `RiskConfig` y la función `LmAutoRiskPct` con tope configurable.
2. Agregar los inputs `RiskMode` (por defecto `Auto`) y `AutoRiskMaxPct` (por defecto `6.0`, rango 0.5–10.0) en el EA, validarlos y mapearlos junto con `RiskPct` al `RuntimeConfig`.
3. Implementar el recálculo automático en `ProcessTick`, el rechazo de `SetRiskPct` en modo automático, la conmutación `SetRiskMode` con continuidad y el `avgAtrPips = atrPips` en el dimensionamiento automático.
4. Agregar modalidad, riesgo y flags al estado del panel, la línea con `(manual|auto)`, el atenuado de botones por modalidad y el botón de modo.
5. Extraer `RefreshPanel()` y agregar `OnChartEvent` con el toggle de modalidad y el guard de `+`/`-`.
6. Actualizar tests, compilar `tests/TestRunner.mq5` y `EA/LmRobot.mq5`, y documentar ambas modalidades, el tope `AutoRiskMaxPct` y la conmutación.

Rollback: volver a `RiskMode=Manual` como valor por defecto y quitar el botón de modo; el control manual y el setter siguen funcionando sin la política automática.

## Open Questions

Ninguna que cambie el alcance. La incorporación de otras variables a la modalidad automática (spread, drawdown, sesión) queda para cambios posteriores.
