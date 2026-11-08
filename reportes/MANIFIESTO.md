# Archivo de reportes — comparación 6 meses

Archivado el 2026-11-06; ampliado el 2026-11-08 con R11 (portafolio `ALL`).
Contiene inventario, métricas de cabecera y la comparación indicativa MT4 vs MT5.

## Estructura

```
reportes/
  mt4/                 3 reportes HTML de MT4
  mt5/                 29 reportes HTML de MT5 (6M + portafolio + corridas previas)
  sets/mt4/            .set e .ini de MT4
  sets/mt5/            .set de las 12 corridas MT5
  MANIFIESTO.md
```

## 1. MT4 — `CodigoOriginalMT4_Test`

Modelo: Control points. Todas las corridas sobre AUDCAD H1, 10.000 USD, 1:100.

| Archivo | Corrida | Período | Net (USD) | PF | Trades | DD máx. | Spread | Cierres |
|---|---|---|---:|---:|---:|---:|---|---|
| `lm_robot_mt4_original_202401_10k.htm` | Enero (ledger) | 2024.01.02–2024.02.01 | **+732,27** | 4,59 | 211 | 2,46 % | Current (17) | 211 t/p, 0 s/l |
| `lm_robot_mt4_original_202401.htm` | Enero (duplicado) | 2024.01.02–2024.02.01 | +732,27 | 4,59 | 211 | 2,46 % | Current (17) | 211 t/p, 0 s/l |
| `lm_robot_mt4_original_2024H1_10k.htm` | **R01 — 6 meses** | 2024.01.02–2024.07.01 | **+3.201,77** | 1,95 | 589 | 17,28 % | **Current (60)** | 582 t/p + 7 `close at stop`, 0 s/l |

Verificación rápida de R01:

- `Σ profit` de los 589 cierres = **3.201,87**; net del reporte = 3.201,77 (diferencia 0,10 por redondeo).
- Columna `S / L` en todas las filas: **0.00000**.
- Ningún cierre `s/l`.
- 7 posiciones abiertas al último tick, cerradas como `close at stop` (0,76 lotes).
- Volumen cerrado total: 62,12 lotes.

## 2. MT5 — `LmRobot`

Todas: AUDCAD H1, 2024.01.01–2024.07.01, 10.000 USD por cuenta, 1:100, modelo 1 minute OHLC.

| ID | Config | Estrategia | Net (USD) | PF | Trades | DD equidad | Nota |
|---|---|---|---:|---:|---:|---:|---|
| R02 | C0 | Scalper Pro | −806,55 | 0,62 | 271 | 1.003,27 (9,95 %) | defaults del código |
| R03 | C0 | Fibonacci Focus | −475,96 | 0,73 | 265 | 662,35 (6,53 %) | defaults del código |
| R04 | C0 | TrendMaster | −436,90 | 0,75 | 272 | 631,57 (6,28 %) | defaults del código |
| R05 | C1 | Scalper Pro | +991,94 | 2,52 | 249 | 554,38 (5,18 %) | lote inicial 0,04 en enero |
| R06 | C1 | Fibonacci Focus | +1.019,97 | 1,86 | 240 | 1.463,19 (13,94 %) | lote inicial 0,04 en enero |
| R07 | C1 | TrendMaster | +1.055,12 | 2,44 | 244 | 627,59 (6,14 %) | lote inicial 0,04 en enero |
| R08 | C2 | Scalper Pro | −1.644,61 | 0,50 | 207 | 1.989,72 (19,42 %) | continuidad |
| R09 | C2 | Fibonacci Focus | −238,01 | 0,89 | 190 | 924,42 (8,72 %) | continuidad |
| R10 | C2 | TrendMaster | −1.343,99 | 0,57 | 216 | 1.406,15 (14,04 %) | continuidad |
| R05b | C1p | Scalper Pro | +1.026,68 | 2,55 | 250 | 554,38 (5,17 %) | calibración `RiskPct=0,80` (lote 0,05) |
| R06b | C1p | Fibonacci Focus | +1.054,64 | 1,89 | 240 | 1.463,19 (13,89 %) | calibración `RiskPct=0,80` (lote 0,05) |
| R07b | C1p | TrendMaster | +1.104,53 | 2,45 | 247 | 627,59 (6,11 %) | calibración `RiskPct=0,80` (lote 0,05) |
| **R11** | **P-NS** | **Portafolio ALL** | **+3.173,21** | **2,36** | **695** | **1.049,40 (8,54 %)** | **una cuenta de 10k, `Strategy=ALL`, Open prices only** |

Agregados de 3 cuentas (30.000 USD):

| Config | Net | Retorno | Estrategias positivas |
|---|---:|---:|---|
| C0 | −1.719,41 | −5,73 % | 0 / 3 |
| C1 | +3.067,03 | +10,22 % | 3 / 3 |
| C1p | +3.185,85 | +10,62 % | 3 / 3 |
| C2 | −3.226,61 | −10,76 % | 0 / 3 |

### 2.1 R11 — portafolio `Strategy=ALL`

Corrida del 2026-11-08, AUDCAD H1, 2024.01.01–2024.07.01, una cuenta de
10.000 USD, 1:100, `P-NS-ALL.set`, modelo **Open prices only** (`Model=2`).
Artefactos: `R11_ALL_P-NS_6m.htm`, `R11_ALL_P-NS_6m.csv`,
`R11_ALL_P-NS_6m_daily.csv`; runner en `sets/mt5/R11_ALL_P-NS_6m.ini`.

| Métrica | Valor |
|---|---:|
| Net del reporte | +3.173,21 |
| Retorno | +31,73 % |
| Profit factor | 2,36 |
| Trades | 695 |
| Volumen operado | 57,41 lotes |
| Exposición agregada máxima | 3,03 lotes (tope 9,00) |
| DD balance | 413,64 (3,36 %) |
| DD equidad | 1.049,40 (8,54 %) |
| Lote base por estrategia | 0,05 |
| `limits_respected` / `aggregate_respected` | SI / SI |

Atribución por magic (reconcilia exactamente con el Net):

| Estrategia | Magic | Net | DD máx. | Volumen máx. |
|---|---:|---:|---:|---:|
| Scalper Pro | 202611030 | +1.122,95 | 698,48 | 1,82 |
| Fibonacci Focus | 202611031 | +900,27 | 880,18 | 1,05 |
| TrendMaster | 202611032 | +1.149,99 | 654,62 | 1,51 |
| **Suma** | | **+3.173,21** | | |

> **Corrección de atribución.** La primera corrida de 11.7 (2026-11-07)
> informó `portfolio_net=3.240,08`. La diferencia de 66,87 USD eran los 7
> cierres forzados al final del test, que MT5 registra con `magic=0`.
> `LmHistoryNetByMagic` ahora recupera el magic desde el deal de apertura
> vía `DEAL_POSITION_ID`, y la suma coincide con `final_balance − depósito`.

### 2.2 Comparación indicativa contra MT4

| Métrica | MT4 R01 | MT5 R11 (ALL) |
|---|---:|---:|
| Net | +3.201,77 | +3.173,21 |
| Retorno | +32,02 % | +31,73 % |
| Profit factor | 1,95 | 2,36 |
| Trades | 589 | 695 |
| Volumen operado | 62,12 lotes | 57,41 lotes |
| Exposición concurrente máx. | 5,95 lotes | 3,03 lotes |
| DD balance | 2.034,97 (17,28 %) | 413,64 (3,36 %) |
| DD equidad | n/a | 1.049,40 (8,54 %) |
| Modelo | Control points | Open prices only |
| Spread | `Current (60)` | no fijado |

La diferencia de Net es de 28,56 USD (0,9 %), pero **no es una comparación
controlada**: cambian modelo de ejecución y spread. Falta la matriz con
`AUDCAD.PARITY`, spread fijo 17/60 y MT4 Every tick descrita en
`docs/comparacion-justa.md`.

## 3. Configuraciones

| Input | C0 | C1 | C1p | C2 |
|---|---:|---:|---:|---:|
| `RiskPct` | 0,5 | 0,745 | 0,80 | 0,5 |
| `SlPips` | 40 | 200 | 200 | 60 |
| `TpPips` | 8 | 8 | 8 | 20 |
| `GridStepPips` | 22 | 22 | 22 | 5 |
| `LotMultiplier` | 1,5 | 1,667 | 1,667 | 1,5 |
| `MaxGridSteps` | 4 | 20 | 20 | 4 |
| `MaxLotPerOrder` | 0,10 | 9,0 | 9,0 | 0,10 |
| `MaxVolumePerStrategy` | 0,30 | 9,0 | 9,0 | 0,30 |
| `MaxBasketLossPct` | 2,0 | 1000 | 1000 | 2,0 |
| `DailyLossLimitPct` | 4,0 | 1000 | 1000 | 4,0 |
| `MaxSpreadPips` | 3,0 | 100 | 100 | 10 |
| `MaxAtrPips` | 30 | 100 | 100 | 100 |

C1p es la corrección de calibración de C1: con 0,745 el lote inicial salía 0,04
en enero por el redondeo hacia abajo; con 0,80 sale 0,05, que es el lote base
del original. A partir de febrero C1 ya daba 0,05 porque el balance había
crecido.

## 4. Sets y configs archivados

`sets/mt5/`: `C0-s0..2.set`, `C1-s0..2.set`, `C1p-s0..2.set`, `C2-s0..2.set`,
`P-NS-ALL.set` y `R11_ALL_P-NS_6m.ini` (portafolio).
El sufijo `s0/s1/s2` es Scalper / Fibonacci / TrendMaster.

`sets/mt4/`: `CodigoOriginalMT4_2024H1.set` (inputs exactos de enero),
`run_r00_control.ini` y `run_r01_6m.ini`.

## 5. Observaciones para el análisis

1. **Spread de R01:** el reporte declara `Current (60)`, frente a `Current (17)`
   de enero. No es la misma condición de spread; hay que decidir si se repite
   R00/R01 con `TestSpread` fijo antes de comparar con MT5.
2. **Cierres forzados:** R01 cierra 7 posiciones al último tick (0,76 lotes).
   Contarlas aparte al atribuir P&L por mes.
3. **C1 vs C1p:** la única diferencia es el lote inicial de enero (0,04 vs
   0,05). No cambia la conclusión de signo, pero sí la magnitud.
4. **Riesgo C1:** el peor `max_projected_loss_pct` medido es 62,66 % (R06) y
   62,45 % (R06b), con `MaxBasketLossPct` desactivado. Es diagnóstico, no
   producción.
5. **Modelos distintos:** MT4 Control points vs MT5 1 minute OHLC. Los
   drawdowns no son estrictamente comparables (balance vs equidad).
6. **`informe6m.md` sigue desactualizado:** todavía marca PENDIENTE las
   corridas de 6 meses. Se actualiza después del análisis.

## 6. Corridas previas de MT5

`reportes/mt5/` también contiene los reportes anteriores: enero 2024 (3
estrategias), enero–febrero, año 2024, límite diario 0,5 %, riesgo 0,1 %,
réplica y reproducibilidad (`repro_a` / `repro_b`). Se conservan como
evidencia de la identidad de P&L y del determinismo.
