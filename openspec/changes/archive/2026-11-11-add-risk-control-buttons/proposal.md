# Proposal

## Why

Hoy el riesgo (`RiskPct`) solo puede cambiarse en los inputs del EA, lo que obliga a reiniciar o recompilar para ajustarlo durante la operación. El operador necesita elegir entre controlar el riesgo manualmente en vivo, con un paso predecible, o delegarlo en una política automática que lo adapte a la volatilidad, sin detener la operación y sin alterar el dimensionamiento ya comprometido de las posiciones abiertas. El caso normal es operar desatendido: el robot debe arrancar y permanecer en modo automático, y el ajuste manual queda como excepción para cuando el operador está delante de la pantalla.

## What Changes

- Se agrega el input `RiskMode` con dos modalidades: `Auto` (por defecto) y `Manual`. El input define la modalidad **inicial**; el panel incluye un tercer botón que alterna la modalidad **en caliente**.
- Se agrega el input `AutoRiskMaxPct` (por defecto `6.0`, rango válido 0.5–10.0) como tope máximo del riesgo automático. El mínimo sigue fijo en 0.5. Un valor fuera de rango impide iniciar el EA.
- En modo `Manual`, dos botones en el gráfico, `+` y `-`, suben y bajan el riesgo vivo de a **0.5 puntos porcentuales absolutos**. El riesgo arranca en el input `RiskPct` y se mantiene **solo en memoria**.
- En modo `Auto`, el riesgo vivo se calcula a partir de una base y la volatilidad. La base es el input `RiskPct` al iniciar y el riesgo vivo del momento al conmutar desde manual:
  `factor_vol = clamp(ATR_medio / ATR_actual, VolFactorMin, VolFactorMax)` y
  `riesgo = clamp(base * factor_vol, 0.5, AutoRiskMaxPct)`, redondeado a dos decimales.
  Sin lectura válida de ATR se usa `factor_vol = 1.0`. Se recalcula en cada tick desde el último ATR cerrado y solo cambia cuando cambia esa lectura.
- En modo `Auto` los botones `+`/`-` quedan deshabilitados y los clics se ignoran; el panel muestra `Riesgo: X.XX% (auto)`.
- El botón de modo muestra `Modo: Manual` o `Modo: Auto` y siempre está habilitado. Al pasar de `Manual` a `Auto`, la política automática toma como base el riesgo vivo actual; al volver a `Manual`, se conserva el último riesgo automático como punto de partida de los botones `+`/`-`. El cambio de modalidad no reinicia el EA ni modifica posiciones abiertas.
- Para no aplicar la volatilidad dos veces, en modo `Auto` el `factor_volatilidad` del lote se fija en `1.0`; en modo `Manual` se conserva el comportamiento actual. La distancia `SL_efectivo` sigue dependiendo del ATR en ambos modos.
- El riesgo vivo se usa para dimensionar las próximas órdenes: la apertura de canastas nuevas y **el próximo paso de grid y los siguientes** de una canasta abierta. Las posiciones ya abiertas no se redimensionan.
- El rango operable manual es **0.5% a 10%** y los botones se deshabilitan al alcanzar el límite. En modo `Auto` el riesgo calculado se acota entre 0.5 y el input `AutoRiskMaxPct`.
- El input `RiskPct` **no se recorta** en modo `Manual`. Si queda fuera de 0.5–10, los botones permanecen deshabilitados y el panel lo indica, para no romper las corridas calibradas (por ejemplo `RiskPct=0.08` o `4.00`).
- El panel muestra el riesgo vivo, la modalidad, su estado (dentro de rango, en el mínimo o en el máximo) y el botón que alterna la modalidad.
- No hay persistencia por cuenta/magic ni cambios en la lógica de los guards: al reiniciar, la modalidad y el riesgo vuelven a los inputs (`RiskMode` y `RiskPct`). `MaxBasketLossPct` sigue rechazando un paso que no entra en el presupuesto.

## Capabilities

### New Capabilities

(Ninguna)

### Modified Capabilities

- `ea-runtime`: el panel de estado incorpora el riesgo vivo, su modalidad (`manual`/`auto`), el botón que alterna la modalidad en caliente y los controles `+`/`-` habilitados solo en modo manual, con manejo de clics, límites y deshabilitado en los extremos.
- `risk-guard`: el riesgo usado para dimensionar pasa a ser un valor vivo cuya fuente depende de la modalidad: ajuste manual en runtime o política automática basada en volatilidad. La conmutación en caliente conserva el riesgo vivo como base y el ajuste por volatilidad del lote se desactiva en modo automático para no duplicar la señal.

## Impact

- `Include/LmRobot/Risk/RiskPolicy.mqh`: enum `ENUM_LM_RISK_MODE`, campos de modalidad, riesgo base y tope automático en `RiskConfig`, y función pura `LmAutoRiskPct` con el tope configurable para la política automática.
- `Include/LmRobot/UI/Dashboard.mqh`: nuevos objetos `OBJ_BUTTON` (riesgo y modo), modalidad y riesgo vivo en `DashboardState`, líneas del panel con la modalidad y renderizado/limpieza de botones.
- `Include/LmRobot/Core/Runtime.mqh`: `CLmRuntime` recalcula el riesgo automático en cada tick, expone un setter del riesgo vivo (rechazado en modo automático), conmuta la modalidad en caliente conservando la continuidad del riesgo y fija el factor de volatilidad del lote en `1.0` cuando la modalidad es automática.
- `EA/LmRobot.mq5`: nuevos inputs `RiskMode` como modalidad inicial y `AutoRiskMaxPct` como tope del riesgo automático, validación de ambos, mapeo al `RuntimeConfig` y `OnChartEvent` para `CHARTEVENT_OBJECT_CLICK` que alterna la modalidad y aplica o ignora los clics de `+`/`-` según corresponda.
- `tests/TestRunner.mq5`: pruebas del ajuste manual, los límites, la política automática, la ausencia de doble ajuste por volatilidad, la aplicación al próximo paso de grid y el nuevo conteo de objetos del panel.
- `docs/operacion.md` y `docs/riesgo.md`: documentación de las dos modalidades, del control manual y de su relación con `RiskPct`.
- Interacción conocida: en modo manual, subir el riesgo a mitad de canasta puede hacer que `MaxBasketLossPct` rechace el próximo paso en lugar de reducirlo.
