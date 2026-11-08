# Sets de la comparación justa

Generados el 2026-11-07 a partir de `docs/comparacion-justa.md`.

## MT4 (`mt4/`)

Todos usan AUDCAD H1, 10.000 USD, USD, 1:100, `CodigoOriginalMT4_Test`.
`TestModel`: 0 = Every tick, 1 = Control points, 2 = Open prices only.

| Archivo | Modelo | Spread | Período | Uso |
|---|---|---:|---|---|
| `cj_mt4_control_s17_202401.ini` | Control points | 17 | Ene 2024 | Gate: debe reproducir 732,27 |
| `cj_mt4_open_s17_2024H1.ini` | Open prices only | 17 | 6M | Paridad de lógica |
| `cj_mt4_everytick_s17_2024H1.ini` | Every tick | 17 | 6M | Comparación principal |
| `cj_mt4_everytick_s60_2024H1.ini` | Every tick | 60 | 6M | Sensibilidad de spread (R01) |
| `cj_mt4_everytick_s0_2024H1.ini` | Every tick | 0 | 6M | Piso sin spread |

## MT5 (`mt5/`)

Todas las configs usan `MaxAtrPips=15`, `MaxSpreadPips=100`, `MaxGridSteps=19`,
`LotMultiplier=1.667`, `TpPips=8`, `GridStepPips=22`, límites de canasta/diario
en 1000 (apagados), `UseSessionFilter=false`.
Sufijo `s0/s1/s2` = Scalper / Fibonacci / TrendMaster. Magic: 202611030/1/2.

| Archivo | SlPips | RiskPct | Lote base | Uso |
|---|---:|---:|---:|---|
| `P-NS-s0..2.set` | 1000 | 4.00 | 0,05 | **Comparación principal** (sin stop efectivo) |
| `P-SL200-s0..2.set` | 200 | 0.80 | 0,05 | Contrafactual con stop real (C1) |
| `P-SL20-s0..2.set` | 20 | 0.08 | 0,05 | Sensibilidad al ancho del stop (C1b) |

`RiskPct` está calibrado para que el primer lote sea 0,05 con el `pipValuePerLot`
real (la corrida C1 con 0,745 dio 0,04; C1p con 0,80 dio 0,05).

El modo portafolio ya tiene `P-NS-ALL.set` (`Strategy=3` = ALL,
`MaxAggregateVolume=9`, `MaxAggregateLossPct=1000`) y el runner
`R11_ALL_P-NS_6m.ini`. La corrida de referencia es
`reportes/mt5/R11_ALL_P-NS_6m.htm` (2024 H1, Open prices only).
