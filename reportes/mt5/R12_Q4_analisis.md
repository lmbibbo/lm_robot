# R12 — Auditoría out-of-sample Q4 2024 (R11 / P-NS-ALL)

Fecha de ejecución: 2026-11-08
EA: `EA/LmRobot.ex5` compilado **X64 Regular** (129.250 bytes, 22:40:09)
Símbolo: AUDCAD H1 · Modelo: Open prices · Depósito: 10.000 USD · Leverage 1:100
Set base: R11 `P-NS-ALL` (baked en los defaults del EA)

## 1. Corridas ejecutadas

| # | Ventana | RiskPct | Neto | Balance final | DD máx | Órdenes | Fin real del test |
|---|---------|---------|------|---------------|--------|---------|-------------------|
| R11 (referencia) | 2024.01.01–2024.07.01 | 4.0 | **+3.173,21** | 13.173,21 | 8,54 % | 695 | 2024.07.01 |
| R12-a | 2024.01.01–2025.01.01 | 4.0 | **+8.683,32** | 18.683,32 | 86,00 % | 1.497 | 2024.12.31 |
| R12-b | 2024.08.01–2024.11.01 | 4.0 | **−9.140,34** | 859,66 | 92,20 % | 232 | **2024.09.30 04:59:58** |
| R12-c | 2024.10.01–2024.11.01 | 4.0 | **+692,49** | 10.692,49 | 3,77 % | 181 | 2024.10.31 |
| R12-d | 2024.08.01–2024.11.01 | 1.0 | **+355,49** | 10.355,49 | 5,23 % | 427 | 2024.10.31 |

Archivos: `R12_Q4_4pct.*`, `R12_OCT_4pct.*`, `R12_Q4_1pct.*` (htm + csv + daily).
Runners: `reportes/sets/mt5/R11_ALL_P-NS_2024Q4.ini` y `run_R11_2024Q4*.ini` en la raíz del terminal.

## 2. Resultado Q4 (R11 tal cual, 4 %)

- El test **no llegó al 1 de noviembre**: terminó el **2024.09.30 a las 04:59:58** porque la cuenta
  fue **liquidada por stop-out** (margin level 16,39 %). MT5 cierra el test al quedar la cuenta
  agotada, por eso la ventana real es 01-ago → 30-sep.
- Pérdida: **−9.140,34 (−91,4 %)**. Balance final 859,66.
- `max_projected_loss = 18.681,17` = **172,6 % del balance**: si el SL de 1.000 pips se hubiera
  ejecutado en el peor momento de la rejilla, la pérdida superaba la cuenta en un 72 %.
- `max_aggregate_loss_pct = 517,79 %`: las 3 estrategias juntas llegaron a tener proyectado
  **5,18× el capital**.
- `max_basket = 2,58` lotes · `max_steps = 6` · `max_order = 1,07`.

### Atribución por estrategia (Q4 @4 %)

| Estrategia | Neto | DD | Órdenes |
|------------|------|----|---------|
| Scalper Pro | −3.034,23 | 3.138,35 | 80 |
| Fibonacci Focus | −3.063,99 | 3.171,58 | 71 |
| TrendMaster | −3.042,12 | 3.109,61 | 81 |

Las tres pierden casi exactamente lo mismo: el evento de septiembre no es un fallo de una
estrategia, es el **riesgo común de la rejilla/martingala** que comparten las tres.

### Curva diaria (Q4 @4 %)

```
12-sep  equity 10.762   (máximo, +7,6 %)
16-sep  −3,36 %
17-sep  −2,56 %
18-sep  −7,69 %
19-sep  −16,82 %
20-sep  −4,45 %
23-sep  −12,90 %
24-sep  −9,44 %
25-sep  −3,26 %
26-sep  −49,34 %   (equity 5.150)
27-sep  −60,66 %   (equity 2.088)
30-sep  −49,78 %   (equity 1.515) → stop-out
```

## 3. Por qué el test se cortó el 30-sep

No es un problema de datos: octubre existe y se testeó aparte (R12-c, 551 barras, hasta el 31-oct).
La causa es la **liquidación de la cuenta**. Prueba directa: la misma ventana con `RiskPct=1.0`
(R12-d) recorre los 3 meses completos y termina el 2024.10.31.

Consecuencia: **el −91,4 % es un resultado truncado**. Si la cuenta hubiera aguantado, el
comportamiento posterior sería el de R12-c (octubre solo: +6,9 % desde 10.000).

## 4. Reconciliación con el +8.683,32 de 2024 completo

Mismo crash, distinto capital de partida:

| Momento | Full 2024 @4 % | Q4 @4 % |
|---------|----------------|---------|
| 01-ago | 14.241,79 | 10.000,00 |
| 12-sep (pico) | 15.401,37 | 10.762,17 |
| 30-sep (mínimo) | 2.514,03 | 1.515,31 → stop-out |
| Resultado del tramo ago–sep | ≈ −8.840 (−62 %) | −9.140 (−91 %) |

La pérdida absoluta del tramo es **parecida (~9.000 USD)** en ambos casos porque los lotes
tocan los topes (`MaxLotPerOrder=9`, `MaxVolumePerStrategy=9`). La diferencia es el colchón:
con 14,2k se sobrevive con −62 %; con 10k se llega al stop-out.

Y el +8.683 anual no viene de una ventaja estable: viene de **octubre**.

```
sep: 14.941 → 5.399   (−64 %)
oct:  3.667 → 16.117  (+340 %, mínimo 2.357)
nov: 16.188 → 17.460
dic: 17.575 → 18.684
```

Es decir: el resultado anual es **supervivencia al crash + rebote de martingala en octubre**.
Un resultado así no es extrapolable: depende de que el crash ocurra con el capital alto.

## 5. Sensibilidad a riesgo (misma ventana Q4)

| Config | Neto | DD | max_basket | max_steps | proj. loss % | agregado % |
|--------|------|----|-----------|-----------|--------------|------------|
| RiskPct 4,0 | −9.140,34 | 92,20 % | 2,58 | 6 | 172,60 | 517,79 |
| RiskPct 1,0 | **+355,49** | **5,23 %** | 0,83 | 7 | 59,20 | 96,29 |
| Oct solo @4,0 | +692,49 | 3,77 % | 0,87 | 4 | 62,90 | 87,93 |

Bajar el riesgo de 4 % a 1 % **no reduce el retorno proporcionalmente** en esta ventana:
convierte −91 % en +3,6 % con DD 5,2 %, y además permite más ciclos (427 vs 232 órdenes).
El problema no es la señal, es el **tamaño y la ausencia de cortacircuitos**.

## 6. Diagnóstico de los controles de riesgo de R11

R11 corre con los tres frenos **desactivados** (valor 1000 = sin límite):

- `MaxBasketLossPct = 1000`
- `DailyLossLimitPct = 1000`
- `MaxAggregateLossPct = 1000`
- `SlPips = 1000` → el SL existe pero es inalcanzable en la práctica: el "stop" real es el margen.
- `MaxGridSteps = 19`, `LotMultiplier = 1.667`, `MaxLotPerOrder = 9`, `MaxVolumePerStrategy = 9`.

Con esa combinación, el peor caso proyectado es varias veces el capital y el único límite
efectivo es el stop-out del bróker.

## 7. Recomendaciones

Para que el sistema sea testeable y operable:

1. **Riesgo**: `RiskPct` 1,0–2,0 (nunca 4 con 19 pasos).
2. **Cortacircuitos reales**:
   - `MaxAggregateLossPct` 30–50
   - `MaxBasketLossPct` 20–30
   - `DailyLossLimitPct` 5–10
3. **Rejilla**: `MaxGridSteps` 8–10; `MaxLotPerOrder` 1,0–2,0; `MaxVolumePerStrategy` 1,0–2,0.
4. **SL coherente**: un SL de 1.000 pips no protege nada; alinearlo con el tamaño de la rejilla
   (p. ej. 3–5× `GridStepPips`) o confiar en el límite de pérdida agregada.
5. **Validación**: repetir 2023 y 2024 completos con la config ajustada; exigir DD < 20 % y
   que el resultado no dependa de un solo mes.
6. No tomar el +3.173,21 de ene–jul como referencia de robustez: es la mitad "fácil" del año.

## 8. Cómo reproducir

```
terminal64.exe /config:"...\run_R11_2024Q4.ini"     # Q4 4 %
terminal64.exe /config:"...\run_R11_2024Q4_r1.ini"  # Q4 1 %
terminal64.exe /config:"...\run_R11_2024OCT.ini"    # octubre solo 4 %
```

Compilar siempre con **X64 Regular** (sin AVX2/FMA3). `config/metaeditor.ini` tiene `CPU=2`
(AVX2+FMA3) y hay que cambiarlo antes de compilar con F7, o compilar por línea de comandos
sin `/avx2`. Con AVX2 el mismo código dio +161,26 en lugar de +3.173,21.
