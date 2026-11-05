# Informe comparativo: `CodigoOriginalMT4` vs `LmRobot.mq5`

**Período:** 2024.01.01 – 2024.02.01 (primer mes de 2024)
**Símbolo / timeframe:** AUDCAD H1
**Depósito inicial:** 10.000 USD por cuenta
**Apalancamiento:** 1:100
**Cuenta:** FBS-Demo
**Fecha del informe:** 2026-11-05

---

## 1. Resumen ejecutivo

| Motor | Net profit | Retorno | Profit factor | Máx. DD (ver nota) | Trades |
|---|---:|---:|---:|---:|---:|
| `CodigoOriginalMT4` (3 estrategias juntas) | **+732,27 USD** | **+7,32%** | **4,59** | **2,46%** | **211** |
| `LmRobot` default (3 corridas separadas) | **-124,26 USD** | **-0,41%** sobre 30.000 | 0,92 | 6,07% | 130 |
| `LmRobot` riesgo normalizado 0,1% | **+219,87 USD** | **+0,73%** sobre 30.000 | 1,38 | 4,39% | 183 |
| `LmRobot` réplica del perfil original | **+210,53 USD** | **+0,70%** sobre 30.000 | 2,20 | 2,37% | 157 |

> **Nota sobre el drawdown:** el reporte de MT4 informa el *maximal drawdown* sobre balance; el de MT5 informa el *equity drawdown*. No son la misma métrica, así que los porcentajes no deben restarse entre sí. En `LmRobot` se toma el peor drawdown de las tres cuentas independientes, no el de una cartera única.

**Lectura rápida:** en enero de 2024 el código original ganó más dinero, pero lo hizo sin stop loss real, con tres estrategias en una sola cuenta y sin límite diario. El motor nuevo, con sus protecciones activas, no alcanzó ese beneficio; aun así, al normalizar el tamaño de la primera orden, las tres estrategias quedaron en positivo agregado y con drawdowns contenidos por cuenta (0,33%–4,39%).

> El resultado **no** demuestra que el original sea mejor: demuestra que el original asumió un riesgo distinto y no comparable. La comparación de beneficio sin comparar riesgo sería engañosa.

---

## 2. Metodología

### 2.1 Motor original (MT4)

- Fuente: `CodigoOriginalMT4.mq4` (94.892 bytes).
- Terminal: FBS Trader 4 build 1492, datos FBS-Demo.
- Modelo: **Control points (Model=1)**.
- Reporte: `lm_robot_mt4_original_202401_10k.htm`.
- Inputs: los valores por defecto del archivo (`MM=true`, `Risk=1`, `Lots=0.01`, `LotExponent=1.667`, `PipStep=220`, `TakeProfit=80`, `GeneralStopLoss=200`, `MaxTrades_*=20`, `UseNewsFilter=true`).

**Parche de banco de pruebas:** el original, tal como está, entra en un bucle infinito en `OrderModify` cuando el broker devuelve error 1 (“no changes”). En la primera corrida generó un log de **22 GB** y no terminó. Para poder medirlo se compiló una copia local `CodigoOriginalMT4_Test.mq4` que limita esos tres bucles a 3 intentos y corta con error 1. **No se modificó ninguna regla de entrada, salida, lotaje ni gestión.** El original sigue teniendo el defecto; el parche es solo para que el tester pueda terminar.

### 2.2 Motor nuevo (MT5)

- Fuente: `EA/LmRobot.mq5`.
- Terminal: FBS MetaTrader 5 build 6182.
- Modelo: **1 minute OHLC (Model=1)**.
- Una corrida por estrategia, porque el EA admite una sola estrategia activa por gráfico:
  - `Strategy=0` → Scalper Pro
  - `Strategy=1` → Fibonacci Focus
  - `Strategy=2` → TrendMaster
- Inputs por defecto: `RiskPct=0.5`, `SlPips=40`, `TpPips=8`, `GridStepPips=22`, `LotMultiplier=1.5`, `MaxGridSteps=4`, `MaxLotPerOrder=0.10`, `MaxVolumePerStrategy=0.30`, `MaxBasketLossPct=2.0`, `DailyLossLimitPct=4.0`, `MaxAtrPips=30`.
- Cada corrida tiene su propio CSV de métricas generado por `OnTester` y su reporte HTML.

### 2.3 Escenarios de sensibilidad de `LmRobot`

Para separar “lógica del motor” de “tamaño de posición” se agregaron dos escenarios:

| Escenario | Objetivo | Cambios principales |
|---|---|---|
| **Riesgo 0,1%** | Acercar la primera orden al lotaje observado del original (~0,04) | `RiskPct=0.1`, resto igual al default |
| **Réplica original** | Quitar topes y usar grilla/TP del original, manteniendo el SL del motor nuevo | `RiskPct=2.0`, `SlPips=1000` (SL prácticamente inexistente), `TpPips=8`, `GridStepPips=22`, `LotMultiplier=1.667`, `MaxGridSteps=20`, `MaxLotPerOrder=9`, `MaxVolumePerStrategy=9`, `MaxBasketLossPct=1000`, `DailyLossLimitPct=1000`, `MaxAtrPips=15`, `MaxSpreadPips=100` |

---

## 3. Resultados detallados

### 3.1 `CodigoOriginalMT4` — todas las estrategias en una cuenta

| Métrica | Valor |
|---|---:|
| Depósito inicial | 10.000,00 USD |
| Total net profit | **+732,27 USD** |
| Retorno | **+7,32%** |
| Gross profit | 936,06 USD |
| Gross loss | -203,79 USD |
| Profit factor | **4,59** |
| Expected payoff | 3,47 USD |
| Máx. drawdown (balance, reporte MT4) | **260,40 USD (2,46%)** |
| Total trades | **211** |
| Short / long | 160 / 51 |
| Win rate | **76,78%** |
| Barras / ticks modelados | 1.530 / 14.228 |
| Calidad de modelado | n/a (Control points) |

**Observaciones del original:**

- `OrderSend` se llama con **SL=0 y TP=0** (líneas 1699/1713 del `.mq4`). Luego se modifica el TP, pero **el SL calculado nunca se envía al broker**. En el reporte, la columna S/L de las operaciones figura en `0.00000`.
- Corre las tres estrategias (Fibonacci, Scalper y TrendMaster) en la misma instancia y la misma cuenta.
- La regla de lotaje usa `Risk/1000`, no `Risk/100`, por lo que el riesgo efectivo es menor al configurado, pero el lotaje crece con la grilla sin tope por orden.
- El `return` de la línea 945 hace que Scalper y TrendMaster solo se ejecuten en el primer tick de cada barra; la gestión intra-barra queda limitada.
- El filtro ATR compara `atr / Point` contra `MaxAllowedATR=150`, es decir, bloquea con ATR > 150 puntos (15 pips), no 150 pips.

### 3.2 `LmRobot` — inputs por defecto

| Estrategia | Net profit | Retorno | PF | Máx. DD equidad | Trades | Máx. orden | Máx. canasta | Pasos |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Scalper Pro | -53,99 | -0,54% | 0,89 | 3,36% | 41 | 0,10 | 0,30 | 2 |
| Fibonacci Focus | **+412,87** | **+4,13%** | 3,65 | 1,63% | 43 | 0,10 | 0,30 | 2 |
| TrendMaster | **-483,14** | **-4,83%** | 0,44 | 6,07% | 46 | 0,10 | 0,30 | 2 |
| **Agregado (3 cuentas)** | **-124,26** | **-0,41%** | **0,92** | **6,07%** | **130** | — | — | — |

- Todas las corridas terminaron con `limits_respected=SI`.
- Pérdida proyectada máxima: 1,37% / 1,36% / 1,44% (límite 2,0%).
- No hubo activaciones del límite diario (`daily_hits=0`).
- El agregado es la suma de tres cuentas independientes de 10.000 USD; **no es una cartera única** y no reproduce el interés compuesto ni el margen del original.

### 3.3 `LmRobot` — riesgo 0,1%

| Estrategia | Net profit | Retorno | PF | Máx. DD equidad | Trades | Máx. orden | Máx. canasta | Pasos |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Scalper Pro | +203,96 | +2,04% | 2,73 | 1,66% | 65 | 0,10 | 0,25 | 4 |
| Fibonacci Focus | +283,79 | +2,84% | 45,97 | 1,04% | 58 | 0,10 | 0,25 | 4 |
| TrendMaster | -267,88 | -2,68% | 0,42 | 4,39% | 60 | 0,10 | 0,25 | 4 |
| **Agregado (3 cuentas)** | **+219,87** | **+0,73%** | **1,38** | **4,39%** | **183** | — | — | — |

- Al reducir el riesgo inicial, Scalper y Fibonacci pasan a positivo; TrendMaster sigue perdiendo.
- La canasta máxima bajó de 0,30 a 0,25 y los pasos subieron de 2 a 4, porque el lote inicial más chico permite más escalones antes de tocar el tope de volumen.

### 3.4 `LmRobot` — réplica del perfil original

| Estrategia | Net profit | Retorno | PF | Máx. DD equidad | Trades | Máx. orden | Máx. canasta | Pasos |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Scalper Pro | +86,49 | +0,86% | 3,26 | 1,19% | 53 | 0,09 | 0,19 | 3 |
| Fibonacci Focus | +75,44 | +0,75% | 5,45 | 0,33% | 60 | 0,05 | 0,10 | 2 |
| TrendMaster | +48,60 | +0,49% | 1,40 | 2,37% | 44 | 0,25 | 0,59 | 5 |
| **Agregado (3 cuentas)** | **+210,53** | **+0,70%** | **2,20** | **2,37%** | **157** | — | — | — |

- Es el escenario más cercano al perfil de riesgo del original (sin SL práctico, grilla 22 pips, multiplicador 1,667, topes altos).
- Aun así, el beneficio es **~3,5 veces menor** que el del original (+210,53 vs +732,27), con 157 trades vs 211.
- La “pérdida proyectada” de este escenario (14,3% / 7,5% / 44,3%) no es comparable con el límite del 2%: se calcula con un SL de 1.000 pips, que en la práctica está desactivado.

---

## 4. Comparación e interpretación

### 4.1 Beneficio

- El original ganó **+732,27 USD** en una cuenta de 10.000 USD.
- El mejor escenario agregado de `LmRobot` fue **+219,87 USD** sobre 30.000 USD (0,73%).
- Si se compara el **mejor resultado individual** de `LmRobot` (Fibonacci default, +412,87 USD, +4,13%) contra el original, el original sigue ganando, pero con tres estrategias y sin SL.
- El original concentra el beneficio en **posiciones cortas** (160 de 211) y una tasa de acierto del 76,78%, consistente con un TP fijo de 8 pips y sin SL.

### 4.2 Riesgo

| Motor | DD reportado | SL real | Límite diario | Topes de volumen | Estrategias por cuenta |
|---|---:|---|---|---|---|
| Original | 2,46% (balance) | **No** | No | Solo `MaxLots` inicial | 3 |
| LmRobot default | 3,36% / 1,63% / 6,07% (equidad) | **Sí, 40 pips** | Sí, 4% | Sí: 0,10 / 0,30 / 4 pasos | 1 |
| LmRobot réplica | 1,19% / 0,33% / 2,37% (equidad) | Sí, 1.000 pips (desactivado) | Sí, 1000% (desactivado) | Sí: 9 / 9 / 20 pasos | 1 |

El original tuvo un drawdown bajo **en este mes favorable**, pero sin SL cualquier movimiento adverso podía dejar posiciones abiertas sin protección. El motor nuevo tiene un drawdown mayor en TrendMaster default (6,07%), pero dentro de sus límites y con SL efectivo.

### 4.3 Por qué no son directamente comparables

1. **Cantidad de estrategias:** el original corre las tres en una cuenta; `LmRobot` corre una por gráfico. El agregado de `LmRobot` son tres cuentas independientes de 10.000 USD, no una cartera de 10.000 USD.
2. **Stop loss:** el original no envía SL; `LmRobot` sí. Esto cambia por completo la distribución de resultados.
3. **Lotaje:** el original calcula lotes con `Risk/1000` y un SL de 200 puntos; `LmRobot` usa `Risk/100` y su propio SL. Los tamaños observados del original (0,03–0,10) y de `LmRobot` default (hasta 0,10) son parecidos, pero la lógica es distinta.
4. **Modelado:** MT4 Control points vs MT5 1-minute OHLC. No son motores idénticos.
5. **Noticias:** el original tiene `UseNewsFilter=true`; `LmRobot` no implementa filtro de noticias. En el tester de MT4 el filtro puede no tener datos reales de noticias.
6. **Parche del original:** el resultado del original requiere una copia con los bucles de `OrderModify` acotados. Sin ese parche, el original no termina el backtest.

---

## 5. Conclusión

En el primer mes de 2024, **`CodigoOriginalMT4` obtuvo más beneficio** que `LmRobot`: +7,32% vs +0,73% del mejor escenario agregado del motor nuevo. Sin embargo, esa diferencia no es una comparación de calidad:

- El original ganó **sin stop loss real**, con tres estrategias en una sola cuenta y sin límite diario.
- El original **no pudo ejecutarse sin un parche** en el banco de pruebas; su bucle de `OrderModify` genera un log de 22 GB y cuelga el tester.
- `LmRobot` respetó todos sus límites en las nueve corridas (`limits_respected=SI`) y, con el riesgo normalizado, las tres estrategias quedaron en positivo agregado.

**Recomendación:** no decidir con un solo mes. Para una comparación defendible hay que correr al menos 3–6 meses, incluyendo un período adverso, y comparar no solo el profit sino también el drawdown, la exposición máxima y la cantidad de operaciones. Si el objetivo es paridad de beneficio, el siguiente paso es comparar operación por operación y revisar las diferencias de entrada, grilla y cierre de canasta; si el objetivo es robustez, el motor nuevo ya muestra una ventaja clara en control de riesgo.

---

## 6. Artefactos

### Reportes MT4

```
C:\Users\palob\AppData\Roaming\MetaQuotes\Terminal\9D15457EC01AD10E06A932AAC616DC32\
  lm_robot_mt4_original_202401_10k.htm
  lm_robot_mt4_original_202401_10k.gif
  mt4_test_original_ascii.ini
  MQL4\Experts\lm_robot\CodigoOriginalMT4_Test.mq4   (copia con reintentos acotados)
  tester\logs\20261105.log
```

### Reportes MT5

```
C:\Users\palob\AppData\Roaming\MetaQuotes\Terminal\776D2ACDFA4F66FAF3C8985F75FA9FF6\
  lm_robot_mt5_jan2024_scalper.htm
  lm_robot_mt5_jan2024_fibonacci.htm
  lm_robot_mt5_jan2024_trend.htm
  lm_robot_mt5_jan2024_scalper_r01.htm
  lm_robot_mt5_jan2024_fibonacci_r01.htm
  lm_robot_mt5_jan2024_trend_r01.htm
  lm_robot_mt5_jan2024_scalper_replica.htm
  lm_robot_mt5_jan2024_fibonacci_replica.htm
  lm_robot_mt5_jan2024_trend_replica.htm
```

### Métricas CSV (`OnTester`)

```
C:\Users\palob\AppData\Roaming\MetaQuotes\Terminal\Common\Files\
  lm_robot_run_Scalper_Pro_AUDCAD_H1_20240131_235859_89890.csv
  lm_robot_run_Fibonacci_Focus_AUDCAD_H1_20240131_235859_8515.csv
  lm_robot_run_TrendMaster_AUDCAD_H1_20240131_235859_25156.csv
  lm_robot_run_Scalper_Pro_AUDCAD_H1_20240131_235859_17437.csv
  lm_robot_run_Fibonacci_Focus_AUDCAD_H1_20240131_235859_36312.csv
  lm_robot_run_TrendMaster_AUDCAD_H1_20240131_235859_53000.csv
  lm_robot_run_Scalper_Pro_AUDCAD_H1_20240131_235859_87218.csv
  lm_robot_run_Fibonacci_Focus_AUDCAD_H1_20240131_235859_5437.csv
  lm_robot_run_TrendMaster_AUDCAD_H1_20240131_235859_24109.csv
```

Cada CSV de métricas tiene su `_daily.csv` asociado con la auditoría diaria.

### Logs

- MT4 tester: `...\9D15457EC01AD10E06A932AAC616DC32\tester\logs\20261105.log`
- MT5 tester: `...\776D2ACDFA4F66FAF3C8985F75FA9FF6\Tester\logs\20261105.log`

Estos artefactos están fuera del repo y no se versionan (`.gitignore` excluye `*.htm`, `*.log`, `*.set`, etc.).
