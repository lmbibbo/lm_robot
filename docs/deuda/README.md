# Registro de deuda técnica

Este directorio guarda decisiones abiertas, hallazgos verificados y trabajo
diferido que condicionan el diseño del motor. No reemplaza a `openspec/`: una
entrada de deuda describe **el problema y la decisión pendiente**; un cambio de
OpenSpec describe **la implementación** una vez que la decisión está tomada.

## Índice

| ID | Título | Estado | Severidad | Decisión que la cierra |
|---|---|---|---|---|
| [DT-001](DT-001-invariancia-timeframe.md) | Invariancia de riesgo y perfil entre timeframes | Abierta | Alta | ¿El perfil se ancla por operación o por tiempo? |

## Convenciones

- **Un archivo por ítem**, nombrado `DT-NNN-titulo-corto.md`. El índice es la
  única lista canónica.
- **Cada afirmación técnica cita código o un experimento reproducible**
  (`archivo:línea`, comando, CSV). Lo que todavía no está verificado se marca
  como *hipótesis*, no como hallazgo.
- **La entrada no se borra al resolverse**: se actualiza el estado y se agrega
  el resultado. El historial queda en git.
- Si el ítem se convierte en trabajo de implementación, se crea un cambio de
  OpenSpec y se enlaza en ambos sentidos. Al archivar el cambio, la entrada pasa
  a `Saldada` con el nombre del cambio.

## Estados

| Estado | Significado |
|---|---|
| `Abierta` | Diagnóstico hecho, decisión sin tomar. |
| `En medición` | Hay un experimento o backtest corriendo para cerrar la decisión. |
| `Decidida` | Hay opción elegida y criterio de aceptación; pendiente de implementar. |
| `Aceptada` | Se decidió no actuar. El registro documenta el riesgo asumido. |
| `Saldada` | El cambio se implementó y archivó; el resultado quedó documentado. |

## Severidad

| Nivel | Criterio |
|---|---|
| Alta | Cambia el modelo de riesgo, la paridad o la viabilidad de operar en más de un TF. |
| Media | Degrada la calidad de ejecución o la comparabilidad de resultados, sin cambiar el riesgo nominal. |
| Baja | Deuda de documentación, herramientas o mantenimiento. |
