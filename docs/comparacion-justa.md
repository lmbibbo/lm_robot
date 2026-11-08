# Plan de comparación justa MT4 vs MT5

| Campo | Valor |
|---|---|
| Objetivo | Comparar `CodigoOriginalMT4` (MT4) contra `LmRobot` (MT5) sin que las diferencias de feed, spread, capital, exposición o stop expliquen el resultado |
| Símbolo / timeframe | AUDCAD H1 |
| Ventana base | 2024.01.01 00:00 – 2024.07.01 00:00 |
| Restricción | **No se modifica el EA de MT4**. El stop se analiza configurando MT5 y simulando post-hoc sobre el ledger de MT4 |
| Estado | Plan aprobado para ejecución; requiere las decisiones de §10 |

---

## 0. Principio

La comparación actual mezcla cinco experimentos distintos. El plan separa cada variable y la mide con una corrida propia. La regla es:

> Dos corridas solo se restan si comparten feed, spread, capital, exposición y política de stop. Si cambia una sola de esas variables, la diferencia se atribuye a esa variable, no al motor.

El resultado final no es un único número: es una **tabla de atribución** que dice cuánto del `Net` y del `DD` explica cada diferencia.

---

## 1. Mismo feed

### 1.1 Fuente única

Se usa **un solo dataset M1** como verdad:

- Fuente canónica: historial M1 de **FBS-Demo MT5** (build 6182) para AUDCAD.
- Ventana: `2023.12.01` – `2024.07.01` (incluye warm-up para RSI/ATR).
- Formato de exportación: `fecha,hora,open,high,low,close,tick_volume`.
- Se guarda el CSV y un hash SHA-256 del contenido normalizado (timestamp + OHLC). Ese hash viaja en el CSV de resultados como `feed_hash`.

### 1.2 Verificación antes de tocar el tester

| Control | Criterio |
|---|---|
| Barras M1 | Mismo conteo, primer y último timestamp |
| OHLC M1 | Hash idéntico |
| Barras H1 derivadas | Mismo conteo y hash |
| Zona horaria | Mismo timestamp para la primera barra H1 de 2024.01.02 |
| Especificación del símbolo | `digits=5`, `point=0.00001`, `contract=100000`, misma divisa de margen, mismo swap y comisión |

Si el hash M1 o H1 no coincide, **no se comparan resultados**: se corrige el feed y se repite.

### 1.3 Cómo se carga el mismo feed en cada terminal

**MT5 — símbolo personalizado `AUDCAD.PARITY`**

1. Clonar la especificación de AUDCAD (dígitos, punto, contrato, tick size/value, divisas, swap, comisión).
2. Fijar `SYMBOL_SPREAD = 17` y `SYMBOL_SPREAD_FLOAT = false`.
3. Importar el CSV M1 como barras del símbolo personalizado.
4. Verificar que el tester vea `AUDCAD.PARITY` y que su H1 derivado coincida con el H1 de la fuente.

Se puede hacer por GUI (`Herramientas > Símbolos personalizados`) o con un script MQL5 (`CustomSymbolCreate` + `CustomRatesUpdate`). El script es preferible para que sea reproducible.

**MT4 — historial importado**

1. `Herramientas > Centro de historial` → AUDCAD → M1 → Importar el mismo CSV.
2. Importar también el H1 generado desde el mismo M1, para que el tester no reconstruya H1 desde un caché viejo.
3. Subir `Máx. barras en el historial` en `Herramientas > Opciones > Gráficos`.
4. Ejecutar MT4 en **modo offline** (`/offline`) para que el bróker no sobrescriba el historial importado.
5. Verificar que el tester reporte el mismo número de barras y que el primer/último tick coincida con el CSV.

> Esto **no toca el EA de MT4**: solo el historial del tester. Si preferís no tocar el historial, la alternativa es verificar que los feeds nativos de MT4 y MT5 coinciden; si no coinciden, la comparación de P&L no es válida y solo se puede hacer paridad de señales en `Open prices only`.

### 1.4 Modelo de ejecución

MT4 no tiene `1 minute OHLC`. La pareja más cercana es:

| Nivel | MT4 | MT5 | Qué aísla |
|---|---|---|---|
| Lógica | `Open prices only` | `Open prices only` | Señales, sizing y grilla, sin ambigüedad intrabar |
| Ejecución | `Every tick` (generado desde M1) | `Every tick` (generado desde M1, sin real ticks) | Orden intrabar, toques de TP/SL y pasos de grilla |
| Robustez | — | `Every tick based on real ticks` | Solo sensibilidad; no se usa para el veredicto |

`Control points` queda fuera de la comparación principal. Su propio reporte dice que los resultados no deben considerarse.

---

## 2. Fijar el spread

### 2.1 Spread base

Se fija **17 points = 1,7 pips** en ambos motores:

- MT4: `TestSpread=17` en el `.ini`.
- MT5: `SYMBOL_SPREAD=17`, `SYMBOL_SPREAD_FLOAT=false` en `AUDCAD.PARITY`.

17 points es el valor declarado por la corrida de enero (`Current (17)`) y el único que tiene un control reproducible. La corrida de 6 meses de MT4 usó `Current (60)`; por eso 60 entra en la escalera de sensibilidad.

### 2.2 Escalera de spread

| Points | Pips | Uso |
|---:|---:|---|
| 0 | 0,0 | Piso sin costo; diagnóstico de lógica |
| 10 | 1,0 | Spread bajo |
| 17 | 1,7 | **Base** |
| 30 | 3,0 | Spread medio |
| 60 | 6,0 | Réplica del R01 6M; explica la diferencia actual |

Mínimo obligatorio: **17 y 60**. Ideal: 0, 10, 17, 30, 60.

### 2.3 Comisión y swap

- Se clonan del símbolo AUDCAD en ambos terminales.
- Si no se pueden igualar, se corren dos variantes: **costo cero** (para aislar lógica) y **costo real** (para el veredicto).
- En MT4 el HTML no separa swap/comisión; hay que sacarlos del statement o marcarlos `n/a` y no restarlos contra MT5.
- En MT5 el HTML sí trae `Commission` y `Swap` en la tabla de deals.

### 2.4 Filtros que deben quedar iguales

| Filtro | MT4 | MT5 | Acción |
|---|---|---|---|
| Spread máximo | No existe en el original | `MaxSpreadPips=100` | Apagado en ambos |
| ATR máximo | `MaxAllowedATR=150` points = 15 pips | `MaxAtrPips=15.0` | Igualar a 15 pips |
| Sesión | No filtra | `UseSessionFilter=false` | Apagado en ambos |
| Noticias | `UseNewsFilter` es código muerto | No existe | Sin acción |

---

## 3. Misma base de capital

### 3.1 Configuración

| Parámetro | Valor |
|---|---|
| Depósito | 10.000 USD |
| Divisa | USD |
| Apalancamiento | 1:100 |
| Modo de cuenta | Hedging |
| Cuenta | FBS-Demo |

MT4: `TestDeposit=10000`, `TestCurrency=USD`, `TestLeverage=100`.
MT5: mismos valores en el tester.

### 3.2 Una sola cuenta, tres estrategias

MT4 corre las tres estrategias en una cuenta de 10.000 USD. Para que el capital sea el mismo, MT5 debe correr las tres estrategias **en una sola cuenta de 10.000 USD**, no en tres cuentas de 10.000.

Dos caminos, con **A elegido**:

| Camino | Qué hace | Ventaja | Límite | Estado |
|---|---|---|---|---|
| **A. Modo portafolio en MT5** | Agregar `Strategy=ALL` al EA MT5 y correr las tres señales en una instancia | Reproduce margen, equidad y DD compartidos; es la comparación definitiva | Requiere cambio de código **solo en MT5** | **Elegido** |
| B. Reconstrucción | Correr cada estrategia en 10k y fusionar los deals por timestamp en una curva de 10k | No requiere código | No modela margen/equidad compartidos; el DD es aproximado | Fallback interino |

**Decisión:** A para el veredicto. B solo si hay que desbloquear un análisis antes de que `Strategy=ALL` esté listo.

### 3.3 Métrica de capital

No se compara `Net` absoluto entre 10k y 30k. Se compara:

- Retorno % sobre 10.000 USD.
- DD % sobre 10.000 USD.
- `Net` solo dentro de la misma base de capital.

---

## 4. Misma exposición

### 4.1 La identidad de lotaje

MT4 calcula el lote así (con `Risk=1`, `GeneralStopLoss=200`):

```
lot_MT4 = (Risk/1000 × balance) / GeneralStopLoss
        = (0.001 × balance) / 200
        = balance / 200.000
```

Con 10.000 USD → **0,05 lotes**.

MT5 calcula:

```
lot_MT5 = (RiskPct/100 × balance) / (SlPips × pipValuePerLot)
```

Para que sea la misma función de balance, se necesita:

```
RiskPct = baseLot × SlPips × pipValuePerLot × 100 / balance
```

Con `baseLot=0,05`, `pipValuePerLot≈7,44`, `balance=10.000`, el valor nominal sería el de la columna "Nominal". Pero la corrida C1 con `RiskPct=0,745` dio 0,04 en enero porque el `pipValuePerLot` real es > 7,45 y el `floor` redondea hacia abajo. C1p lo corrigió con `RiskPct=0,80`. Por eso se usan los valores **calibrados**:

| Variante | SlPips | RiskPct nominal | RiskPct calibrado (usar) | Lote base | f* = TP/(TP+SL) |
|---|---:|---:|---:|---:|---:|
| **P-NS** (sin stop efectivo) | 1000 | 3,72 | **4,00** | 0,05 | ≈0,8 % |
| P-SL200 (C1) | 200 | 0,745 | **0,80** | 0,05 | 3,85 % |
| P-SL20 (C1b) | 20 | 0,0745 | **0,08** | 0,05 | 28,6 % |
| P-SL4 (opcional) | 4 | 0,0149 | **0,016** | 0,05 | 66,7 % |

> **Regla:** usar la columna calibrada. El valor nominal solo sirve para documentar la fórmula. Verificar siempre el primer deal: debe ser 0,05. Si el calibrado diera 0,06, bajar un escalón (por ejemplo `P-NS → 3,8`).

### 4.2 Parámetros de exposición

| Input | MT4 | MT5 P-NS | Nota |
|---|---:|---:|---|
| Lote inicial | 0,05 | 0,05 | Verificar primer deal |
| Multiplicador | 1,667 | 1,667 | `LotExponent` / `LotMultiplier` |
| Paso de grilla | 22 pips | 22 pips | `PipStep=220` points / `GridStepPips=22` |
| Take profit | 8 pips | 8 pips | `TakeProfit=80` points / `TpPips=8` |
| Stop de canasta | **No se envía** | 1000 pips (P-NS) | MT4 intacto; MT5 con stop lejano |
| Máx. órdenes | 20 por estrategia | `MaxGridSteps=19` | 19 pasos + inicial = 20 |
| Máx. lote por orden | 9 | `MaxLotPerOrder=9` | Igual |
| Máx. volumen por estrategia | Sin tope explícito | `MaxVolumePerStrategy=9` | Ver §4.3 |
| Límite de canasta | No existe | `MaxBasketLossPct=1000` | Apagado |
| Límite diario | No existe | `DailyLossLimitPct=1000` | Apagado |
| Trailing stop | `UseTrailingStop=false` | No existe | Sin acción |
| Slippage | `slip=3` points | `Delays=0` | Documentar |

### 4.3 Topes que no deben recortar

El ledger de MT4 6M da un **volumen concurrente máximo de 5,95 lotes** (2024.04.09 17:00), sumando las tres estrategias. El volumen total operado es 62,12 lotes.

Por eso:

- `MaxVolumePerStrategy=9` por estrategia no debería recortar si cada estrategia se mantiene por debajo de 9 lotes.
- Si el modo portafolio comparte un tope global, fijarlo por encima de 5,95 (por ejemplo 9) para que no recorte.
- Verificar en el CSV de métricas que `max_basket_volume` no toque el tope. Si lo toca, la comparación de exposición falla y hay que subir el tope.

---

## 5. Qué se compara respecto al stop (sin tocar MT4)

MT4 no envía stop loss: los seis `OrderSend` del `.mq4` pasan `0, 0` en SL/TP y el reporte tiene 0 cierres `s/l`. **No se modifica MT4.** El stop se analiza de tres formas:

### 5.1 Comparación primaria: MT5 sin stop efectivo (P-NS)

`SlPips=1000` y `RiskPct=3,72` reproducen el lotaje de MT4 y alejan el stop lo suficiente para que no defina el resultado. Es la comparación **de lógica y ejecución**: si MT5 P-NS no se parece a MT4, la diferencia no es el stop.

- Si el stop de 1000 pips se toca, se reporta como evento separado.
- `f* ≈ 0,8 %`: el stop casi no participa.

### 5.2 Contrafactual: MT5 con stop real (P-SL200, P-SL20)

Responden otra pregunta: **¿qué pasaría si el original hubiera tenido stop?** No son la comparación principal, porque MT4 no tiene stop. Se reportan como curva de sensibilidad:

```
Net vs SlPips:  4 → 20 → 200 → 1000
```

Si el `Net` de MT5 converge al de MT4 a medida que el stop se ensancha, la ventaja de MT4 es principalmente la ausencia de stop.

### 5.3 Simulación post-hoc del stop sobre el ledger de MT4

La forma más limpia de comparar stops sin tocar MT4:

1. Parsear el ledger de MT4 (entradas, salidas, precios, tamaños, tiempos).
2. Reconstruir cada canasta por cierre simultáneo (misma convención del `informe6m.md`).
3. Calcular el precio promedio ponderado de entrada de cada canasta.
4. Con el mismo feed M1, calcular la **excursión adversa máxima (MAE)** de cada canasta entre entrada y cierre.
5. Aplicar un stop hipotético a 4, 20 y 200 pips desde el promedio y recalcular el P&L con la misma convención de ejecución.
6. Comparar el P&L simulado contra el P&L real de MT4 y contra MT5 P-SL200/P-SL20.

Esto permite decir: *"con un stop de 20 pips, el original habría cerrado X canastas y su Net habría sido Y"*, sin modificar una línea de MT4. La limitación es la agrupación de canastas por cierre simultáneo cuando dos estrategias cierran en el mismo segundo; se documenta.

### 5.4 Lo que no se hace

- No se agrega SL al EA de MT4.
- No se cambia `GeneralStopLoss` (sigue siendo solo el denominador del lotaje).
- No se compara el `Net` de MT4 sin stop contra MT5 con stop como si fueran la misma política de riesgo.

---

## 6. Matriz de corridas

### 6.1 Fase A — MT4 (solo configuración de tester)

| ID | Modelo | Spread | Período | Propósito |
|---|---|---:|---|---|
| M4-C | `Control points` | 17 | Ene 2024 | Reproducir 732,27; gate de feed/config |
| M4-O6 | `Open prices only` | 17 | 6M | Paridad de lógica |
| M4-E6 | `Every tick` | 17 | 6M | **Comparación principal** |
| M4-E6-60 | `Every tick` | 60 | 6M | Sensibilidad de spread; explica R01 |
| M4-E6-0 | `Every tick` | 0 | 6M | Piso sin spread (opcional) |

`.ini` de ejemplo para M4-E6:

```ini
; comparacion justa - MT4 every tick, spread fijo
ExpertsEnable=true
ExpertsTrades=true
TestExpert=lm_robot\CodigoOriginalMT4_Test
TestSymbol=AUDCAD
TestPeriod=H1
TestModel=0
TestSpread=17
TestOptimization=false
TestDateEnable=true
TestFromDate=2024.01.01
TestToDate=2024.07.01
TestDeposit=10000
TestCurrency=USD
TestLeverage=100
TestReport=lm_robot_mt4_parity_everytick_s17_6m
TestReplaceReport=true
TestShutdownTerminal=true
TestVisualEnable=false
```

Para M4-O6: `TestModel=2`. Para M4-C: `TestModel=1`, `TestToDate=2024.02.01`.
Guardar el `.ini` como UTF-16LE, igual que los existentes en `reportes/sets/mt4/`.

### 6.2 Fase B — MT5 por estrategia

Configuración común P-NS:

```ini
Strategy=0||0||0||2||N
MagicNumber=202611030||202611030||1||202611030||N
MaxAttempts=3||3||1||3||N
RetryDelayMs=250||250||1||250||N
DeadlineMs=3000||3000||1||3000||N
AtrTimeframe=0||0||1||0||N
AtrPeriod=14||14||1||14||N
MaxSpreadPips=100.0||100.0||1||100.0||N
MaxAtrPips=15.0||15.0||1||15.0||N
RiskPct=4.0||4.0||1||4.0||N
MaxBasketLossPct=1000.0||1000.0||1||1000.0||N
DailyLossLimitPct=1000.0||1000.0||1||1000.0||N
MaxGridSteps=19||19||1||19||N
LotMultiplier=1.667||1.667||1||1.667||N
MaxLotPerOrder=9.0||9.0||1||9.0||N
MaxVolumePerStrategy=9.0||9.0||1||9.0||N
SlPips=1000.0||1000.0||1||1000.0||N
TpPips=8.0||8.0||1||8.0||N
GridStepPips=22.0||22.0||1||22.0||N
UseSessionFilter=false||false||0||true||N
SessionStartHour=8||8||1||80||N
SessionEndHour=17||17||1||170||N
```

Cambiar por corrida:

- `Strategy`: 0 = Scalper, 1 = Fibonacci, 2 = TrendMaster.
- `MagicNumber`: 202611030 / 202611031 / 202611032.
- `RiskPct`: 4,00 (P-NS), 0,80 (P-SL200), 0,08 (P-SL20).
- `SlPips`: 1000 / 200 / 20.

Los `.set` ya están generados en `reportes/sets/mt5/` (`P-NS-s0..2.set`,
`P-SL200-s0..2.set`, `P-SL20-s0..2.set`), y los `.ini` de MT4 en
`reportes/sets/mt4/`. El índice está en `reportes/sets/README_comparacion_justa.md`.

Corridas mínimas:

| Ola | Corridas | Qué responde |
|---|---|---|
| 1 | MT5 P-NS × 3 estrategias × `Open prices only` y `Every tick` | ¿La lógica y la ejecución reproducen a MT4? |
| 2 | MT5 P-SL200 × 3 y P-SL20 × 3, `Every tick` | ¿Cuánto explica el stop? |
| 3 | MT4 spread 60 y MT5 P-NS spread 60 | ¿Cuánto explica el spread de R01? |
| 4 | MT5 `Strategy=ALL` (portafolio) o reconstrucción | ¿Cuánto explica la estructura de cuenta? |

### 6.3 Fase C — Portafolio

- **A (definitiva):** `Strategy=ALL` en MT5, una cuenta de 10k, tres señales, magics distintos. Modelos `Open prices only` y `Every tick`. Configs P-NS y P-SL200.
- **B (interina):** fusionar los tres reportes por estrategia en una curva de 10k. Reportar que el DD es aproximado y que el margen compartido no está modelado.

**Estado:** A está implementado y corrido en `Open prices only`. Resultado en
`reportes/mt5/R11_ALL_P-NS_6m.htm` (ver §9.3). Falta la pata `Every tick` y el
spread fijo sobre `AUDCAD.PARITY`.

---

## 7. Atribución de la diferencia

El corazón del plan es explicar el `ΔNet` y el `ΔDD` por partes:

```
ΔNet(MT4 − MT5) =
    Δseñales
  + Δfeed/modelo
  + Δspread
  + Δcomisión/swap
  + Δstop
  + Δsizing
  + Δestructura de cuenta
  + Δcierres forzados
  + residual
```

Cómo se mide cada término:

| Término | Cómo se aísla |
|---|---|
| Δseñales | `Open prices only`, mismo feed, mismo spread, misma exposición. Debería ser ≈0 |
| Δfeed/modelo | MT5 `Open prices only` vs MT5 `Every tick`, misma config |
| Δspread | 17 vs 60 en ambos motores |
| Δcomisión/swap | Variante costo cero vs costo real |
| Δstop | P-NS vs P-SL200 vs P-SL20 |
| Δsizing | Comparar la secuencia de lotes; si el primer lote y la progresión coinciden, ≈0 |
| Δestructura | Suma de 3 cuentas de 10k vs portafolio de 10k |
| Δcierres forzados | P&L de posiciones abiertas al último tick, reportado aparte |
| Residual | Diferencia de secuencia intrabar entre MT4 `Every tick` y MT5 `Every tick` |

El residual se reporta con su magnitud. Si es grande, la comparación de ejecución queda limitada y se dice explícitamente.

---

## 8. Gates de aceptación

| Gate | Criterio | Si falla |
|---|---|---|
| Feed | M1 y H1 idénticos (conteo, timestamps, hash) | No comparar; corregir import |
| Control | M4-C reproduce 732,27 ± 0,1 % | Revisar feed, spread o build |
| Spread | Ambos declaran 17 points fijos | Ajustar símbolo/`.ini` |
| Capital | 10k, USD, 1:100, hedging | Igualar |
| Exposición | Primer lote 0,05; grilla 22; TP 8; mult 1,667; ≤20 órdenes | Ajustar `RiskPct`/`MaxGridSteps` |
| Señales | `Open prices only`: ≥99,9 % de entradas/salidas coincidentes | Revisar paridad de estrategias |
| Costos | Swap/comisión iguales o cero en ambos | Igualar o reportar gross/net |
| DD | Balance DD en ambos; equity solo si está disponible en MT4 | No comparar balance vs equity |
| Topes | `max_basket_volume` por debajo de `MaxVolumePerStrategy` | Subir el tope o reportar recorte |

---

## 9. Contrato del reporte

`reportes/comparacion_justa.csv`, una fila por corrida:

```
run_id, engine, build, broker, symbol, digits, contract, leverage, deposit,
currency, period_from, period_to, model, spread_points, spread_pips,
swap_mode, commission_mode, strategy, config, sl_pips, tp_pips, grid_pips,
lot_mult, max_grid, base_lot, max_concurrent_volume, net, gross_profit,
gross_loss, swap, commission, return_pct, pf, expected_payoff, trades,
deals, volume_closed, pct_volume_stopped, f_star, balance_dd_abs,
balance_dd_pct, equity_dd_abs, equity_dd_pct, recovery, max_consec_loss,
open_at_end, forced_close_pnl, bars, ticks, history_quality, feed_hash,
h1_hash, notes
```

Para MT4, `swap`, `commission`, `equity_dd_*` pueden quedar vacíos (`n/a`).
Para MT5, `balance_dd_*` y `equity_dd_*` salen del HTML.
El CSV se genera con un script que parsea los HTML de `reportes/mt4/` y `reportes/mt5/`; no se copian números a mano.

### 9.1 Tabla de veredicto

| Motor / config | Net 6M | Retorno % | PF | DD balance % | DD equidad % | Trades | Volumen | % detenido | f* |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| MT4 original (no stop) | +3.201,77 | +32,02 | 1,95 | 17,28 | n/a | 589 | 62,12 | 0 % | 0 % |
| MT5 P-NS (3 cuentas) | pendiente | | | | | | | | 0,79 % |
| MT5 P-SL200 (3 cuentas) | pendiente | | | | | | | | 3,85 % |
| MT5 P-SL20 (3 cuentas) | pendiente | | | | | | | | 28,6 % |
| MT5 P-NS portafolio | **+3.173,21** | **+31,73** | **2,36** | **3,36** | **8,54** | **695** | **57,41** | **0 %** | 0,79 % |

> La fila P-NS portafolio es R11: una cuenta de 10.000 USD, `Strategy=ALL`,
> Open prices only, spread del símbolo sin fijar. La referencia de 3 cuentas más
> cercana es C1p (30.000 USD, 1 minute OHLC): +3.185,85 (+10,62 %), pero no es
> P-NS y no se resta contra R11 como si compartiera feed y spread.

### 9.2 Tabla de atribución

| Componente | ΔNet | ΔDD | Evidencia |
|---|---:|---:|---|
| Señales | | | Open prices only |
| Modelo | | | MT5 Open vs Every tick |
| Spread | | | 17 vs 60 |
| Costos | | | costo cero vs real |
| Stop | | | P-NS vs P-SL200 vs P-SL20 |
| Sizing | | | primer lote y progresión |
| Estructura | | | suma 3×10k vs portafolio 10k |
| Cierres forzados | | | P&L al último tick |
| Residual | | | no explicado |

---

## 10. Decisiones tomadas

| Decisión | Elección | Consecuencia |
|---|---|---|
| Feed | **Importar M1 de FBS-Demo MT5 en ambos terminales** | Se crea `AUDCAD.PARITY` en MT5 y se importa el mismo M1/H1 en MT4. Gate de hash obligatorio |
| Portafolio | **`Strategy=ALL` en MT5** | Cambio de código solo en MT5; una cuenta de 10k con tres señales |
| Spread base | **17 points** | `TestSpread=17` en MT4 y `SYMBOL_SPREAD=17` fijo en MT5 |
| Variantes de stop | **P-NS + P-SL200 + P-SL20** | MT4 intacto; la comparación de stop se hace en MT5 + simulación post-hoc sobre el ledger MT4 |
| Costos | **Real y costo cero** | Dos variantes para separar lógica de costos |
| `RiskPct` | **Calibrado: 4,00 / 0,80 / 0,08** | Garantiza lote base 0,05 con el `pipValuePerLot` real |

---

## 11. Orden de ejecución

1. Exportar y hashear el M1 canónico.
2. Crear `AUDCAD.PARITY` en MT5 e importar el M1; verificar H1.
3. Importar el mismo M1/H1 en MT4; verificar y ejecutar offline.
4. Correr M4-C y validar 732,27.
5. Correr M4-O6 y M4-E6.
6. Correr MT5 P-NS × 3 estrategias en `Open prices only` y `Every tick`.
7. Comparar: si `Open prices only` no da paridad, parar y revisar señales antes de seguir.
8. Correr P-SL200 y P-SL20.
9. Correr la escalera de spread 60 (y 0/10/30 si hay tiempo).
10. Implementar `Strategy=ALL` y correr el portafolio de 10k (fallback: reconstrucción).
11. Generar `comparacion_justa.csv` y las tablas de §9.
12. Escribir el veredicto con la atribución y el residual.

---

## 12. Línea base verificada

Datos ya extraídos de los reportes existentes, para no volver a calcularlos:

| Dato | Valor | Fuente |
|---|---:|---|
| MT4 6M Net | +3.201,77 | `lm_robot_mt4_original_2024H1_10k.htm` |
| MT4 6M trades | 589 | ídem |
| MT4 6M volumen total | 62,12 lotes | ledger |
| MT4 6M volumen concurrente máximo | 5,95 lotes (2024.04.09 17:00) | ledger |
| MT4 6M P&L por mes (cierre) | Ene 515,02 / Feb 492,84 / Mar 350,71 / Abr 847,30 / May 624,08 / Jun 371,92 | ledger |
| MT4 6M DD balance | 2.034,97 (17,28 %) | reporte |
| MT4 6M spread | `Current (60)` | reporte |
| MT4 enero Net | +732,27 | `lm_robot_mt4_original_202401_10k.htm` |
| MT4 enero spread | `Current (17)` | reporte |
| MT5 C1 6M Net | +991,94 (Scalper) | `R05_C1_scalper_6m.htm` |
| MT5 C1 6M DD balance / equidad | 220,68 (2,06 %) / 554,38 (5,18 %) | reporte |
| MT5 C1 6M trades | 249 (498 deals) | reporte |
| MT5 C0 6M Net | −806,55 (Scalper) | `R02_C0_scalper_6m.htm` |
| MT5 P-NS portafolio 6M Net | +3.173,21 | `R11_ALL_P-NS_6m.htm` |
| MT5 P-NS portafolio 6M DD balance / equidad | 413,64 (3,36 %) / 1.049,40 (8,54 %) | ídem |
| MT5 P-NS portafolio 6M trades / volumen | 695 / 57,41 lotes | ídem |
| MT5 P-NS portafolio exposición agregada máx. | 3,03 lotes (tope 9,00) | CSV de `OnTester` |

> El P&L mensual de MT4 6M es por fecha de cierre en la corrida continua. No coincide con la corrida mensual independiente de enero (732,27) porque en la continua las posiciones abiertas al 31-01 siguen hasta febrero.
