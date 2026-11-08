# Cómo ejecutar el test de MT4 y configuración guardada

## Resumen

En esta máquina, `terminal.exe /config:<archivo.ini>` **no procesa el archivo**:
el terminal abre la GUI, se conecta a FBS-Demo y se queda idle. El journal no
registra la línea `Started with configuration file`, ni siquiera usando el
mismo `.ini` que sí funcionó el 2026-11-05. Por eso la vía fiable es la GUI
del Strategy Tester.

La configuración de entradas ya está guardada y es reutilizable. Solo hay que
cargarla y pulsar Start.

## Archivos creados

| Archivo | Ruta | Uso |
|---|---|---|
| Set de entradas | `...\Terminal\9D15457EC01AD10E06A932AAC616DC32\MQL4\Presets\CodigoOriginalMT4_2024H1.set` | Cargar en Inputs → Load |
| Config R01 (6 meses) | `...\Terminal\9D15457EC01AD10E06A932AAC616DC32\run_r01_6m.ini` | Referencia / intento headless |
| Config R00 (control enero) | `...\Terminal\9D15457EC01AD10E06A932AAC616DC32\run_r00_control.ini` | Referencia / intento headless |
| Copia versionada | `reportes\sets\mt4\` (en este repo) | Respaldo |

El `.set` reproduce **exactamente** los inputs de la corrida de enero
(`tester\CodigoOriginalMT4_Test.ini`).

## Procedimiento manual (R01, 6 meses)

1. Abrir `C:\Program Files (x86)\FBS Trader 4\terminal.exe`.
2. `Ctrl+R` para abrir el Strategy Tester.
3. Configurar:

   | Campo | Valor |
   |---|---|
   | Expert | `lm_robot\CodigoOriginalMT4_Test` |
   | Symbol | `AUDCAD` |
   | Period | `H1` |
   | Model | `Control points` |
   | Use date | activado |
   | From | `2024.01.01` |
   | To | `2024.07.01` |
   | Deposit | `10000` |
   | Currency | `USD` |
   | Leverage | `1:100` |
   | Visual mode | desactivado |

4. Botón `Expert properties` → pestaña `Inputs` → `Load` →
   `CodigoOriginalMT4_2024H1.set`.
5. Verificar que los inputs cargaron (tabla de abajo) y aceptar.
6. `Start`. La corrida de 6 meses tarda unos minutos.
7. Al terminar: clic derecho sobre el reporte → `Save as Report` (o `Guardar
   como informe`) → guardar como:

   ```
   C:\Users\palob\AppData\Roaming\MetaQuotes\Terminal\9D15457EC01AD10E06A932AAC616DC32\lm_robot_mt4_original_2024H1_10k.htm
   ```

## Procedimiento para R00 (control de enero)

Mismos pasos, cambiando solo:

| Campo | Valor |
|---|---|
| From | `2024.01.01` |
| To | `2024.02.01` |
| Reporte | `lm_robot_mt4_original_202401_control.htm` |

R00 debe dar **+732,27 USD** (el valor del ledger de enero). Si no coincide,
no interpretar R01 hasta explicar la diferencia (spread, datos o build).

## Inputs guardados (idénticos a enero)

| Input | Valor | Nota |
|---|---:|---|
| `GeneralStopLoss` | 200 | Solo denominador del lotaje; **no se envía como SL** |
| `Lots` | 0,01 | Lote base |
| `LotExponent` | 1,667 | Multiplicador de grilla |
| `lotdecimal` | 5 | |
| `PipStep` | 220 | 22 pips |
| `MaxLots` | 9,0 | |
| `MM` | 1 | Money management activo |
| `Risk` | 1,0 | `Risk/1000 × balance / 200` → 0,05 lotes con 10k |
| `TakeProfit` | 80 | 8 pips |
| `UseEquityStop` | 0 | |
| `TotalEquityRisk` | 20 | |
| `UseTrailingStop` | 0 | |
| `TrailStart` / `TrailStop` | 13 / 3 | |
| `slip` | 3 | |
| `MaxAllowedATR` | 150 | |
| `ATR_Period` | 14 | |
| `ATR_Timeframe` | 60 | H1 |
| `MaxTrades_Hilo` | 20 | Fibonacci |
| `MagicNumber_Hilo` | 10278 | |
| `MaxTrades_15` | 20 | Scalper |
| `g_magic_176_15` | 22324 | |
| `MaxTrades_16` | 20 | TrendMaster |
| `g_magic_176_16` | 23794 | |
| `UseNewsFilter` | 1 | Código muerto: no filtra nada |

## Qué verificar en el reporte

1. Período exacto `2024.01.01–2024.07.01`.
2. `Total Net Profit` = suma de la columna de P&L de los cierres.
3. `Total Trades` = número de cierres.
4. Columna `S/L` en `0.00000` y ningún cierre con motivo `s/l`.
5. Aperturas = cierres (si quedan posiciones abiertas al corte, el reporte las
   cierra al final; anotar el volumen).
6. Spread declarado en el encabezado (`Current (17)` en enero).

## Por qué no se usa `/config` en esta máquina

Evidencia recogida el 2026-11-06:

- El journal solo muestra `FBS Trader build 1492 started` y `Data Folder: ...`.
- Nunca aparece `Started with configuration file '...'`.
- Se probaron: ruta absoluta, ruta relativa, con y sin comillas, vía `cmd /c
  start`, directorio de trabajo en datos y en instalación, `.ini` en ASCII,
  UTF-8 y UTF-16LE, y una copia byte a byte del `.ini` que funcionó el 05-11.
- El proceso queda con CPU ~4 % y sin reporte.
- La instalación está en `C:\Program Files (x86)` y la sesión **no** es
  elevada, así que tampoco se puede escribir un `.ini` dentro de la instalación.

Conclusión: usar la GUI. El `.ini` se conserva por si una actualización del
terminal restaura el soporte de `/config`.
