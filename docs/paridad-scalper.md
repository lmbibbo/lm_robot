# Paridad de señales: Scalper Pro

## Corrida de referencia

| Dato | Valor |
|---|---|
| Símbolo | AUDCAD |
| Timeframe | H1 |
| Período | 2026-01-01 00:00 a 2026-06-30 23:59 (hora del servidor) |
| Barras leídas | 3.069 |
| Filas exportadas | 3.068 |
| Referencia | `lm_robot_reference_scalper_AUDCAD_H1.csv` |
| Copia versionada | `tests/reference/lm_robot_reference_scalper_AUDCAD_H1.csv` |
| Motor nuevo | `lm_robot_engine_scalper_AUDCAD_H1.csv` |

La primera barra del rango no se evalúa porque no tiene un cierre anterior contra
el cual comparar. Por eso hay una fila por cada barra cerrada evaluada:
`3.069 barras - 1 = 3.068 filas`.

Primeras filas del CSV:

```csv
time,strategy,direction,timeframe
2026.01.02 01:00:00,Scalper,SELL,H1
2026.01.02 02:00:00,Scalper,SELL,H1
2026.01.02 03:00:00,Scalper,SELL,H1
```

Últimas filas:

```csv
2026.06.30 22:00:00,Scalper,BUY,H1
2026.06.30 23:00:00,Scalper,SELL,H1
```

## Resultado del comparador

| Métrica | Valor |
|---|---:|
| Coincidencias | 3.068 |
| Faltantes | 0 |
| Sobrantes | 0 |
| Direcciones diferentes | 0 |
| Paridad | **Sí** |

Los dos CSV son idénticos línea por línea. El reporte generado por
`tests/ParityCompare.mq5` queda en `MQL5/Files/lm_robot_parity_scalper.md`.

## Diferencias esperadas por el gate de barra

La referencia MT4 tiene un retorno temprano en `CodigoOriginalMT4.mq4`:

```mql4
if (LastBarTime_Hilo == Time[0])
   return (0);
```

Ese retorno hace que Scalper Pro y TrendMaster solo se ejecuten en el primer tick
de cada barra del gráfico. En el motor nuevo el gate es explícito: la señal se
evalúa una sola vez por barra cerrada, usando `close[1]` y `close[2]`.

El port de referencia `tests/ReferenceScalperExport.mq5` modela exactamente esa
cadencia: una evaluación por barra cerrada. Por eso, en la corrida H1:

| Categoría | Esperado | Observado | Explicación |
|---|---:|---:|---|
| Faltantes | 0 | 0 | Ambas implementaciones evalúan todas las barras cerradas del período. |
| Sobrantes | 0 | 0 | Ninguna de las dos evalúa dos veces la misma barra. |
| Direcciones diferentes | 0 | 0 | Ambas usan `close[2] > close[1] -> SELL`; en caso contrario `BUY`. |

La diferencia que el gate podría introducir aparece cuando el timeframe del
gráfico no coincide con el `Timeframe_Scalper` original (H1). En el MT4, el
bloque de señal se ejecuta por barra del gráfico, pero el disparador separado
`LastBarTime_ScalperTrigger` usa `Timeframe_Scalper`. Esa combinación podía
agregar o duplicar entradas en timeframes distintos de H1. El motor nuevo elimina
`Timeframe_Scalper` y usa el timeframe del gráfico tanto para la señal como para
el gate, que es el comportamiento buscado por el diseño D2.

En esta corrida H1 el gate coincide y el comparador reporta **cero
diferencias**. Cualquier diferencia futura en un período distinto debe revisarse
contra estas tres categorías: faltante, sobrante o dirección diferente.

## Reproducción

El procedimiento completo está en `docs/paridad.md`.
