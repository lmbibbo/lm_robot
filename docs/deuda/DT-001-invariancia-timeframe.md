# DT-001 — Invariancia de riesgo y perfil entre timeframes

| Campo | Valor |
|---|---|
| ID | DT-001 |
| Estado | Abierta — decisión pendiente |
| Severidad | Alta |
| Fecha de registro | 2026-11-12 |
| Origen | Revisión de `CodigoRefactorizado.mq4`, `CodigoRefactorizado.mq5`, `CodigoRefactorizado copy2.mq4` y comparación con `LmRobot` |
| Alcance | `RiskPolicy`, `Runtime`, `MarketContext`, `BasketState`, inputs del EA y sets de referencia |
| Decisión que la cierra | ¿El perfil se ancla **por operación** (volatilidad) o **por tiempo** (calendario)? |
| Documentos relacionados | [Modelo de riesgo](../riesgo.md) · [Paridad de señales](../paridad.md) · [Comparación justa](../comparacion-justa.md) |

## 1. Resumen

- "Mismo riesgo y mismo perfil de ganancia entre timeframes" puede significar
  tres cosas incompatibles: misma geometría en **precio**, misma geometría en
  **volatilidad** o mismo ritmo en **tiempo**. No se pueden tener las tres.
- `LmRobot` en la configuración de paridad ya es casi **invariante en precio**:
  TP, grid y SL son distancias absolutas en pips y el SL está dominado por el
  piso `SlPips=1000`. El riesgo **por canasta** es aproximadamente constante; el
  riesgo **por día** no lo es.
- El refactor agrega un "perfil por TF", pero solo el grid escala con ATR. El TP
  es una tabla manual, el SL es un piso absoluto y la señal sigue leyendo el TF
  del gráfico. No es una ley de escala.
- Las tres asimetrías que sí rompen la invariancia son: el guard de ATR anclado
  al TF del gráfico, el reloj del grid por barra y la cadencia de reapertura sin
  tope.
- La decisión pendiente es de producto, no de código: **perfil por operación**
  (opciones B/D) o **perfil por tiempo** (opción A). Sin esa decisión, portar la
  tabla del refactor es prematuro.

## 2. Las tres invariancias

| Invariancia | Qué se mantiene | Qué se rompe | Efecto en el arquetipo |
|---|---|---|---|
| **Precio** (pips fijos) | Geometría en dólares: TP, grid y SL idénticos en todos los TF | Cambia cuándo se muestrea la entrada | Riesgo por canasta constante; la cantidad de canastas por día depende del TF |
| **Volatilidad** (`k · ATR`) | Geometría en unidades de ATR; win rate y `f*` por operación parecidos | Cambia la cantidad de operaciones por día | En TF bajos se multiplican las canastas (~60× de M1 a H1) |
| **Tiempo** (por día/mes) | Mismo ritmo de trades y mismo DD mensual | Requiere tope de cadencia y/o riesgo por canasta decreciente con la frecuencia | Ninguna implementación actual lo hace |

Ninguna de las dos implementaciones elige una y la cumple: el refactor mezcla
grid por volatilidad, TP por costos y SL por precio. `LmRobot` es
deliberadamente precio-invariante, salvo los bordes listados en §4.

## 3. Qué es invariante hoy en `LmRobot`

Configuración de referencia: set `P-NS-ALL` / R11 (`RiskPct=4.0`,
`SlPips=1000`, `TpPips=8`, `GridStepPips=22`, `MaxGridSteps=19`,
`LotMultiplier=1.667`, `MaxAtrPips=15`, `AtrTimeframe=PERIOD_CURRENT`).

Las distancias se construyen en pips y se convierten con `pipSize`
(`Runtime.mqh:544-545`, `BasketState.mqh:188-189`), así que no dependen de que el
símbolo tenga 4 o 5 dígitos. Eso ya resuelve la portabilidad que el refactor
rompe al trabajar en `Point`.

| Aspecto | ¿Invariante entre TF? | Dónde |
|---|---|---|
| Geometría en pips (TP, grid, SL) | Sí | `Runtime.mqh:544-545`, `BasketState.mqh:188-189` |
| Riesgo por canasta | Sí, salvo clamps y redondeo | `RiskPolicy.mqh:185-215` |
| Riesgo por día | **No**: más canastas/día en TF bajo; el guard diario es el único tope | `DailyLossGuard.mqh`, `Runtime.mqh:1006` |
| Cadencia de entrada | **No**: una evaluación por barra del gráfico | `Runtime.mqh:1023` |
| Cadencia de grid | **No**: un paso por barra, dentro del gate | `Runtime.mqh:1050`, `BasketState.mqh:160-167` |
| Filtro de volatilidad | **No**: `MaxAtrPips=15` sobre el ATR del TF del gráfico | `EA/LmRobot.mq5:23,26,135`; `MarketContext.mqh:42-44` |
| Costo relativo | **No**: spread fijo contra TP fijo | 21 % del TP con spread 1,7 pips y TP 8 pips |

### Riesgo por canasta

```
lote            = floor((RiskPct/100 · balance) / (SL · valor_pip_por_lote), step)
riesgo_canasta  = lote · SL · valor_pip_por_lote
```

Con 10.000 USD, `RiskPct=4.0`, `SL=1000` pips y `valor_pip_por_lote ≈ 7,44`:

```
lote = 400 / (1000 · 7,44) = 0,0538 → 0,05
riesgo_canasta = 0,05 · 1000 · 7,44 = 372 USD (3,72 % del balance)
```

El mismo cálculo da el mismo resultado en M1, M10 y H1, porque `max(SlPips,
ATR · AtrSlMultiplier)` queda dominado por el piso de 1000 pips en todos los TF.
La invariancia es **nominal**: el stop está a 1000 pips, así que lo que limita la
pérdida real es el guard diario o el stop-out, no el SL.

### Los clamps rompen la igualdad en los extremos

Ejemplo con los valores iniciales de `docs/riesgo.md` (10.000 USD, 0,5 %,
`MaxLotPerOrder=0.10`, valor del pip 7,44):

| SL | Lote por fórmula | Lote efectivo | Riesgo efectivo |
|---:|---:|---:|---:|
| 40 pips | 0,168 | 0,10 (tope por orden) | 0,30 % |
| 200 pips | 0,034 | 0,03 (redondeo) | 0,45 % |

La invariancia se sostiene "en el medio del rango", no en los extremos. Cualquier
vara de aceptación tiene que medir el riesgo **efectivo**, no el de la fórmula.

## 4. Asimetrías abiertas

| # | Hallazgo | Evidencia | Consecuencia |
|---|---|---|---|
| 4.1 | El guard de volatilidad usa el ATR del TF del gráfico | `EA/LmRobot.mq5:23` (`PERIOD_CURRENT`), `:26` (`MaxAtrPips=15`), `:135`; `MarketContext.mqh:42-44` | Es un interruptor disfrazado de filtro: casi nunca bloquea en M1, bloquea seguido en H1 y casi siempre en H4. La palanca existe (`AtrTimeframe=H1`), pero no es el default |
| 4.2 | El paso de grid solo se evalúa al abrir barra | `Runtime.mqh:1023` (gate) y `:1050` (llamada a `OpenGrid`); `BasketState.mqh:160-167` | En H1, un cruce de 22 pips dentro de la vela se agrega en la barra siguiente y a peor precio. Es una asimetría de ejecución, no de riesgo |
| 4.3 | No hay cooldown entre canastas | `Runtime.mqh:1023` (única cadencia) | Una canasta cerrada por TP se reabre en la barra siguiente: 1 minuto en M1, 1 hora en H1. Con el mismo perfil por canasta, M1 puede completar ~60× más canastas por día |
| 4.4 | El riesgo por día no tiene presupuesto propio | `DailyLossGuard.mqh`; `Runtime.mqh:1006` | El único tope es el guard diario; no hay límite de canastas/día ni de pasos/hora |
| 4.5 | Los topes agregados son por instancia, no por cuenta | `EA/LmRobot.mq5:47-48`; `Runtime.mqh:479-530` | Tres gráficos en la misma cuenta multiplican el presupuesto agregado. "Mismo riesgo por gráfico" no es "mismo riesgo por cuenta" |
| 4.6 | El costo es fijo y el TP también | `TpPips=8`, spread ≈ 1,7 pips | El spread se come ~21 % del TP en cualquier TF. Si se escala el TP hacia abajo, la fracción crece |
| 4.7 | El SL de paridad es nominal | `SlPips=1000`; `MaxBasketLossPct=1000`; `DailyLossLimitPct=1000` | Con el stop a 1000 pips, lo que acota la pérdida es el stop-out. Decir "mantengo el mismo riesgo" equivale a "mantengo el mismo denominador de lotaje" |

## 5. Por qué el "perfil por TF" del refactor no escala

`CodigoRefactorizado.mq4` declara `Timeframe_Scalper=M1` y deriva cuatro
parámetros de ese TF:

| Función | Línea | Qué hace |
|---|---|---|
| `GetLotExponentByTimeframe` | 163 | M1 1,20 → D1 2,00 (default 1,50) |
| `GetPipStepByTimeframe` | 202 | `max(10, ATR(tf) · 2,0) / riskMultiplier` |
| `GetTakeProfitByTimeframe` | 214 | Tabla manual M1 30 → D1 300 puntos |
| `GetLotSizeBasedOnBalance` | 443 | `SL = max(200 pts, ATR · LotExponent(tf))` |

Tabla resultante (5 dígitos, `GeneralStopLoss=200` puntos = 20 pips):

| TF | TP | Grid ≈ 2·ATR | SL nominal | R:R nominal |
|---|---:|---:|---:|---:|
| M1 | 3 pips | ~4 | 20 | 6,7 : 1 |
| M5 | 5 | ~7 | 20 | 4 : 1 |
| M15 | 7 | ~12 | 20 | 2,9 : 1 |
| M30 | 8 | ~18 | 20 | 2,5 : 1 |
| H1 | 10 | ~30 | 20 | 2 : 1 |
| H4 | 15 | ~60 | 20 | 1,3 : 1 |
| D1 | 30 | ~120 | 20 | 0,7 : 1 |
| M10 (default) | 8 | ~12 | 20 | 2,5 : 1 |

Tres observaciones:

1. El **grid** sí es auto-escalable: `2 · ATR(TF)` mantiene constante la geometría
   del grid en unidades de volatilidad.
2. El **TP no** es auto-escalable: es una escalera hecha a mano. En TF bajos
   crece en unidades de ATR (M1: 1,5 ATR; H1: 0,67 ATR). Eso no es un descuido:
   es la forma de que el TP siga siendo mayor que el spread.
3. El **SL no** es auto-escalable: 200 puntos es un piso absoluto y, además,
   `OrderSend(..., 0, tp_open, ...)` pasa SL = 0 (`:372`, `:377`). El "SL" es solo
   el denominador del lotaje.

### El detalle que rompe la idea de "perfil por TF"

El reloj usa `iTime(NULL, Timeframe_Scalper, 0)` (`:809`), pero la señal usa
`iClose(Symbol(), 0, 2)` (`:815`): TF del **gráfico**. El TF declarado mueve el
lotaje, el grid, el TP y el reloj; la dirección de entrada la sigue poniendo el
gráfico. Con `Timeframe_Scalper=M1` adjuntado a H1 se obtiene señal H1 con perfil
de money management M1, y no hay forma de aislar el efecto del TF.

### Tres calibraciones del mismo filtro

| Archivo | `ATR_Timeframe` | `MaxAllowedATR` | Significado |
|---|---|---:|---|
| `CodigoRefactorizado.mq4` | `PERIOD_M1` (`:69`) | 150 pts | 15 pips sobre M1: casi nunca bloquea |
| `CodigoRefactorizado.mq5` | `PERIOD_M1` (`:82`) | 150 pts | Igual que el anterior |
| `CodigoRefactorizado copy2.mq4` | `PERIOD_H1` (`:69`) | 150 pts | 15 pips sobre H1: bloquea seguido |
| `CodigoOriginalMT4.mq4` | `PERIOD_H1` (`:33`) | 150 pts | Igual que `copy2` |

No son el mismo filtro. Cualquier comparación entre esos archivos que ignore este
punto está midiendo otra cosa.

## 6. Riesgo por canasta vs riesgo por tiempo

| | Riesgo por canasta | Riesgo por tiempo |
|---|---|---|
| Fórmula | `lote · SL · valor_pip` | `(canastas/día) · riesgo/canasta` |
| Estado | Ya invariante, salvo clamps | **No invariante**: ~60× más canastas/día en M1 |
| Qué lo controla | `RiskPolicy` | Solo `DailyLossLimitPct` hoy |

El perfil del arquetipo (grid + TP de canasta, SL lejano) se define por:

```
f*     = TP / (TP + SL)          fracción de riesgo que gana cada canasta
p_win  ≈ SL / (TP + SL)          probabilidad de tocar TP antes que SL
E[R]   = p_win · TP − (1 − p_win) · SL − C
```

Con TP=8 y SL=1000: `f* ≈ 0,8 %`, `p_win ≈ 99,2 %`. Es el perfil "casi siempre
gano 8 pips, alguna vez pierdo 1000". Se mantiene igual en cualquier TF **mientras
las distancias sean absolutas**.

Si se escalan las distancias por ATR para que la geometría sea constante en
volatilidad, el costo fijo por operación se come una fracción creciente del TP:

| TF | ATR aprox. (pips) | TP si se escala (k≈0,53) | Spread 1,7 pips | Spread/TP |
|---|---:|---:|---:|---:|
| M1 | 2,0 | 1,1 | 1,7 | ~160 % |
| M10 | 6,0 | 3,2 | 1,7 | ~53 % |
| H1 | 15,0 | 8,0 | 1,7 | ~21 % |

En M1 el TP sería más chico que el spread. No hay forma de tener a la vez la
misma geometría en ATR y el mismo resultado neto en TF bajos. La tabla del
refactor lo resuelve a mano: en M1 pone TP=3 pips (no 1). Es un compromiso de
**costos**, no una ley de escala.

Falta el otro componente: la señal. `close[2]` vs `close[1]` no tiene por qué
tener el mismo poder predictivo en M1 que en H1. Escalar distancias preserva el
riesgo; no fabrica edge. Si el edge está en la reversión de una vela horaria, en
M1 no existe. Eso solo se responde midiendo.

## 7. Opciones de diseño

| Opción | Qué hace | Ventaja | Costo |
|---|---|---|---|
| **A. Paridad / pips absolutos** | Conserva la geometría actual y arregla solo los bordes | Mantiene R11 y la paridad MT4; cambio acotado | No logra geometría constante en ATR |
| **B. Geometría nativa en ATR** | `TP=k_t·ATR`, `grid=k_g·ATR`, `SL=k_s·ATR`, con piso `TP ≥ m·spread` y tope de cadencia | Único camino a perfil por operación parecido en M1/M10 | Rompe paridad; hay que recalibrar todo |
| **C. Portar la tabla del refactor** | Tabla TF → TP/LotExp | Fácil de explicar | Incompleta (M10 cae en default), depende de dígitos, no preserva el riesgo |
| **D. Híbrido** | ATR para distancias; tabla solo para piso de costos y cadencia; modos `PARIDAD` y `PERFIL` | No rompe las corridas de referencia | Dos modos que mantener y documentar |

Lectura: si el objetivo es "mismo riesgo y mismo perfil de ganancia entre TF", el
camino no es portar la tabla, es **definir el invariante y medirlo**. La opción C
no se recomienda.

## 8. Decisión pendiente

> ¿El perfil se ancla por operación o por tiempo?

| Si la respuesta es… | Entonces… | Camino |
|---|---|---|
| **Por operación** (misma geometría en ATR, mismo win rate y `f*` por canasta) | Distancias en ATR y cadencia limitada; aceptar recalibrar y romper paridad | B / D |
| **Por tiempo** (mismo retorno y DD por mes) | Conservar pips absolutos y atacar solo el guard de ATR y la cadencia, sin tocar la geometría | A |

Esta decisión bloquea el diseño de cualquier "modo TF". No conviene implementar
nada del refactor antes de tomarla.

## 9. Plan de medición

Antes de escribir una línea de motor:

1. Conservar el modo `PARIDAD` tal cual. R11 sigue siendo la referencia.
2. Medir el modo actual en M1 y M10 con el harness existente
   (`tests/EngineScalperExport.mq5` es TF-paramétrico y `OnTester` ya escribe el
   CSV de métricas). Eso responde si la invariancia de precio alcanza.
3. Solo si no alcanza, agregar un modo `PERFIL` separado con geometría en ATR,
   piso de TP en múltiplos de spread y tope de cadencia por tiempo.
4. Fijar la vara de aceptación **antes** de tocar nada.

### Vara de aceptación propuesta

| Métrica | Criterio |
|---|---|
| Profit factor | Dentro de ±0,2 del H1 |
| Win rate | ±5 puntos porcentuales |
| DD máximo | ±3 puntos porcentuales |
| Trades/día | Entre 0,5× y 2× el H1 |
| Riesgo efectivo por canasta | Medido, no el de la fórmula; incluye clamps y redondeo |

La comparación debe usar el mismo feed, spread, capital y ventana
([`comparacion-justa.md`](../comparacion-justa.md)).

## 10. Qué no portar del refactor

| Pieza | Problema | Consecuencia |
|---|---|---|
| Tabla TP / LotExp | Solo cubre M1/M5/M15/M30/H1/H4/D1 | M10 cae en default (1,5 / 80 pts); M2, M3, M6, M12, H2, H3, H6, H8, H12, W1 también |
| Unidades en `Point` | 100 puntos = 10 pips en 5 dígitos, 100 pips en 4 | Rompe la portabilidad que `Instrument.mqh:30` ya resolvió con `pipSize` |
| `Timeframe_*` vs señal del gráfico | El perfil no va atado a la señal | No se puede aislar el efecto TF |
| `LotExponent` como multiplicador de SL | Dos conceptos en una función | `LmRobot` ya los separa (`LotMultiplier`, `AtrSlMultiplier`) |
| SL = 0 en `OrderSend` | El "riesgo" es solo denominador | No hay riesgo acotado; no sirve como modelo |
| `MaxAllowedATR` en puntos y ATR global | Tres calibraciones entre archivos | El mismo filtro cambia de significado según el archivo |

## 11. Criterios de cierre

La entrada se puede marcar `Decidida` cuando exista:

- [ ] Una definición escrita del invariante elegido (precio, volatilidad o tiempo).
- [ ] La respuesta a la pregunta de §8, con el motivo.
- [ ] La tabla de aceptación de §9 con los umbrales acordados.
- [ ] La corrida base M1/M10 del modo actual, con CSV y fecha.
- [ ] El vínculo al cambio de OpenSpec que implementa la opción elegida.

## 12. Referencias

- `CodigoRefactorizado.mq4:18,47,69,163,202,214,372,377,443,454-459,809,815`
- `CodigoRefactorizado.mq5:80,82,401-402,797-798`
- `CodigoRefactorizado copy2.mq4:67,69`
- `CodigoOriginalMT4.mq4:31,33`
- `EA/LmRobot.mq5:23-30,33-48,135`
- `Include/LmRobot/Core/Runtime.mqh:169-200,544-545,1006,1023,1050`
- `Include/LmRobot/Core/BasketState.mqh:160-167,188-189`
- `Include/LmRobot/Risk/RiskPolicy.mqh:185-215`
- `Include/LmRobot/Core/MarketContext.mqh:42-44`
- `reportes/sets/mt5/P-NS-ALL.set` (configuración de paridad R11)
- `reportes/mt5/R12_Q4_analisis.md` (riesgo agregado y stop-out)
- `tests/EngineScalperExport.mq5` (harness TF-paramétrico)
