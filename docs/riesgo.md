# Modelo de riesgo

Este documento describe cómo `RiskPolicy` calcula el volumen, acota la
exposición de la canasta y decide si una apertura está permitida. La gestión de
posiciones abiertas (stop loss, take profit, trailing, reducción o cierre) queda
fuera de estos guards y se ejecuta siempre.

## Parámetros

Los valores iniciales son el punto de partida para el primer backtest; se
calibran con los resultados, no son compromisos de producto.

| Parámetro | Valor inicial | Uso |
|---|---:|---|
| `RiskMode` | `Auto` | Modalidad inicial del riesgo vivo: `Auto` o `Manual`. El panel permite alternarla en caliente. |
| `AutoRiskMaxPct` | 6.0% | Tope máximo del riesgo automático. Rango válido 0.5–10.0; fuera de él el EA no inicia. |
| `RiskPct` | 0.5% | Riesgo base: en `Manual` es el riesgo vivo inicial y ajustable; en `Auto` es la base del cálculo por volatilidad. |
| `MaxBasketLossPct` | 2% | Pérdida máxima proyectada de toda la canasta al stop loss. |
| `DailyLossLimitPct` | 4% | Caída máxima de equidad respecto del inicio del día del servidor. |
| `MaxGridSteps` | 4 | Cantidad máxima de pasos de grid además de la orden inicial. |
| `LotMultiplier` | 1.5 | Multiplicador de volumen entre pasos consecutivos. |
| `MaxLotPerOrder` | 0.10 | Volumen máximo de una sola orden. |
| `MaxVolumePerStrategy` | 0.30 | Volumen máximo acumulado de la canasta. |
| `SL_pips` | 40 | Piso del stop loss de canasta, en pips. |
| `TP_pips` | 8 | Distancia del take profit de canasta, en pips. |
| `GridStepPips` | 22 | Distancia desde la última orden para habilitar el siguiente paso. |
| `MaxSpreadPips` | 3 | Spread máximo para permitir aperturas. |
| `AtrSlMultiplier` | 1.667 | Multiplicador del ATR para ampliar el stop loss. |
| `AtrLookback` | 50 | Barras usadas para la media histórica del ATR. |
| `VolFactorMin` | 0.3 | Piso del factor de volatilidad sobre el lote. |
| `VolFactorMax` | 2.0 | Techo del factor de volatilidad sobre el lote. |

Los topes de pérdida y de volumen se comparan contra el `balance`, no contra la
equidad, para que un drawdown flotante no habilite más riesgo. El límite diario
es la excepción: compara equidad actual contra equidad de inicio del día.

## Riesgo vivo

El riesgo usado para dimensionar (`RuntimeConfig.risk.riskPct`) es un valor vivo
propiedad del runtime. Su fuente depende de la modalidad:

- **`Auto` (por defecto)**. En cada tick se calcula desde la base y la
  volatilidad relativa:
  `riesgo = clamp(base * clamp(ATR_medio / ATR_actual, VolFactorMin, VolFactorMax), 0.5, AutoRiskMaxPct)`,
  redondeado a dos decimales. La base es el input `RiskPct` al iniciar o el riesgo
  vivo capturado al pasar de `Manual` a `Auto`; mientras permanece en `Auto` no se
  recompone con los resultados sucesivos. Sin lectura válida de ATR el factor es
  `1.0` y el riesgo queda en la base acotada. El mínimo sigue fijo en 0.5 y el tope
  superior es `AutoRiskMaxPct`.
- **`Manual`**. Arranca en el input `RiskPct` y **no se recorta** al iniciar. Un
  valor fuera de `0.5–10`, por ejemplo `0.08`, se usa tal cual para dimensionar y
  solo deja los botones de ajuste deshabilitados.
- Los botones `+`/`-` del panel solo actúan en `Manual`: suben o bajan el riesgo en
  pasos fijos de **0.5** puntos porcentuales, dentro del rango **0.5–10**. En el
  mínimo o en el máximo, el botón correspondiente no responde. En `Auto` ambos
  botones quedan atenuados e ignoran el clic.
- El botón de modo alterna `Manual`/`Auto` en caliente. `Manual → Auto` captura el
  riesgo vivo como base; `Auto → Manual` conserva el último valor automático y los
  botones parten de él. Alternar repetidamente no acumula volatilidad.
- Se usa en la apertura de canastas nuevas y en el próximo paso de grid y los
  siguientes de una canasta abierta.
- No redimensiona las posiciones ya abiertas ni cambia su stop loss o take profit.
- Subir el riesgo a mitad de canasta puede hacer que `MaxBasketLossPct` rechace el
  próximo paso: el guard no reduce el volumen, simplemente no permite el paso.
- No hay persistencia por cuenta ni por magic: al reiniciar el EA o el terminal, la
  modalidad vuelve al input `RiskMode` y el riesgo al valor del input `RiskPct`
  (acotado por `AutoRiskMaxPct` si arranca en `Auto`).

## Fórmulas

### Pip y valor del pip

```
pip_size            = 10 * point   si digits es 3 o 5
                    = point        si digits es 2 o 4
valor_pip_por_lote  = tick_value / (tick_size / pip_size)
```

Estas conversiones viven en `Include/LmRobot/Core/Instrument.mqh`.

### Stop loss proporcional al ATR

`SL_pips` actúa como piso. Cuando hay lectura válida de ATR, la distancia se
amplía proporcionalmente a la volatilidad:

```
SL_efectivo = max(SL_pips, ATR_pips * AtrSlMultiplier)
```

El ATR se lee de la última barra cerrada y se expresa en pips. Esta misma
distancia se usa para dimensionar el lote, para proyectar la pérdida y como stop
loss real de la canasta: si el ATR sube, el lote baja y el stop se aleja, de modo
que el riesgo monetario se mantiene cercano al configurado.

### Factor de volatilidad

Además del stop por ATR, el lote se ajusta contra la volatilidad media de las
últimas `AtrLookback` barras:

```
factor_volatilidad = clamp(ATR_medio / ATR_actual, VolFactorMin, VolFactorMax)
```

Con volatilidad igual a la media no hay ajuste (`1.0`). Si la volatilidad actual
supera la media el lote se reduce, y si está por debajo se aumenta, siempre dentro
de los topes configurados.

En modo `Manual` este factor se aplica al lote. En modo `Auto` el riesgo vivo ya
incorpora la volatilidad relativa, así que el lote **no vuelve a aplicar** el
factor: se usa `factor_volatilidad = 1.0` para no duplicar el efecto. El stop
efectivo sí sigue derivándose del ATR en ambas modalidades.

### Lote inicial

```
riesgo_vivo = RiskPct en manual, ajustado por los botones +/-
              o base * factor_volatilidad en automatico, acotado a 0.5-AutoRiskMaxPct

lote_inicial = (riesgo_vivo / 100 * balance) / (SL_efectivo * valor_pip_por_lote)
               * factor_volatilidad
```

El resultado se redondea **hacia abajo** al `volume_step` del broker y se acota
entre `volume_min` y `volume_max`. Si el lote calculado queda debajo del mínimo,
se usa el mínimo; si ese mínimo implica superar `MaxBasketLossPct`, la apertura se
rechaza.

Ejemplo de la especificación:

```
balance = 10.000
RiskPct = 0.5%
SL_pips = 40
valor_pip_por_lote = 10

lote = (0.005 * 10.000) / (40 * 10) = 50 / 400 = 0.125
lote normalizado al step 0.01 = 0.12
```

El lote por fórmula es 0.12. Si `MaxLotPerOrder` es 0.10, el tope por orden se
aplica después y la orden efectiva sale con 0.10: la fórmula calcula el riesgo
deseado y los caps son una segunda barrera.

### Lote de un paso de grid

```
lote_paso_n = lote_inicial * LotMultiplier^n
```

`n` es el número de paso de grid; el paso 0 corresponde a la orden inicial.

### Pérdida proyectada y presupuesto

```
perdida_proyectada = (volumen_actual_canasta + lote_nuevo) * SL_efectivo * valor_pip_por_lote
presupuesto        = balance * MaxBasketLossPct / 100
```

Antes de enviar cualquier orden se exige:

```
perdida_proyectada <= presupuesto
```

Si no se cumple, el paso se rechaza y la canasta conserva las posiciones que ya
tenía. Un plan rechazado devuelve volumen cero para que el ejecutor no tenga nada
que enviar.

### Topes independientes

Se aplican tres topes, cada uno por separado:

```
volumen_orden   = min(volumen_calculado, MaxLotPerOrder)
volumen_canasta = min(volumen_solicitado, MaxVolumePerStrategy - volumen_actual)
pasos           = currentSteps < MaxGridSteps
```

Un tope alcanzado bloquea únicamente aperturas nuevas; no impide modificar el
stop loss, mover el take profit, reducir o cerrar posiciones existentes.

### Límite diario

```
caida_pct = (equidad_inicio_dia - equidad_actual) / equidad_inicio_dia * 100
bloqueado = caida_pct >= DailyLossLimitPct
```

La equidad de inicio se registra en el primer tick del día del servidor y se
persiste por cuenta y día. Una vez que la caída alcanza el límite, el bloqueo se
guarda como bandera y se mantiene hasta el inicio del día siguiente, aunque la
equidad se recupere durante la misma jornada.

Persistencia en producción:

- Store: `CGlobalVariableDailyStore` sobre variables globales del terminal.
- Clave de equidad inicial: `LM_DAILY_START_<cuenta>_<YYYYMMDD>`.
- Clave de bloqueo: `LM_DAILY_BLOCKED_<cuenta>_<YYYYMMDD>`.

Las variables globales sobreviven a un reinicio del terminal. Al cambiar el día
del servidor se usa un par de claves nuevo, con lo que el bloqueo anterior deja de
aplicarse y se registra una nueva equidad de inicio.

## Prioridad de la gestión

En cada tick el orden es:

1. Gestionar la canasta abierta: stop loss, take profit, trailing, reducción o
   cierre.
2. Evaluar guards de entrada: límite diario, spread, volatilidad y sesión.
3. Solo si todos los guards están libres, evaluar la señal y planificar una
   apertura.

`LmCanManagePositions()` devuelve siempre `true`; `LmCanOpenNew()` es la única
función que consulta los guards. Por eso, con el límite diario activo, un cierre
por stop loss se ejecuta igual y solo se bloquean canastas nuevas.

## Resumen de decisiones

| Situación | Resultado |
|---|---|
| Pérdida proyectada dentro del presupuesto | Se permite el paso con el volumen calculado. |
| Pérdida proyectada por encima del presupuesto | Se rechaza el paso y se registra el motivo. |
| Volumen por encima de `MaxLotPerOrder` | Se recorta al tope y se reevalúa el presupuesto. |
| Canasta en `MaxVolumePerStrategy` | Se rechaza cualquier paso nuevo. |
| `MaxGridSteps` alcanzado | No se habilitan pasos nuevos. |
| Caída diaria en `DailyLossLimitPct` | Se bloquean aperturas hasta el día siguiente. |
| Guard activo y canasta abierta | La gestión continúa sin cambios. |

## Verificación

Las pruebas de `tests/TestRunner.mq5` cubren:

- lote inicial 10.000 / 0.5% / 40 pips / 10 por pip = 0.12 y clamp al broker;
- riesgo vivo ajustable en pasos de 0.5, con límites 0.5–10 y sin recorte del input;
- modalidad `Auto` por defecto, tope `AutoRiskMaxPct` (6.0 por defecto, rango
  0.5–10.0) y cálculo por volatilidad redondeado a dos decimales;
- conmutación `Manual`/`Auto` en caliente con continuidad de la base y del último
  valor automático;
- en `Auto` el lote no repite el factor de volatilidad;
- la apertura y el próximo paso de grid usan el riesgo vigente sin tocar lo abierto;
- SL derivado del ATR con piso en `SL_pips` y factor de volatilidad acotado;
- lote proporcional al balance, al riesgo y al factor de volatilidad;
- rechazo de un paso que excede el 2% del balance, usando el SL efectivo;
- cada tope de volumen y de pasos de forma independiente;
- persistencia del límite diario tras un reinicio simulado y reinicio en un nuevo
  día del servidor;
- prioridad de la gestión sobre las aperturas con el límite diario activo.
