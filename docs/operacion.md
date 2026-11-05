# Operación del EA

Este documento explica cómo instalar y operar `EA/LmRobot.mq5`: qué exige de la
cuenta, qué significa cada parámetro de entrada, cómo se aplican los límites y
cómo interpretar el panel de estado.

## Requisitos de la cuenta

- **Cuenta hedging obligatoria.** El motor abre varias posiciones del mismo
  símbolo y las gestiona como una canasta. En una cuenta *netting* esas órdenes
  se netean en una sola posición promedio y el grid deja de existir. `OnInit`
  comprueba `ACCOUNT_MARGIN_MODE` y falla con un mensaje explícito si la cuenta
  no es hedging.
- **Un gráfico por instancia.** Cada instancia opera una sola estrategia sobre el
  símbolo y el timeframe del gráfico. Para operar dos estrategias se abren dos
  gráficos con `MagicNumber` distintos.
- **Símbolo con stops level válido.** El stop loss de canasta se envía al broker;
  si el bróker publica un `SYMBOL_TRADE_STOPS_LEVEL` que impide respetar la
  distancia configurada, la apertura se rechaza y el motivo queda en el log.
- **MetaTrader 5 con MetaEditor 5.** El procedimiento de compilación está en
  [`build.md`](build.md).

## Parámetros de entrada

### Estrategia y ejecución

| Input | Valor inicial | Significado |
|---|---:|---|
| `Strategy` | `Scalper Pro` | Estrategia activa. Solo se evalúa esta señal; las otras dos no abren posiciones ni consumen presupuesto. |
| `MagicNumber` | `20261103` | Identifica la canasta de esta instancia. Debe ser distinto por gráfico y no coincidir con otros expertos. |
| `MaxAttempts` | `3` | Intentos máximos por envío o modificación de orden. |
| `RetryDelayMs` | `250` | Espera entre intentos, en milisegundos. |
| `DeadlineMs` | `3000` | Tiempo máximo total de una operación. Al vencer se abandona el intento y se registra el error, sin bloquear el hilo. |

### Contexto de mercado

| Input | Valor inicial | Significado |
|---|---:|---|
| `AtrTimeframe` | `PERIOD_CURRENT` | Timeframe del ATR. `PERIOD_CURRENT` usa el timeframe del gráfico. |
| `AtrPeriod` | `14` | Período del ATR. |
| `MaxSpreadPips` | `3.0` | Spread máximo para permitir aperturas. Un spread estrictamente mayor bloquea solo entradas nuevas. |
| `MaxAtrPips` | `30.0` | ATR máximo para permitir aperturas. Un ATR estrictamente mayor bloquea solo entradas nuevas. |

El RSI usado por las estrategias tiene período fijo 14 y se lee en el timeframe
del gráfico. No es un input porque las reglas de las tres estrategias lo asumen.

### Riesgo

| Input | Valor inicial | Significado |
|---|---:|---|
| `RiskPct` | `0.5` | Riesgo de la primera orden, en porcentaje del balance. Define el lote inicial junto con `SlPips` y el valor del pip. |
| `MaxBasketLossPct` | `2.0` | Pérdida máxima proyectada de toda la canasta al stop loss, en porcentaje del balance. Es el presupuesto que se compara antes de cada paso. |
| `DailyLossLimitPct` | `4.0` | Caída máxima de equidad respecto del inicio del día del servidor, en porcentaje. Al alcanzarse se bloquean aperturas hasta el día siguiente. |
| `MaxGridSteps` | `4` | Cantidad máxima de pasos de grid además de la orden inicial. |
| `LotMultiplier` | `1.5` | Multiplicador de volumen entre pasos consecutivos. |
| `MaxLotPerOrder` | `0.10` | Volumen máximo de una sola orden. |
| `MaxVolumePerStrategy` | `0.30` | Volumen máximo acumulado de la canasta. |
| `SlPips` | `40.0` | Distancia del stop loss de canasta, en pips, desde el precio promedio ponderado. |
| `TpPips` | `8.0` | Distancia del take profit de canasta, en pips, desde el precio promedio ponderado. |
| `GridStepPips` | `22.0` | Distancia desde la última orden que habilita el siguiente paso de grid, en la dirección que agrava la posición. |

Los topes de pérdida y de volumen se comparan contra el `balance`, no contra la
equidad, para que un drawdown flotante no habilite más riesgo. La excepción es el
límite diario, que compara equidad actual contra equidad de inicio del día. Las
fórmulas completas están en [`riesgo.md`](riesgo.md).

### Sesión

| Input | Valor inicial | Significado |
|---|---:|---|
| `UseSessionFilter` | `false` | Habilita la ventana horaria para aperturas. La gestión de posiciones abiertas nunca se bloquea. |
| `SessionStartHour` | `8` | Hora de inicio de la ventana, en hora del servidor (0-23). |
| `SessionEndHour` | `17` | Hora de fin de la ventana, en hora del servidor (0-24). `24` cierra a medianoche. Si inicio y fin coinciden, la sesión es de 24 horas. |

## Límites y prioridad

En cada tick el orden de trabajo es:

1. **Gestión primero:** stop loss, take profit y modificación de la canasta
   abierta. Ocurre en todos los ticks, incluso si un guard de entrada está activo.
2. **Guards de entrada:** límite diario, spread, volatilidad y sesión.
3. **Señal y apertura:** la señal se evalúa una sola vez por barra cerrada. Si
   todos los guards están libres, se planifica la primera orden o un paso de grid.

Los guards nunca cierran, reducen ni dejan de proteger una canasta abierta. Si el
límite diario está activo y una canasta toca su stop loss, el cierre se ejecuta
igual y solo se bloquean las aperturas nuevas.

Antes de enviar cualquier orden se aplican, en este orden:

- volumen calculado por riesgo, normalizado al paso del bróker;
- tope por orden (`MaxLotPerOrder`);
- tope por canasta (`MaxVolumePerStrategy`);
- tope de pasos (`MaxGridSteps`);
- pérdida proyectada contra `MaxBasketLossPct`;
- stop loss válido, stops level del símbolo y margen libre.

Si cualquiera falla, la orden no se envía, la canasta no se altera y el motivo se
registra en el log de Expertos.

## Panel de estado

El panel se dibuja en la esquina superior izquierda del gráfico. Muestra siete
campos:

| Campo | Interpretación |
|---|---|
| **Estrategia** | Estrategia activa según el input `Strategy`. |
| **Dirección** | `Compra`, `Venta` o `Plana` según la canasta abierta. |
| **Volumen** | Volumen total de la canasta, en lotes. |
| **Promedio** | Precio promedio ponderado por volumen de las posiciones abiertas. El TP y el SL de canasta se calculan desde este valor. |
| **Próximo grid** | Precio al que se habilitaría el siguiente paso: por debajo del promedio en compras, por encima en ventas. Muestra `-` sin canasta. |
| **Presupuesto usado** | Porcentaje del presupuesto `MaxBasketLossPct` consumido por la pérdida proyectada de la canasta al stop loss. `0.0%` sin canasta. |
| **PnL del día** | Diferencia entre la equidad actual y la equidad registrada al inicio del día del servidor. Incluye resultado flotante. |

El panel es una proyección del estado del motor: no recalcula indicadores ni crea
objetos en cada tick. Un *dirty flag* compara los siete valores y solo redibuja
cuando cambia alguno. Por eso un tick sin cambios no produce redibujos, y el PnL
del día puede actualizarse con más frecuencia que el resto cuando hay posiciones
abiertas.

Al retirar el EA del gráfico, `OnDeinit` elimina todos los objetos del panel y
deja el comentario del gráfico limpio.

## Puesta en marcha

1. Compilar con `powershell -NoProfile -ExecutionPolicy Bypass -File tools\build.ps1`.
2. Adjuntar `LmRobot.ex5` a un gráfico del símbolo y timeframe deseados.
3. Verificar en el log de Expertos el mensaje de inicialización: símbolo,
   estrategia, dígitos, tamaño del pip, valor del pip por lote y modo de cuenta.
4. Confirmar que el panel muestra los siete campos.
5. Revisar que `MagicNumber` no colisione con otra instancia.

## Verificación

Las pruebas de `tests/TestRunner.mq5` cubren el panel:

- los siete campos se construyen y se actualizan al cambiar la canasta, la
  estrategia o el PnL del día;
- diez ticks sin cambios no incrementan el contador de redibujos;
- la limpieza elimina todos los objetos del EA y deja el comentario vacío.
