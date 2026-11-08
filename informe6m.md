# Comparación a 6 meses: `CodigoOriginalMT4` (MT4) vs `LmRobot` (MT5)

| Campo | Valor |
|---|---|
| Ventana | 2024.01.01 00:00 – 2024.07.01 00:00 (6 meses) |
| Símbolo / timeframe | AUDCAD H1 |
| Depósito inicial | 10.000 USD por cuenta |
| Apalancamiento | 1:100 |
| Cuentas | FBS-Demo — MT4 build 1492 / MT5 build 6182 |
| Fecha del informe | 2026-11-06 (addendum R11: 2026-11-08) |
| Estado | **PARCIAL**: enero verificado; 6M MT4 y 6M MT5 portafolio medidos; comparación controlada pendiente |

> **Regla de este informe.** Ninguna cifra de 6 meses se rellena por extrapolación. Si no existe una corrida, la celda dice `PENDIENTE`. Las únicas cifras que aparecen son las que se pueden reconciliar contra un HTML de resultados, contra el ledger de operaciones o contra el código.

---

## 0. Mapa de verificación

| Bloque | Estado | Base de la verificación |
|---|---|---|
| Auditoría de enero del original (Anexo A) | **Verificado** | Ledger HTML: 211 aperturas, 211 cierres |
| Identidad de P&L y umbral de break-even (§7) | **Verificado** | Álgebra + reconciliación de 4 corridas MT5 |
| Inventario de corridas existentes (§3) | **Verificado** | 32 informes HTML (29 MT5 + 3 MT4) + sets y CSV |
| Configuraciones C0 / C1 / C2 (Anexo B) | **Ejecutado** | R02–R10, totales de §5.2–§5.4 |
| Resultado 6M MT4 (R01) | **Verificado** | HTML `lm_robot_mt4_original_2024H1_10k.htm` |
| Resultado 6M MT5 portafolio (R11) | **Verificado** | HTML + CSV `R11_ALL_P-NS_6m` |
| Desglose mensual febrero–junio | **PENDIENTE** | Los HTML no separan meses |
| Comparación controlada (spread/modelo) | **PENDIENTE** | Falta `AUDCAD.PARITY`, spread fijo y MT4 Every tick |
| Veredicto a 6 meses (§9) | **PARCIAL** | Hay Net 6M de ambos motores, pero no con feed/spread igualados |

> **Proveniencia.** Este informe se produjo en modo exploración: no se modificó código ni configuración, y no se ejecutaron testers nuevos. Las cifras de enero y de las corridas existentes se extrajeron de los HTML ya presentes en el terminal; las configuraciones C0/C1/C2 son propuestas, no resultados.
>
> **Addendum 2026-11-08.** Se ejecutó R11 (`Strategy=ALL`, P-NS, 2024.01.01–2024.07.01,
> Open prices only) y se corrigió la atribución por magic. El resultado está en
> §5.6 y en `reportes/mt5/R11_ALL_P-NS_6m.htm`. No se modificó el EA de MT4.

---

## 1. Resumen ejecutivo

### 1.1 Lo que ya se puede afirmar

1. **El beneficio de enero del original es aritmética, no una señal superior.** Cerró las 211 operaciones en take-profit, ninguna en stop loss, y las 99 agrupaciones de cierre simultáneo disponibles (ver A.2) terminaron en positivo. Movió 13,14 lotes y ganó 732,27 USD, es decir **55,73 USD por lote** (≈7,5 pips netos por lote).
2. **La única configuración MT5 con corridas de varios meses es C2** (`SlPips=60`, `TpPips=20`, `GridStepPips=5`, `MaxSpreadPips=10`, `MaxAtrPips=100`), no los defaults del código. En enero el original movió 13,14 lotes sobre 10.000 USD; C2 movió 13,00 lotes sobre tres cuentas de 10.000 USD (30.000 USD), es decir, con un tercio del volumen por dólar. Aun así, C2 cerró el **23,1 % de su volumen en un stop de 60 pips** y el original el 0 %. Ahí está la diferencia de resultado.
3. **El umbral `Tp/(Tp+Sl)` predice el signo de todas las corridas medidas.** Para C2 el break-even es 25 % del volumen detenido; Fibonacci detuvo 12,2 % y ganó, Scalper 40,9 % y perdió, TrendMaster 35,1 % y perdió.
4. **C0, C1 y C1p ya se corrieron a 6 meses** (R02–R07b), y el portafolio `Strategy=ALL` también (R11, P-NS). Lo que todavía **no existe es una comparación controlada**: falta igualar feed, spread y modelo entre MT4 y MT5.

### 1.2 Lo que todavía no se puede afirmar

- Si la ventaja de enero del original se mantiene, se reduce o se invierte entre febrero y junio.
- Si C0 (defaults del código) o C1 (paridad de tamaño con stop real) cierran la brecha de beneficio.
- Si alguna configuración sobrevive a un semestre adverso.

Con las corridas de 6 meses ya disponibles: MT4 R01 cerró **+3.201,77**; MT5 portafolio R11 cerró **+3.173,21**; C0 agregado −1.719,41; C1p agregado +3.185,85. La brecha de enero no se mantiene en C0, pero el portafolio nuevo queda a 0,9 % del original.

### 1.3 Consecuencia práctica

No conviene cambiar el diseño ni los valores por defecto con la evidencia actual. Lo que falta no es otra corrida suelta sino la matriz controlada: mismo feed M1, spread fijo 17/60, `AUDCAD.PARITY` y MT4 Every tick. La identidad de §7 permite anticipar el signo de cada configuración, pero no su magnitud.

---

## 2. Objetivo, alcance y preguntas

### 2.1 Pregunta principal

¿La ventaja de beneficio del `CodigoOriginalMT4` observada en enero de 2024 se mantiene durante el primer semestre de 2024, o es un artefacto de un mes favorable y de una estructura de riesgo distinta?

### 2.2 Preguntas secundarias

1. ¿La brecha se explica por la lógica de entrada/salida o por el tamaño de posición y el stop loss?
2. ¿Alguna configuración de `LmRobot` puede igualar el beneficio del original sin reproducir su exposición sin stop?
3. ¿Qué configuración es la candidata para una comparación de robustez (drawdown, exposición, cantidad de operaciones)?

### 2.3 Fuera de alcance

- Modificar código, defaults o lógica.
- Optimizar parámetros.
- Operar en real.
- Cambiar el período o el símbolo.

---

## 3. Inventario de datos y limitaciones

### 3.1 Qué existe

**MT4 — `CodigoOriginalMT4`**

| Corrida | Período | Modelo | Net | PF | DD | Trades | Artefacto |
|---|---|---|---:|---:|---:|---:|---|
| Original enero | 2024.01.01–2024.02.01 | Control points | **+732,27** | 4,59 | 2,46 % (balance) | 211 | `lm_robot_mt4_original_202401_10k.htm` |

No hay ninguna otra corrida MT4. El original corre las tres estrategias en una sola cuenta.

**MT5 — `LmRobot`**

| Familia | Config real | Período | Estrategias | Net (USD) | PF | DD equidad | Trades |
|---|---|---|---|---|---|---|---|
| Enero (3 corridas) | C2 | 01.01–02.01 | S / F / T | −53,99 / +412,87 / −483,14 | 0,89 / 3,65 / 0,44 | 3,36 / 1,63 / 6,07 % | 41 / 43 / 46 |
| Ene–Feb (3 corridas) | C2 | 01.01–03.01 | S / F / T | −720,84 / +431,94 / −527,68 | 0,42 / 1,94 / 0,57 | 10,28 / 3,14 / 7,23 % | 66 / 74 / 77 |
| Año 2024 (1 corrida) | C2 | 01.01–12.31 | S | −2.650,23 | 0,62 | 28,80 % | 544 |
| Límite diario 0,5 % (1) | C2 + `DailyLossLimitPct=0.5` | 01.01–03.01 | S | +179,57 | 1,25 | 2,38 % | 79 |
| Reproducibilidad (2) | C2 | 01.01–03.01 | S | −720,84 ×2 | 0,42 | 10,28 % | 66 |
| Riesgo 0,1 % (3) | C2 + `RiskPct=0.1` | 01.01–02.01 | S / F / T | +203,96 / +283,79 / −267,88 | 2,73 / 45,97 / 0,42 | 1,66 / 1,04 / 4,39 % | 65 / 58 / 60 |
| Réplica (3) | `SlPips=1000`, `TpPips=8`, `GridStepPips=22` | 01.01–02.01 | S / F / T | +86,49 / +75,44 / +48,60 | 3,26 / 5,45 / 1,40 | 1,19 / 0,33 / 2,37 % | 53 / 60 / 44 |
| **R11** | **P-NS, `Strategy=ALL`** | **01.01–07.01** | **3 en 1 cuenta** | **+3.173,21** | **2,36** | **8,54 % (equidad)** | **695** |

S = Scalper Pro, F = Fibonacci Focus, T = TrendMaster.

### 3.2 Qué no existe

- Ninguna corrida MT4 con spread fijo y modelo Every tick.
- Ninguna corrida MT5 de 6 meses con spread fijo (`AUDCAD.PARITY` no existe).
- Ninguna corrida MT5 P-NS por estrategia en 6 meses (solo el portafolio R11).
- Fibonacci Focus y TrendMaster a año completo.
- Desglose por `magic number` en el HTML de MT4.
- Volumen acumulado en el CSV de `OnTester` (solo registra máximos).
- Desglose mensual nativo: el informe HTML no separa meses.

### 3.3 Corrección de etiquetas de `informe.md`

`informe.md` llama “default” a corridas que **no** usan los defaults del código. La inspección de los HTML muestra:

| Etiqueta en `informe.md` | Inputs reales | Nombre correcto |
|---|---|---|
| “`LmRobot` default” | `SlPips=60`, `TpPips=20`, `GridStepPips=5`, `MaxSpreadPips=10`, `MaxAtrPips=100` | **C2** |
| “Riesgo 0,1 %” | C2 + `RiskPct=0.1` | **C2-r01** |
| “Réplica original” | `SlPips=1000`, `TpPips=8`, `GridStepPips=22`, topes altos | **Réplica** (no es C1) |
| “Inputs por defecto” en §2.2 | `SlPips=40`, `TpPips=8`, `GridStepPips=22`, `MaxSpreadPips=3`, `MaxAtrPips=30` | **C0** — nunca ejecutado |

Consecuencia: **todo el cuerpo de evidencia MT5 existente pertenece a C2, a variantes de C2 o a la réplica sin stop**, no a los defaults. Cualquier afirmación sobre “el motor nuevo con sus defaults” carece de corrida.

### 3.4 Limitaciones

1. **Motores de modelado distintos.** MT4 usa *Control points*; el propio reporte advierte “a very crude method, the results must not be considered”. MT5 usa *1 minute OHLC*. No son la misma secuencia de ticks.
2. **Drawdown no comparable.** MT4 informa drawdown sobre balance; MT5 informa drawdown sobre equidad. Los porcentajes no se restan.
3. **Estructura de cuenta.** El original corre tres estrategias en una cuenta de 10.000 USD. `LmRobot` puede correr una estrategia por gráfico (agregado de tres cuentas de 10.000 USD) o el modo `Strategy=ALL`, que sí reproduce una sola cuenta de 10.000 USD con las tres señales. R11 usa `ALL`; las corridas R02–R10 usan tres cuentas.
4. **El original no envía stop loss.** Los seis `OrderSend` del `.mq4` pasan `0, 0` en SL/TP (líneas 1561, 1571, 1699, 1713, 1843, 1853). El SL se calcula pero nunca se envía. La comparación beneficio/riesgo es estructuralmente asimétrica.
5. **El original requiere un parche de banco de pruebas.** Sin acotar los reintentos de `OrderModify`, entra en bucle y genera un log de 22 GB. La copia `CodigoOriginalMT4_Test.mq4` solo limita reintentos; no cambia ninguna regla de entrada, salida, lotaje ni gestión.
6. **`UseNewsFilter` es código muerto.** Está declarado en la línea 49 y no se lee en ninguna otra línea. No hay filtro de noticias en ninguno de los dos motores.
7. **El HTML de MT4 no trae `magic number`.** Las canastas se reconstruyen por cierre simultáneo (§A.2). Si dos estrategias cierran en el mismo segundo, se agrupan.
8. **Atribución mensual.** En las corridas continuas, el P&L de un mes se atribuye por fecha de cierre; una posición abierta a fin de mes cae en el mes siguiente. No es lo mismo que una corrida mensual independiente.
9. **Spread del tester MT4.** El `.ini` usa `TestSpread=0` (spread actual). El reporte declara “Current (17)”. El valor efectivo no queda fijado en el `.ini`, así que no es reproducible byte a byte entre terminales.
10. **El CSV de `OnTester` no registra volumen acumulado.** Para la identidad de §7 hay que sumar el volumen desde la tabla de deals del HTML.
11. **C1 tiene los topes altos a propósito.** Es una configuración de diagnóstico, no un candidato de producción (ver advertencia en §4.3).
12. **Los resultados son in-sample.** No hay validación fuera de 2024.

### 3.5 Controles de calidad aplicados

| Control | Resultado |
|---|---|
| Aperturas = cierres = cierres en t/p (MT4 enero) | 211 = 211 = 211 |
| Suma de P&L de cierres = net del reporte | 732,27 = 732,27 |
| Lotes abiertos = lotes cerrados | 13,14 = 13,14 |
| Grupos de cierre con P&L positivo | 99 / 99 |
| Reconciliación MT5: `Σ(profit + swap) = net` | Exacta en las 4 corridas verificadas |
| Reproducibilidad MT5 (`repro_a` vs `repro_b`) | 429 / 429 líneas normalizadas idénticas |

---

## 4. Matriz de corridas

### 4.1 Parámetros fijos

| Parámetro | Valor |
|---|---|
| Símbolo | AUDCAD |
| Timeframe | H1 |
| Desde | 2024.01.01 00:00 |
| Hasta | 2024.07.01 00:00 |
| Depósito | 10.000 USD |
| Apalancamiento | 1:100 |
| Divisa | USD |
| MT4: modelo | Control points (`TestModel=1`) |
| MT5: modelo | 1 minute OHLC |

### 4.2 Configuraciones

| Input | C0 (defaults) | C1 (paridad + stop real) | C2 (continuidad) |
|---|---:|---:|---:|
| `Strategy` | 0 / 1 / 2 | 0 / 1 / 2 | 0 / 1 / 2 |
| `RiskPct` | 0,5 | **0,745** | 0,5 |
| `SlPips` | 40 | **200** | 60 |
| `TpPips` | 8 | 8 | 20 |
| `GridStepPips` | 22 | 22 | 5 |
| `LotMultiplier` | 1,5 | 1,667 | 1,5 |
| `MaxGridSteps` | 4 | 20 | 4 |
| `MaxLotPerOrder` | 0,10 | 9,0 | 0,10 |
| `MaxVolumePerStrategy` | 0,30 | 9,0 | 0,30 |
| `MaxBasketLossPct` | 2,0 | 1000 | 2,0 |
| `DailyLossLimitPct` | 4,0 | 1000 | 4,0 |
| `MaxSpreadPips` | 3,0 | 100 | 10 |
| `MaxAtrPips` | 30 | 100 | 100 |
| `AtrPeriod` | 14 | 14 | 14 |
| `AtrTimeframe` | actual | actual | actual |
| `UseSessionFilter` | false | false | false |
| **Lote inicial calculado (10.000 USD)** | **0,10** (tope) | **0,05** | **0,10** (tope) |

### 4.3 Racionalidad de cada configuración

**C0 — control literal del código.**
Es la configuración que un usuario obtiene al arrastrar el EA al gráfico. Nunca se ha corrido. Su lote inicial bruto sería 0,5 % × 10.000 / (40 × 7,44) = 0,168, recortado a 0,10 por `MaxLotPerOrder`. Su break-even de volumen detenido es 16,7 %.

**C1 — paridad de tamaño con stop real.**
El original calcula el lote con `(Risk/1000 × balance) / effectiveStopLoss`, donde `effectiveStopLoss` es un número plano que vale 200 (no se convierte a pips). Con 10.000 USD y `Risk=1` eso da 0,05 lotes, que es el lote base observado. C1 reproduce ese lote (0,05) y convierte ese 200 en un stop real de 200 pips, con grilla de 22 pips y TP de 8 pips. El `RiskPct` se deriva así:

```
RiskPct = baseLot × SlPips × pipValuePerLot / balance × 100
        = 0,05 × 200 × 7,44 / 10.000 × 100
        = 0,744  →  0,745
```

> **Advertencia sobre C1.** Con los topes en 9 lotes y el stop en 200 pips, una canasta que llegue al tope perdería 9 × 200 × 7,44 = **13.392 USD (134 % de la cuenta)**. C1 es un diagnóstico de “¿qué pasa si el original tuviera stop real?”, no una configuración recomendada. Si C1 gana, repetir con `MaxBasketLossPct=5` antes de considerarla.

> **Calibración fina de C1.** El lote 0,05 está en el borde del redondeo: con `pipValuePerLot > 7,45` el cálculo da 0,0499 y el `floor` lo deja en 0,04. Verificar en R05 que el primer lote sea 0,05; si sale 0,04, subir `RiskPct` a 0,76–0,80 y documentarlo.

**C2 — continuidad con la evidencia existente.**
Es la configuración base de todas las corridas MT5 de varios meses que ya existen (enero, enero–febrero, año completo). Sirve para comparar 6 meses contra datos previos sin cambiar dos variables a la vez. Su break-even de volumen detenido es 25 %.

### 4.4 Corridas a ejecutar

| ID | Motor | Config | Estrategia | `Strategy` | Período | Salida esperada |
|---|---|---|---|---|---:|---|
| R00 | MT4 | original | 3 en 1 | — | 01.01–02.01 | Control de enero (debe dar 732,27) |
| R01 | MT4 | original | 3 en 1 | — | 01.01–07.01 | 6 meses |
| R02 | MT5 | C0 | Scalper Pro | 0 | 01.01–07.01 | 6 meses |
| R03 | MT5 | C0 | Fibonacci Focus | 1 | 01.01–07.01 | 6 meses |
| R04 | MT5 | C0 | TrendMaster | 2 | 01.01–07.01 | 6 meses |
| R05 | MT5 | C1 | Scalper Pro | 0 | 01.01–07.01 | 6 meses |
| R06 | MT5 | C1 | Fibonacci Focus | 1 | 01.01–07.01 | 6 meses |
| R07 | MT5 | C1 | TrendMaster | 2 | 01.01–07.01 | 6 meses |
| R08 | MT5 | C2 | Scalper Pro | 0 | 01.01–07.01 | 6 meses |
| R09 | MT5 | C2 | Fibonacci Focus | 1 | 01.01–07.01 | 6 meses |
| R10 | MT5 | C2 | TrendMaster | 2 | 01.01–07.01 | 6 meses |
| R11 | MT5 | P-NS | Portafolio ALL | 3 | 01.01–07.01 | 6 meses en una cuenta de 10k |

Total: **10 corridas principales + 1 control + 1 portafolio**.

R00 es barato y evita interpretar un R01 que no reproduzca enero. Si R00 no da 732,27 ± 1 %, hay un cambio de spread, de datos o de versión del terminal y R01 no es comparable con el ledger de enero.

### 4.5 Criterios de aceptación por corrida

1. El período del reporte es exactamente `2024.01.01–2024.07.01`.
2. `Σ(profit + swap)` de la tabla de deals = `Total Net Profit` del reporte.
3. Número de cierres = `Total Trades`.
4. En MT5, `limits_respected=SI` (salvo C1, que tiene los límites desactivados: en ese caso registrar el valor y no tratarlo como fallo).
5. Registrar `max_order_volume`, `max_basket_volume`, `max_grid_steps`, `max_projected_loss_pct`, `daily_limit_hits`.
6. Registrar el volumen abierto al final de cada mes (posiciones que cruzan el corte).
7. En MT4, verificar que la columna S/L siga en `0.00000` y que no haya cierres `s/l`.
8. Guardar el HTML, el CSV de `OnTester`, el `_daily.csv` y el `.set` usado.

---

## 5. Resultados mensuales (enero–junio)

### 5.1 MT4 — `CodigoOriginalMT4`

| Mes | Net (USD) | Retorno | PF | DD balance | Trades | Tickets ganadores | Grupos de cierre | Lotes |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Enero | **+732,27** | +7,32 % | 4,59 | 2,46 % | 211 | 162 (76,78 %) | 99 / 99 positivos | 13,14 |
| Febrero | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| Marzo | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| Abril | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| Mayo | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| Junio | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| **Total 6M** | **+3.201,77** | **+32,02 %** | **1,95** | **17,28 %** | **589** | PENDIENTE | PENDIENTE | **62,12** |

> La fila de enero es la corrida mensual independiente (spread 17). R01 es la corrida continua de 6 meses (spread 60): en ella enero cierra con +515,02 porque las posiciones abiertas al 31-01 siguen hasta febrero, y hay 7 cierres forzados al final. No es un error de ninguna de las dos corridas.

### 5.2 C2 — continuidad con la evidencia previa

| Mes / corte | Scalper | Fibonacci | TrendMaster | Agregado | Nota |
|---|---:|---:|---:|---:|---|
| Enero (corrida mensual) | −53,99 | +412,87 | −483,14 | **−124,26** | Cierre forzado al 31-01 |
| Enero (atribución en corrida 2M) | +7,94 | +421,20 | −437,88 | **−8,74** | Por fecha de cierre |
| Febrero (atribución en corrida 2M) | −728,78 | +10,74 | −89,80 | **−807,84** | Incluye cierres forzados al 29-02 |
| **Ene–Feb verificado** | **−720,84** | **+431,94** | **−527,68** | **−816,58** | Suma exacta de los 3 reportes |
| Marzo | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | — |
| Abril | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | — |
| Mayo | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | — |
| Junio | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | — |
| **Total 6M** | **−1.644,61** | **−238,01** | **−1.343,99** | **−3.226,61** | R08 / R09 / R10 |

La diferencia entre “enero mensual” (−124,26) y “enero por atribución” (−8,74) no es un error: la corrida mensual fuerza el cierre de las posiciones abiertas el 31-01, mientras la corrida de 2 meses las deja correr hasta febrero. Es la razón por la que §5.5 fija una convención. El desglose mensual de la corrida de 6M no está disponible en el HTML; solo el total.

### 5.3 C0 — defaults del código

| Mes | Scalper | Fibonacci | TrendMaster | Agregado | Trades | Peor DD |
|---|---:|---:|---:|---:|---:|---:|
| Enero | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| Febrero | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| Marzo | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| Abril | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| Mayo | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| Junio | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| **Total 6M** | **−806,55** | **−475,96** | **−436,90** | **−1.719,41** | **808** | **9,95 %** |

### 5.4 C1 — paridad de tamaño con stop real

| Mes | Scalper | Fibonacci | TrendMaster | Agregado | Trades | Peor DD |
|---|---:|---:|---:|---:|---:|---:|
| Enero | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| Febrero | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| Marzo | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| Abril | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| Mayo | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| Junio | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| **Total 6M** | **+991,94** | **+1.019,97** | **+1.055,12** | **+3.067,03** | **733** | **13,94 %** |

> C1 usa `RiskPct=0,745`; en enero el lote inicial salió 0,04. La variante C1p (`RiskPct=0,80`, lote 0,05) cierra en +3.185,85 y está archivada como R05b–R07b.

### 5.5 Comparación a 6 meses (veredicto)

| Motor / config | Net 6M | Retorno | PF | Peor DD | Trades | Volumen | % volumen detenido |
|---|---:|---:|---:|---:|---:|---:|---:|
| MT4 original (R01) | +3.201,77 | +32,02 % | 1,95 | 17,28 % (balance) | 589 | 62,12 | 0 % |
| MT5 C0 (agregado 3 cuentas) | −1.719,41 | −5,73 % | — | 9,95 % (equidad) | 808 | — | — |
| MT5 C1 (agregado 3 cuentas) | +3.067,03 | +10,22 % | — | 13,94 % (equidad) | 733 | — | — |
| MT5 C2 (agregado 3 cuentas) | −3.226,61 | −10,76 % | — | 19,42 % (equidad) | 613 | — | — |
| **MT5 P-NS portafolio (R11, 1 cuenta)** | **+3.173,21** | **+31,73 %** | **2,36** | **8,54 % (equidad) / 3,36 % (balance)** | **695** | **57,41** | **0 %** |

> Las filas C0/C1/C2 son tres cuentas de 10.000 USD (30.000 USD) y 1 minute OHLC;
> R11 es una sola cuenta de 10.000 USD con `Strategy=ALL` y Open prices only.
> R01 y R11 tienen Net casi igual, pero no son todavía una comparación controlada.

**Convención mensual (obligatoria para que la tabla sea comparable):**

1. Atribuir cada cierre al mes de su fecha de cierre.
2. Reportar aparte el volumen y el P&L flotante de las posiciones abiertas al último tick de cada mes.
3. No sumar los agregados de MT5 como si fueran una cartera de 10.000 USD: son tres cuentas de 10.000 USD. El retorno agregado se calcula sobre 30.000 USD.
4. Para MT4, usar el mismo criterio; el original corre tres estrategias en una sola cuenta, así que su retorno sí es sobre 10.000 USD.

### 5.6 R11 — portafolio `Strategy=ALL` (6 meses)

Corrida del 2026-11-08 sobre AUDCAD H1, 2024.01.01–2024.07.01, una cuenta de
10.000 USD, 1:100, `P-NS-ALL.set`, modelo Open prices only. Artefactos:
`reportes/mt5/R11_ALL_P-NS_6m.htm`, `.csv` y `_daily.csv`.

| Métrica | MT4 R01 | MT5 R11 |
|---|---:|---:|
| Net | +3.201,77 | +3.173,21 |
| Retorno sobre 10k | +32,02 % | +31,73 % |
| Profit factor | 1,95 | 2,36 |
| Trades / cierres | 589 | 695 (688 tp + 7 end of test) |
| Volumen operado | 62,12 lotes | 57,41 lotes |
| Exposición concurrente máx. | 5,95 lotes | 3,03 lotes |
| DD balance | 2.034,97 (17,28 %) | 413,64 (3,36 %) |
| DD equidad | n/a | 1.049,40 (8,54 %) |
| Lote base | 0,05 | 0,05 por estrategia |
| `limits_respected` / `aggregate_respected` | n/a | SI / SI |

Atribución por magic, que reconcilia exactamente con el Net:

| Estrategia | Magic | Net | DD máx. | Volumen máx. |
|---|---:|---:|---:|---:|
| Scalper Pro | 202611030 | +1.122,95 | 698,48 | 1,82 |
| Fibonacci Focus | 202611031 | +900,27 | 880,18 | 1,05 |
| TrendMaster | 202611032 | +1.149,99 | 654,62 | 1,51 |
| **Suma** | | **+3.173,21** | | |

**Salvedades.**

1. MT4 R01 usó Control points y spread `Current (60)`; R11 usó Open prices only
   y el spread variable del símbolo. La diferencia de Net (0,9 %) es indicativa,
   no un veredicto.
2. El DD de MT4 es sobre balance y el de MT5 prioritariamente sobre equidad; no
   se restan.
3. Los 7 cierres forzados al final del test (0,79 lotes, −66,87 USD) se
   registran con `magic=0`. La atribución ahora los recupera por
   `DEAL_POSITION_ID`; antes de la corrección `portfolio_net` sumaba 3.240,08.

---

## 6. Comparación disponible hoy: enero

### 6.1 Volumen parecido, capital y stops distintos

| Métrica | MT4 original | MT5 C2 (3 cuentas) |
|---|---:|---:|
| Capital | 10.000 USD | 30.000 USD (3 × 10.000) |
| Volumen abierto | 13,14 lotes | 13,00 lotes |
| Volumen por 10.000 USD | 13,14 lotes | 4,33 lotes |
| Volumen cerrado en TP | 13,14 (100 %) | 9,30 (71,5 %) |
| Volumen cerrado en SL | **0 (0 %)** | **3,00 (23,1 %)** |
| Volumen abierto al corte | 0 | 0,70 (5,4 %) |
| Net | **+732,27** | **−124,26** |
| Operaciones | 211 tickets | 130 trades |
| Profit factor | 4,59 | 0,92 |
| Peor DD | 2,46 % (balance) | 6,07 % (equidad) |

La diferencia no está solo en cuánto operó cada motor. En términos absolutos movieron un volumen parecido, pero el original lo hizo sobre una sola cuenta de 10.000 USD (3× más volumen por dólar) y **no cerró ni un lote en pérdida**; `LmRobot` operó sobre 30.000 USD y cerró 3,00 lotes en un stop de 60 pips.

### 6.2 La aritmética de enero

- Original: `13,14 lotes × 7,49 pips netos × 7,44 USD/pip = 732,27 USD`.
- C2: el tramo de TP aportó `9,30 × 20 × 7,44 = 1.383,8 USD`; el tramo de SL restó `3,00 × 60 × 7,44 = 1.339,2 USD`. El neto de ambos tramos es +44,6 USD; el resto de la diferencia corresponde a swap (−54,7 USD) y a la posición abierta al corte.

### 6.3 Las tres estrategias no son equivalentes

En C2, con el mismo `Tp/Sl = 20/60` y el mismo umbral de 25 %:

| Estrategia | % volumen detenido (ene–feb) | Net (ene–feb) | Signo |
|---|---:|---:|---|
| Fibonacci Focus | 12,2 % | +431,94 | Positivo |
| TrendMaster | 35,1 % | −527,68 | Negativo |
| Scalper Pro | 40,9 % | −720,84 | Negativo |

TrendMaster es la única estrategia negativa de forma consistente (35–40 % de volumen detenido frente a un break-even de 25 %). Enero fue un mes favorable para AUDCAD (el par cayó ~230 pips), lo que explica que el original, siendo netamente vendedor, ganara tanto.

### 6.4 Qué cambiaría el veredicto

- Si febrero–junio son meses laterales o alcistas, el sesgo vendedor del original debería sufrir y la ventaja de enero debería reducirse.
- Si C0 y C1 detienen menos volumen que C2 (por grilla de 22 pips y TP de 8), su resultado debería acercarse al del original.
- Si C1 no se acerca, el problema no es el tamaño de posición sino la lógica de entrada/grilla.

---

## 7. Identidad diagnóstica del P&L

### 7.1 Unidades

El bróker es de 5 decimales en AUDCAD:

- 1 pip = 0,0001 = 10 points.
- `PipStep=220` del original → 22 pips.
- `TakeProfit=80` → 8 pips.
- `GeneralStopLoss=200` → 20 pips como precio; como número plano en la fórmula de lotaje equivale a un denominador de 200 (de ahí el 0,05 de C1). Nunca se envía.
- `MaxAllowedATR=150` → 15 pips (el filtro es prácticamente inerte).
- `SlPips` y `TpPips` de `LmRobot` están en pips, no en points.

### 7.2 Fórmula

Para una canasta con volumen total `V` (lotes), valor del pip `p` (USD por pip por lote) y cierre íntegro en TP o SL:

```
Net = Tp × p × V_tp  −  Sl × p × V_sl  −  P&L de lo que quede abierto
```

El umbral de volumen detenido que iguala a cero es:

```
f* = V_sl / (V_tp + V_sl) = Tp / (Tp + Sl)
```

Si `f > f*`, la configuración pierde; si `f < f*`, gana. Es una identidad de volumen, no de cantidad de operaciones.

### 7.3 Valores por lote (p = 7,44 USD/pip)

| TP / SL | USD por lote en TP | USD por lote en SL | `f*` |
|---|---:|---:|---:|
| 8 / 40 (C0) | +59,5 | −297,6 | 16,7 % |
| 20 / 60 (C2) | +148,8 | −446,4 | 25,0 % |
| 8 / 200 (C1) | +59,5 | −1.488,0 | 3,85 % |
| 8 / 1.000 (réplica) | +59,5 | −7.440,0 | 0,79 % |
| 8 / 20 (C1b, ver §9) | +59,5 | −148,8 | 28,6 % |

### 7.4 Verificación empírica

Con los volúmenes extraídos de la tabla de deals de cada HTML:

| Corrida | Volumen | % en SL | Net real | Net según identidad | Swap | Cierres forzados | No explicado |
|---|---:|---:|---:|---:|---:|---:|---:|
| C2 Scalper (ene–feb) | 6,60 | 40,9 % | −720,84 | −669,60 | −19,51 | −33,06 | +1,33 |
| C2 Fibonacci (ene–feb) | 7,40 | 12,2 % | +431,94 | +520,80 | −57,23 | −33,06 | +1,43 |
| C2 TrendMaster (ene–feb) | 7,70 | 35,1 % | −527,68 | −505,92 | −12,40 | −11,04 | +1,68 |
| C2 Scalper (año 2024) | 46,02 | 34,1 % | −2.650,23 | −2.522,85 | −66,15 | −106,16 | +44,93 |

El residual se descompone en swap + P&L de los cierres forzados al final del test + un término menor de variación del valor del pip y redondeo. En las tres corridas de dos meses ese término menor es 1,3–1,7 USD (0,2–0,4 % del net); en la corrida anual es 44,93 USD (1,7 %), consistente con un año de variación CAD/USD. La identidad reproduce el signo y el orden de magnitud de las cuatro corridas.

### 7.5 Qué no explica la identidad

- **Cuándo** se toca el TP o el SL (timing y secuencia de la grilla).
- **Cuántas** canastas se abren (frecuencia de la señal).
- El swap, la comisión y el P&L flotante al corte.
- Las diferencias entre estrategias con el mismo `Tp/Sl`: la identidad es la misma, pero cada estrategia produce un `f` distinto.
- La fracción por cantidad de operaciones no es la identidad: es solo un proxy cuando el volumen por operación es homogéneo.

---

## 8. Reproducibilidad

### 8.1 MT4 — `.ini` para R01

```ini
ExpertsEnable=true
ExpertsTrades=true
TestExpert=lm_robot\CodigoOriginalMT4_Test
TestSymbol=AUDCAD
TestPeriod=H1
TestModel=1
TestSpread=0
TestOptimization=false
TestDateEnable=true
TestFromDate=2024.01.01
TestToDate=2024.07.01
TestDeposit=10000
TestCurrency=USD
TestLeverage=100
TestReport=lm_robot_mt4_original_2024H1_10k
TestReplaceReport=true
TestShutdownTerminal=true
TestVisualEnable=false
```

Para R00, cambiar solo `TestToDate=2024.02.01` y `TestReport=lm_robot_mt4_original_202401_control`.

`TestSpread=0` mantiene la metodología de enero (spread actual). El reporte declara el valor efectivo en el encabezado (“Spread Current (17)” en enero). Si el terminal cambia de spread entre corridas, fijar `TestSpread=17` y repetir R00 para cuantificar la diferencia.

### 8.2 MT5 — procedimiento

1. Abrir el Strategy Tester de MT5 (build 6182).
2. Expert: `LmRobot`. Símbolo: `AUDCAD`. Período: `H1`.
3. Fecha: `2024.01.01` – `2024.07.01`. Modelo: `1 minute OHLC`.
4. Depósito: `10.000 USD`. Apalancamiento: `1:100`.
5. Pestaña Inputs → cargar el `.set` de Anexo B (o introducir los valores de la tabla §4.2).
6. Ejecutar y guardar el HTML con el nombre de la tabla §4.4.
7. Verificar los criterios de §4.5 antes de pasar a la corrida siguiente.

Para R11 el runner está en `reportes/sets/mt5/R11_ALL_P-NS_6m.ini`
(`Strategy=ALL`, `P-NS-ALL.set`, `Model=2` = Open prices only); se puede lanzar
con `terminal64.exe /config:ruta\R11_ALL_P-NS_6m.ini`.

### 8.3 Artefactos a archivar

| Artefacto | Nombre |
|---|---|
| Reporte MT4 R00 | `lm_robot_mt4_original_202401_control.htm` |
| Reporte MT4 R01 | `lm_robot_mt4_original_2024H1_10k.htm` |
| Reportes MT5 | `lm_robot_mt5_2024H1_<config>_<estrategia>.htm` |
| Reporte MT5 portafolio (R11) | `reportes/mt5/R11_ALL_P-NS_6m.htm` |
| Métricas | CSV de `OnTester` + `_daily.csv` por corrida |
| Inputs | `.set` usado en cada corrida |
| Logs | `Tester/logs/<fecha>.log` |

### 8.4 Evidencia de determinismo

`lm_robot_backtest_repro_a.htm` y `lm_robot_backtest_repro_b.htm` son dos corridas idénticas de C2 Scalper (ene–feb). Producen:

- mismo net: −720,84;
- mismo PF: 0,42;
- mismo DD: 10,28 %;
- mismas 429 líneas de contenido normalizado.

El hash binario difiere solo por metadatos de generación del HTML. Conclusión: el tester MT5 es determinista para esta configuración.

### 8.5 Trampas conocidas

1. **`TestSpread=0` en MT4** no fija el spread; hay que registrar el valor efectivo.
2. **Cierres “end of test”**: si la corrida termina con posiciones abiertas, el net incluye su cierre forzado. No confundir con P&L realizado mes a mes.
3. **`MaxAtrPips`**: en `LmRobot` está en pips; en el original `MaxAllowedATR` está en points. No copiar el número sin convertir.
4. **`RiskPct` y `SlPips` están acoplados** en `LmInitialLot`. Cambiar el stop sin recalcular el riesgo cambia el lote.
5. **C1 en el borde del redondeo** (ver §4.3): verificar que el primer lote sea 0,05.
6. **C1 con límites en 1000 %**: `limits_respected` puede dar `SI` aunque la pérdida proyectada supere el 100 % de la cuenta. Leer `max_projected_loss_pct`, no solo el booleano.
7. **El original no debe correrse sin el parche** de reintentos: el bucle de `OrderModify` cuelga el tester.

---

## 9. Conclusiones y decisión pendiente

### 9.1 Conclusiones verificadas

1. **La brecha de enero es de riesgo, no de señal.** El original movió 13,14 lotes sobre 10.000 USD y no detuvo nada; C2 movió 13,00 lotes sobre 30.000 USD y detuvo el 23,1 % del volumen. La diferencia de capital también cuenta, pero no explica por sí sola el signo del resultado.
2. **El original gana por aritmética de TP sin stop**, no por predecir mejor. Su resultado es reproducible con lápiz: 13,14 lotes × ≈7,5 pips netos × 7,44 USD/pip.
3. **La identidad `f* = Tp/(Tp+Sl)` explica el signo de las cuatro corridas medidas** y debe usarse como filtro de diseño antes de correr nada.
4. **El historial MT5 ya cubre C0, C1, C1p y C2 a 6 meses** (R02–R10), además del portafolio P-NS (R11). La afirmación anterior de que solo existía C2 quedó desactualizada.
5. **Hay evidencia de 6 meses para ambos motores.** MT4 R01: +3.201,77 (+32,02 %). MT5 portafolio R11: +3.173,21 (+31,73 %) con la mitad de drawdown de equidad que el original en balance y 57,41 lotes contra 62,12. La diferencia de Net es 0,9 %, pero el veredicto controlado sigue pendiente porque no se igualaron feed, spread ni modelo.
6. **La atribución por estrategia ya reconcilia con el reporte.** R11: 1.122,95 + 900,27 + 1.149,99 = 3.173,21. Los cierres forzados con `magic=0` se recuperan por `DEAL_POSITION_ID`.

### 9.2 Árbol de decisión para cuando estén las corridas

| Si los resultados de §4 muestran… | Entonces… |
|---|---|
| MT4 sigue positivo y C1/C2 negativos | La ventaja es la ausencia de stop; decidir si se replica ese perfil (no recomendado) o se acepta menor retorno con control de riesgo. |
| C1 iguala o supera a MT4 con menor DD | Adoptar la lógica de tamaño de C1 (lote base 0,05, stop real) y descartar la réplica sin stop. |
| C0/C1/C2 negativos y MT4 positivo | El problema es la lógica de entrada/grilla, no el tamaño; abrir un cambio de diseño. |
| Todos negativos | El período 2024-H1 no es favorable para el sistema; no ajustar parámetros con estos datos. |
| C1 gana pero con DD > 20 % | Repetir C1 con `MaxBasketLossPct=5` antes de considerarla. |

### 9.3 Recomendación

1. Completar la matriz controlada: `AUDCAD.PARITY`, spread fijo 17 y 60, MT4 Every tick y MT5 P-NS/ALL con el mismo feed M1. R00–R10 ya tienen corridas base.
2. No modificar código ni defaults antes de tener la tabla de §5.5 controlada.
3. Si se quiere una tercera vía de paridad, agregar **C1b**: `SlPips=20`, `RiskPct=0,0745`, mismo `TpPips=8` y `GridStepPips=22`. Es la lectura literal de `GeneralStopLoss=200` como 200 points = 20 pips; su break-even es 28,6 %, mucho más exigente que el de C1. No está en la matriz aprobada; es una variante opcional.

---

## Anexo A — Auditoría del ledger de enero (real)

Fuente: `lm_robot_mt4_original_202401_10k.htm` (FBS-Demo, build 1492, AUDCAD H1, 2024.01.02–2024.02.01).

### A.1 Totales del reporte

| Métrica | Valor |
|---|---:|
| Depósito inicial | 10.000,00 USD |
| Net profit | **+732,27 USD** |
| Retorno | +7,32 % |
| Gross profit | 936,06 USD |
| Gross loss | −203,79 USD |
| Profit factor | 4,59 |
| Expected payoff | 3,47 USD |
| DD absoluto | 27,07 USD |
| DD máximo (balance) | 260,40 USD (2,46 %) |
| Trades | 211 |
| Cortos / largos | 160 (78,12 % ganados) / 51 (72,55 %) |
| Tickets ganadores | 162 (76,78 %) |
| Tickets perdedores | 49 (23,22 %) |
| Mayor ganancia / pérdida | 28,32 / −9,91 |
| Media ganancia / pérdida | 5,78 / −4,16 |
| Barras / ticks | 1.530 / 14.228 |
| Calidad de modelado | n/a (Control points) |
| Spread declarado | Current (17) |

### A.2 Reconstrucción de canastas

El HTML no incluye `magic number`. Se agruparon las 211 operaciones por **timestamp exacto de cierre**: cada grupo es una canasta que se cerró de una vez.

| Métrica | Valor |
|---|---:|
| Aperturas | 211 |
| Cierres | 211 |
| Cierres en `t/p` | 211 |
| Cierres en `s/l` | 0 |
| Lotes abiertos | 13,14 |
| Lotes cerrados | 13,14 |
| Grupos de cierre | 99 |
| Grupos con P&L positivo | 99 |
| Grupos con P&L negativo | 0 |
| P&L mínimo / máximo por grupo | +1,71 / +50,79 |
| P&L medio por grupo | +7,40 |
| Órdenes por grupo (media) | 2,13 |
| Lotes por grupo (media) | 0,133 |
| Grupo máximo | 9 órdenes / 0,90 lotes |

Distribución de órdenes por grupo:

| Órdenes | Grupos |
|---:|---:|
| 1 | 45 |
| 2 | 24 |
| 3 | 19 |
| 4 | 5 |
| 5 | 1 |
| 6 | 3 |
| 9 | 2 |

> Limitación: si dos estrategias cerraron en el mismo segundo, sus canastas se fusionan. No es posible descartarlo al 100 % sin el `magic number`.

### A.3 Los 49 tickets perdedores

Los 49 tickets con pérdida **no son canastas perdedoras**. Son órdenes profundas de la grilla que se cerraron al TP de la canasta, calculado sobre el precio medio ponderado. El precio de entrada de esas órdenes era peor que el promedio, así que su P&L individual es negativo aunque la canasta en conjunto gane.

- Suma de los 49 tickets perdedores: −203,79 USD.
- Suma de los 162 ganadores: +936,06 USD.
- Neto: +732,27 USD.

Esto es exactamente lo que la identidad de §7 describe: el resultado se decide a nivel de canasta y de volumen, no de ticket.

### A.4 Hallazgos del código del original

| Hallazgo | Evidencia | Efecto |
|---|---|---|
| El SL nunca se envía | `OrderSend(..., 0, 0, ...)` en líneas 1561, 1571, 1699, 1713, 1843, 1853 | Ninguna operación puede cerrar por stop |
| El TP se re-ancla al promedio | `OrderModify` con `TakeProfitPrice_*` calculado sobre `AveragePrice_*` | Explica los 49 tickets perdedores dentro de canastas ganadoras |
| Lotaje con `Risk/1000` | Línea 1991: `(Risk/1000*balance)/effectiveStopLoss` | 0,05 lotes base con 10.000 USD y `Risk=1` |
| `GeneralStopLoss=200` solo entra en el lotaje | Línea 1962–1968 | No es un stop real; es el denominador del lote |
| `StopLossPips_* = 40.0` | Líneas 56, 89, 123 | El SL calculado sería 40 points = 4 pips, y no se envía |
| Filtro ATR casi inerte | `atr/Point` contra `MaxAllowedATR=150` | Bloquea solo con ATR > 15 pips en un feed de 5 decimales |
| `UseNewsFilter` muerto | Declarado en línea 49, nunca leído | No hay filtro de noticias |
| Reintentos de `OrderModify` sin tope | Bucles `while (!OrderModify(...))` | Requiere el parche para terminar el backtest |

### A.5 Reconciliación

```
Σ P&L cierres           = 936,06 − 203,79 = 732,27
Net del reporte         = 732,27
Diferencia              = 0,00
```

```
Aperturas 211 = cierres 211  →  posiciones abiertas al 01-02 = 0
Lotes abiertos 13,14 = lotes cerrados 13,14
```

---

## Anexo B — Configuraciones exactas

Formato `.set` de MT5 (el mismo que genera “Save” en la pestaña Inputs). El campo `Strategy` se ajusta a 0, 1 o 2 según la corrida.

### B.1 C0 — defaults del código

```ini
Strategy=0||0||0||2||N
MagicNumber=20261103||20261103||1||202611030||N
MaxAttempts=3||3||1||30||N
RetryDelayMs=250||250||1||2500||N
DeadlineMs=3000||3000||1||30000||N
AtrTimeframe=0||0||0||49153||N
AtrPeriod=14||14||1||140||N
MaxSpreadPips=3.0||3.0||0.3||30.0||N
MaxAtrPips=30.0||30.0||3.0||300.0||N
RiskPct=0.5||0.5||0.05||5.0||N
MaxBasketLossPct=2.0||2.0||0.2||20.0||N
DailyLossLimitPct=4.0||4.0||0.4||40.0||N
MaxGridSteps=4||4||1||40||N
LotMultiplier=1.5||1.5||0.15||15.0||N
MaxLotPerOrder=0.10||0.1||0.01||1.0||N
MaxVolumePerStrategy=0.30||0.3||0.03||3.0||N
SlPips=40.0||40.0||4.0||400.0||N
TpPips=8.0||8.0||0.8||80.0||N
GridStepPips=22.0||22.0||2.2||220.0||N
UseSessionFilter=false||false||0||true||N
SessionStartHour=8||8||1||80||N
SessionEndHour=17||17||1||170||N
```

### B.2 C1 — paridad de tamaño con stop real

```ini
Strategy=0||0||0||2||N
MagicNumber=20261103||20261103||1||202611030||N
MaxAttempts=3||3||1||30||N
RetryDelayMs=250||250||1||2500||N
DeadlineMs=3000||3000||1||30000||N
AtrTimeframe=0||0||0||49153||N
AtrPeriod=14||14||1||140||N
MaxSpreadPips=100.0||100.0||1.0||1000.0||N
MaxAtrPips=100.0||100.0||1.0||1000.0||N
RiskPct=0.745||0.745||0.05||5.0||N
MaxBasketLossPct=1000.0||1000.0||1.0||1000.0||N
DailyLossLimitPct=1000.0||1000.0||1.0||1000.0||N
MaxGridSteps=20||20||1||40||N
LotMultiplier=1.667||1.667||0.1||10.0||N
MaxLotPerOrder=9.0||9.0||0.01||100.0||N
MaxVolumePerStrategy=9.0||9.0||0.01||100.0||N
SlPips=200.0||200.0||4.0||400.0||N
TpPips=8.0||8.0||0.8||80.0||N
GridStepPips=22.0||22.0||2.2||220.0||N
UseSessionFilter=false||false||0||true||N
SessionStartHour=8||8||1||80||N
SessionEndHour=17||17||1||170||N
```

### B.3 C2 — continuidad con la evidencia existente

```ini
Strategy=0||0||0||2||N
MagicNumber=20261103||20261103||1||202611030||N
MaxAttempts=3||3||1||30||N
RetryDelayMs=250||250||1||2500||N
DeadlineMs=3000||3000||1||30000||N
AtrTimeframe=0||0||0||49153||N
AtrPeriod=14||14||1||140||N
MaxSpreadPips=10.0||10.0||0.3||30.0||N
MaxAtrPips=100.0||100.0||3.0||300.0||N
RiskPct=0.5||0.5||0.05||5.0||N
MaxBasketLossPct=2.0||2.0||0.2||20.0||N
DailyLossLimitPct=4.0||4.0||0.4||40.0||N
MaxGridSteps=4||4||1||40||N
LotMultiplier=1.5||1.5||0.15||15.0||N
MaxLotPerOrder=0.10||0.1||0.01||1.0||N
MaxVolumePerStrategy=0.30||0.3||0.03||3.0||N
SlPips=60.0||60.0||4.0||400.0||N
TpPips=20.0||20.0||0.8||80.0||N
GridStepPips=5.0||5.0||1.0||100.0||N
UseSessionFilter=false||false||0||true||N
SessionStartHour=8||8||1||80||N
SessionEndHour=17||17||1||170||N
```

### B.4 Derivación del `RiskPct` de C1

```
pipValuePerLot(AUDCAD) ≈ 7,44 USD/pip/lote
baseLot objetivo       = 0,05
SlPips                 = 200

riesgo por orden = 0,05 × 200 × 7,44 = 74,40 USD
RiskPct          = 74,40 / 10.000 × 100 = 0,744 %
```

0,745 es el valor nominal calculado con `pipValuePerLot = 7,44`. El lote queda en el borde del redondeo: con `pipValuePerLot > 7,45` el cálculo da 0,0499 y el `floor` lo deja en 0,04. Verificar en R05 que el primer lote sea 0,05; si sale 0,04, subir `RiskPct` a 0,76–0,80 y documentarlo.

### B.5 Variante opcional C1b (fuera de la matriz aprobada)

Lectura alternativa de `GeneralStopLoss=200` como 200 points = 20 pips:

```
SlPips      = 20
RiskPct     = 0,05 × 20 × 7,44 / 10.000 × 100 = 0,0744 %
f*          = 8 / (8 + 20) = 28,6 %
```

Es una configuración mucho más exigente que C1 y probablemente detenga una fracción de volumen muy superior al 28,6 % en un semestre. Se propone solo si se quiere medir la sensibilidad al ancho del stop.
