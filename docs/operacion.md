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
| `RiskMode` | `Auto` | Modalidad inicial: `Auto` o `Manual`. El panel permite alternarla en caliente. |
| `AutoRiskMaxPct` | `6.0` | Tope máximo del riesgo automático, en porcentaje. Rango válido 0.5–10.0; fuera de él el EA no inicia. |
| `RiskPct` | `0.5` | Riesgo base en porcentaje del balance. En `Manual` es el riesgo vivo inicial y ajustable; en `Auto` es la base del cálculo por volatilidad. Define el lote inicial junto con `SlPips` y el valor del pip. |
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

El panel se dibuja en la esquina superior izquierda del gráfico. Muestra los
siete campos de la canasta y una línea adicional con el riesgo vivo:

| Campo | Interpretación |
|---|---|
| **Estrategia** | Estrategia activa según el input `Strategy`. |
| **Dirección** | `Compra`, `Venta` o `Plana` según la canasta abierta. |
| **Volumen** | Volumen total de la canasta, en lotes. |
| **Promedio** | Precio promedio ponderado por volumen de las posiciones abiertas. El TP y el SL de canasta se calculan desde este valor. |
| **Próximo grid** | Precio al que se habilitaría el siguiente paso: por debajo del promedio en compras, por encima en ventas. Muestra `-` sin canasta. |
| **Presupuesto usado** | Porcentaje del presupuesto `MaxBasketLossPct` consumido por la pérdida proyectada de la canasta al stop loss. `0.0%` sin canasta. |
| **PnL del día** | Diferencia entre la equidad actual y la equidad registrada al inicio del día del servidor. Incluye resultado flotante. |
| **Riesgo** | Riesgo vivo usado para dimensionar, con dos decimales y la modalidad entre paréntesis: `(manual)` o `(auto)`. En `Manual` es el valor de `RiskPct` ajustado con los botones; en `Auto` se recalcula en cada tick desde la base y el ATR, acotado a 0.5–`AutoRiskMaxPct`. |

Debajo de la última línea aparecen tres botones:

- `-` baja el riesgo vivo **0.5** puntos porcentuales y `+` lo sube otros **0.5**.
  Solo actúan en modo `Manual`.
- El rango operable manual es **0.5–10**. En el mínimo, `-` queda atenuado y no
  responde; en el máximo ocurre lo mismo con `+`.
- `Modo: Manual`/`Modo: Auto` alterna la modalidad en caliente. `Manual → Auto`
  captura el riesgo vivo como base del cálculo automático; `Auto → Manual` deja los
  botones partiendo del último valor automático. En `Auto`, `+`/`-` quedan
  atenuados e ignoran el clic.
- El riesgo automático sigue la volatilidad relativa: con ATR actual por encima de
  la media baja, y por debajo sube, sin superar `AutoRiskMaxPct`. Sin ATR válido se
  usa la base acotada.
- Cada clic actualiza el riesgo de inmediato y el panel lo refleja sin reiniciar el
  EA. El cambio se aplica a la próxima orden y a los pasos siguientes de la
  canasta; no redimensiona posiciones abiertas ni modifica su SL o TP.
- Si el input `RiskPct` queda fuera de 0.5–10 en modo `Manual` (por ejemplo `0.08`),
  el panel lo muestra con la leyenda `fuera de 0.5-10: control deshabilitado` y
  ambos botones quedan atenuados. El riesgo no se recorta: se sigue usando para
  dimensionar. La leyenda no aplica en `Auto`.
- El ajuste y la modalidad viven solo en memoria: al reiniciar el EA o el terminal
  se vuelve a `RiskMode` y a `RiskPct`, con el tope `AutoRiskMaxPct` si arranca en
  `Auto`.

El panel es una proyección del estado del motor: no recalcula indicadores ni crea
objetos en cada tick. Un *dirty flag* compara los valores, incluidos el riesgo y la
modalidad, y solo redibuja cuando cambia alguno. Por eso un tick sin cambios no produce
redibujos, y el PnL del día puede actualizarse con más frecuencia que el resto
cuando hay posiciones abiertas.

Al retirar el EA del gráfico, `OnDeinit` elimina todos los objetos del panel y
deja el comentario del gráfico limpio.

## Puesta en marcha

1. Compilar con `powershell -NoProfile -ExecutionPolicy Bypass -File tools\build.ps1`.
2. Adjuntar `LmRobot.ex5` a un gráfico del símbolo y timeframe deseados.
3. Verificar en el log de Expertos el mensaje de inicialización: símbolo,
   estrategia, dígitos, tamaño del pip, valor del pip por lote y modo de cuenta.
4. Confirmar que el panel muestra la canasta, el riesgo vivo, los botones `-`/`+`
   y el botón de modo.
5. Revisar que `MagicNumber` no colisione con otra instancia.

## Verificación

Las pruebas de `tests/TestRunner.mq5` cubren el panel:

- los siete campos de la canasta y la línea de riesgo se construyen y se
  actualizan al cambiar la canasta, la estrategia o el PnL del día;
- el ajuste manual respeta el paso 0.5, los límites 0.5–10 y el input fuera de
  rango sin recortarlo;
- la línea de riesgo muestra `(manual)`/`(auto)` y el botón de modo alterna la
  modalidad;
- en automático los botones `-`/`+` quedan atenuados y no ajustan el riesgo;
- los tres botones se reutilizan entre renders y se atenúan según corresponda;
- diez ticks sin cambios no incrementan el contador de redibujos;
- la limpieza elimina todos los objetos del EA, incluidos los tres botones, y deja
  el comentario vacío.
