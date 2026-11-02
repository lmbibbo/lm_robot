# Procedimiento de paridad de señales

Este documento permite reproducir el CSV de referencia de Scalper Pro y
compararlo contra el motor nuevo. La corrida de referencia actual está resumida
en `docs/paridad-scalper.md`.

## Artefactos

| Archivo | Función |
|---|---|
| `tests/ReferenceScalperExport.mq5` | Port "solo señales" de la regla MT4. No calcula riesgo ni ejecuta órdenes. |
| `tests/EngineScalperExport.mq5` | Exporta la señal del motor nuevo usando `LmScalperSignal`. |
| `tests/ParityCompare.mq5` | Compara ambos CSV y escribe el reporte. |
| `Include/LmRobot/Harness/SignalCsv.mqh` | Escritor, lector y comparador CSV. |
| `Include/LmRobot/Strategies/Scalper.mqh` | Señal pura `close[2] > close[1] -> SELL`. |
| `tests/reference/lm_robot_reference_scalper_AUDCAD_H1.csv` | Copia versionada del CSV de referencia de la corrida actual. |

## Corrida de referencia

La corrida versionada usa:

```
Símbolo:    AUDCAD
Timeframe:  H1
Desde:      2026.01.01 00:00:00
Hasta:      2026.06.30 23:59:59
```

Los valores están en los inputs por defecto de los dos EAs de exportación. Para
cambiar el período, editar `StartDate`, `EndDate` y `OutputFile` en el fuente y
volver a compilar. El horario es el del servidor, tal como lo entrega
`CopyRates`.

## 1. Compilar

Desde la raíz del repositorio:

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build.ps1 -Source tests\ReferenceScalperExport.mq5
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build.ps1 -Source tests\EngineScalperExport.mq5
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build.ps1 -Source tests\ParityCompare.mq5
```

Los tres comandos deben terminar con `0 error(es), 0 warning(s)`.

## 2. Verificar el historial

El terminal debe tener historial de AUDCAD H1 para el período. Si es la primera
vez, abrir AUDCAD en H1 y desplazar el gráfico hasta el inicio del período, o
dejar que el terminal descargue el historial con conexión. Después se puede
ejecutar en modo offline.

## 3. Exportar la referencia

Crear un archivo `lm_robot-ref-export.ini`:

```ini
[StartUp]
Symbol=AUDCAD
Period=H1
Expert=lm_robot\tests\ReferenceScalperExport
ShutdownTerminal=1
```

Cerrar cualquier terminal abierto y ejecutar:

```powershell
Get-Process terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force
& 'C:\Program Files\FBS MetaTrader 5\terminal64.exe' /offline /config:'C:\ruta\a\lm_robot-ref-export.ini'
```

En el log de Expertos debe aparecer:

```
REFERENCE_EXPORT OK bars=3069 rows=3068 first=2026.01.02 01:00:00 last=2026.06.30 23:00:00 file=lm_robot_reference_scalper_AUDCAD_H1.csv timeframe=H1
```

El CSV queda en:

```
<datos-del-terminal>\MQL5\Files\lm_robot_reference_scalper_AUDCAD_H1.csv
```

Verificación: `rows` debe ser `bars - 1`. La primera barra del rango no se
evalúa porque no tiene cierre anterior.

La corrida versionada también deja una copia del CSV en
`tests/reference/lm_robot_reference_scalper_AUDCAD_H1.csv`. Es un artefacto de
auditoría; para comparar contra el motor nuevo se puede regenerar con el paso 3
o copiar esa copia a `MQL5/Files`.

## 4. Exportar el motor nuevo

Crear `lm_robot-engine-export.ini`:

```ini
[StartUp]
Symbol=AUDCAD
Period=H1
Expert=lm_robot\tests\EngineScalperExport
ShutdownTerminal=1
```

Ejecutar:

```powershell
Get-Process terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force
& 'C:\Program Files\FBS MetaTrader 5\terminal64.exe' /offline /config:'C:\ruta\a\lm_robot-engine-export.ini'
```

En el log debe aparecer:

```
ENGINE_EXPORT OK bars=3069 rows=3068 first=2026.01.02 01:00:00 last=2026.06.30 23:00:00 file=lm_robot_engine_scalper_AUDCAD_H1.csv timeframe=H1
```

El CSV queda en:

```
<datos-del-terminal>\MQL5\Files\lm_robot_engine_scalper_AUDCAD_H1.csv
```

## 5. Comparar

Crear `lm_robot-parity.ini`:

```ini
[StartUp]
Symbol=AUDCAD
Period=H1
Expert=lm_robot\tests\ParityCompare
ShutdownTerminal=1
```

Ejecutar:

```powershell
Get-Process terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force
& 'C:\Program Files\FBS MetaTrader 5\terminal64.exe' /offline /config:'C:\ruta\a\lm_robot-parity.ini'
```

En el log debe aparecer:

```
PARITY OK ref=3068 actual=3068 matches=3068 missing=0 extra=0 mismatched=0 parity=SI report=lm_robot_parity_scalper.md
```

El reporte queda en:

```
<datos-del-terminal>\MQL5\Files\lm_robot_parity_scalper.md
```

## 6. Interpretar el reporte

El comparador informa:

- **Coincidencias:** misma fecha y misma dirección en ambos archivos.
- **Faltantes:** fecha presente en la referencia y ausente en el motor nuevo.
- **Sobrantes:** fecha presente en el motor nuevo y ausente en la referencia.
- **Direcciones diferentes:** misma fecha, dirección distinta.
- **Paridad:** `SÍ` solo si faltantes, sobrantes y direcciones diferentes son
  cero.

La corrida versionada da `3068` coincidencias y cero diferencias. La explicación
del gate de barra y de las diferencias esperadas en otros timeframes está en
`docs/paridad-scalper.md`.

## 7. Pruebas del comparador

`tests/TestRunner.mq5` incluye casos con dos CSV idénticos (cero diferencias) y
con un CSV alterado (una coincidencia, una faltante, una sobrante y una
dirección diferente). También verifica que la exportación conserva las filas
`NONE`.
