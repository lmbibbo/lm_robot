# Design

## Context

Ver `proposal.md` para la motivación. Este documento asume tres hechos del código de referencia:

- `CodigoOriginalMT4.mq4` concentra panel, señales, gestión y riesgo en un `start()` de 1.227 líneas, con tres copias del mismo motor.
- El port parcial `CodigoRefactorizado.mq5` ya resuelve dos cosas que conviene heredar conceptualmente: precio promedio ponderado por volumen y caché de handles de ATR. El resto son stubs.
- El repo no tiene build reproducible ni specs. Este change crea las specs; el código se escribe después.

Restricciones de plataforma: MQL5, `CTrade`, cuenta hedging, `SYMBOL_TRADE_STOPS_LEVEL` variable por broker y por símbolo.

## Goals / Non-Goals

**Goals:**

- Un motor único que sirva a las tres estrategias sin duplicar gestión.
- Señales puras, deterministas y comparables contra la referencia MT4.
- Riesgo acotado en pesos, no solo en lotes.
- Que ningún guard pueda dejar posiciones abiertas sin gestión.
- Un harness que permita afirmar "las señales son las mismas" con evidencia.

**Non-Goals:**

- Implementar Fibonacci real.
- Exposición agregada a nivel de cuenta entre varios gráficos.
- Optimización genética, multi-símbolo y firma del binario.
- Reproducir el panel decorativo de 49 indicadores.

## Decisions

### D1. Pipeline por capas con señales puras

```
OnTick
  |
  v
MarketContext.Refresh()        tick, spread, stops level, ATR, sesion
  |
  v
BasketState.Scan(magic)        conteo, direccion, volumen, promedio, PnL
  |
  +--> Manage(basket)          SL / TP / trailing / cierre   (siempre)
  |
  +--> if (barra nueva && guards OK)
         signal = Strategy.Evaluate(context)
         plan   = RiskPolicy.Plan(basket, signal)
         Executor.Apply(plan)
  |
  v
Dashboard.Render(state)        solo si cambio algo
```

**Por qué:** la señal se puede testear sin broker y comparar contra el MT4; el riesgo queda en un solo lugar auditable.

**Alternativas descartadas:** tres funciones paralelas (reproduce la duplicación actual) y un `OnTick` monolítico (no testeable).

### D2. Una estrategia por gráfico, timeframe del gráfico

El input `Strategy` selecciona una de las tres. La señal usa `_Period`. Se eliminan `Timeframe_Scalper` y `Timeframe_Trend` porque en el original solo gobernaban el trigger de barra nueva mientras la señal leía el gráfico.

**Por qué:** las señales de Scalper y Trend son la misma regla y Fibonacci es un short permanente; ejecutarlas juntas crea canastas opuestas y triplica margen sin diversificar.

**Alternativa descartada:** tres magics simultáneos con veto de dirección. Se puede reevaluar cuando existan señales realmente distintas.

### D3. La canasta es la unidad de estado y de riesgo

`BasketState` agrupa por `symbol + magic` y expone: cantidad, dirección, volumen total, precio promedio ponderado, PnL con swap y comisión, y el precio de la última orden.

**Por qué:** el TP de un grid solo tiene sentido sobre el promedio ponderado; el promedio simple del refactor no garantiza breakeven.

**Alternativas descartadas:** gestión por orden (no protege la canasta) y promedio simple (no representa el costo real).

### D4. Martingala capada por pérdida proyectada

Antes de cada paso:

```
perdida_proyectada = (volumen_actual + lote_nuevo) * SL_pips * valor_pip_por_lote
si perdida_proyectada > MaxBasketLossPct/100 * balance -> rechazar paso
```

Los topes de volumen y de pasos se aplican además, como segunda barrera.

**Por qué:** un tope de lote no acota el riesgo en dinero. Con SL de 40 pips, 0.5 lotes son ~$200; con SL de 400 pips son ~$2.000. El cap tiene que estar en la moneda de la cuenta.

**Consecuencia:** al alcanzar el cap, la martingala deja de serlo y el grid pasa a lote fijo. Es intencional.

**Alternativa descartada:** replicar `MaxLots` sobre el lote base, que es lo que hace hoy el original.

### D5. Stop loss de canasta enviado al broker en cada posición

Todas las posiciones comparten un SL calculado desde el promedio ponderado (`avg - SL` en compras, `avg + SL` en ventas). Cada nuevo paso recalcula el promedio y reenvía SL y TP a todas las posiciones.

**Por qué:** es la única protección que sobrevive a una desconexión del terminal. El original calcula ese precio y nunca lo envía.

**Alternativas descartadas:** stop solo blando monitoreado por el EA (falla si el terminal se cae) y SL independiente por orden (las posiciones salen en momentos distintos y rompen la lógica de canasta).

### D6. Los guards solo bloquean entradas

Orden de prioridad en cada tick: gestión y cierre primero, aperturas después. Volatilidad, spread, sesión y límite diario son condiciones de entrada, nunca de salida.

**Por qué:** el `return(0)` del ATR gate y el `return` de barra del original dejan posiciones sin TP, sin trailing y sin cierre.

### D7. Ejecución acotada

Cada envío o modificación tiene `MaxAttempts` y un deadline. Se registra el último código de retorno y se abandona el intento sin bloquear el hilo.

**Por qué:** los `while (!OrderModify(...)) { Sleep(1000); }` del original pueden congelar el EA indefinidamente.

**Alternativa descartada:** reintentar hasta el éxito (comportamiento actual).

### D8. Cuenta hedging obligatoria

`OnInit` verifica `ACCOUNT_MARGIN_MODE` y falla con mensaje explícito si es netting.

**Por qué:** en netting las órdenes del mismo símbolo se netean en una posición promedio y el grid no existe como concepto.

**Alternativa descartada:** soportar netting en v1. Requiere rediseñar la canasta como una sola posición, es otro change.

### D9. Panel como proyección del estado

El panel lee `BasketState` y `RiskGuard`; no recalcula indicadores ni recrea objetos si nada cambió. Se redibuja por dirty flag.

**Por qué:** hoy se recrean ~50 objetos y se calculan 49 indicadores por tick, ninguno de los cuales influye en el trading.

### D10. Handles de indicadores en `OnInit`

Solo se necesitan `iRSI` (timeframe del gráfico, período 14) y `iATR` (timeframe y período configurados). Se crean una vez y se leen con `CopyBuffer` al cierre de barra.

**Por qué:** en MQL5 no existe la llamada directa tipo MT4; crear handles por tick es caro y filtraría recursos.

### D11. Harness de paridad separado del producto

Un modo de exportación escribe `timestamp, estrategia, direccion, timeframe` a CSV. La referencia se genera con un port "solo señales" del MT4 (sin riesgo ni ejecución). La comparación es sobre direcciones y timestamps, no sobre PnL.

**Por qué:** "mismas señales, riesgo distinto" solo es verificable si se puede aislar la señal del resultado económico.

## Contratos entre módulos

Conceptuales, no código final:

```
Signal.Evaluate(context)            -> BUY | SELL | NONE
BasketState.Scan(magic)             -> Basket
RiskPolicy.Plan(basket, signal)     -> { NONE, OPEN_FIRST, OPEN_GRID,
                                         UPDATE_PROTECTION, CLOSE_ALL }
Executor.Apply(plan)                -> { OK, REJECTED, RETRY_EXHAUSTED }
Dashboard.Render(basket, guard)     -> void
```

`RiskPolicy` es el único módulo que conoce el balance, el presupuesto y los topes. `Executor` es el único que habla con `CTrade`.

## Fórmulas de referencia

```
pip_size          = 10 * point   si digits es 3 o 5
                  = point        si digits es 2 o 4
valor_pip_por_lote = tick_value / (tick_size / pip_size)
lote_inicial      = (RiskPct/100 * balance) / (SL_pips * valor_pip_por_lote)
lote_paso_n       = lote_inicial * LotMultiplier^n
perdida_proyectada = (volumen_canasta + lote_paso) * SL_pips * valor_pip_por_lote
```

Todos los límites se comparan contra `balance` (no `equity`) para que un drawdown flotante no habilite más riesgo.

## Valores iniciales a calibrar

No son compromisos de producto; son el punto de partida para el primer backtest.

| Parámetro | Valor inicial |
|---|---|
| `RiskPct` | 0.5% |
| `MaxBasketLossPct` | 2% |
| `DailyLossLimitPct` | 4% |
| `MaxGridSteps` | 4 |
| `LotMultiplier` | 1.5 |
| `MaxLotPerOrder` | 0.10 |
| `MaxVolumePerStrategy` | 0.30 |
| `SL_pips` | 40 |
| `TP_pips` | 8 |
| `GridStepPips` | 22 |
| `MaxSpreadPips` | 3 |

## Risks / Trade-offs

- **Cambiar el gate altera los resultados vs MT4** → la paridad se mide sobre señales, no sobre PnL; las diferencias esperadas se documentan en el reporte.
- **Exigir hedging excluye brokers netting** → error explícito en `OnInit`; soporte netting queda como change separado.
- **SL de canasta puede quedar dentro del stops level** → se clampea al mínimo permitido y, si eso rompe el presupuesto de riesgo, se rechaza la apertura y se registra.
- **El SL compartido se reenvía en cada paso** → N modificaciones por paso; se acota con `MaxGridSteps` y se toleran fallos parciales sin bloquear.
- **Estado del límite diario entre reinicios** → se persiste por cuenta y día del servidor; si falta, se reconstruye desde el historial.
- **Una estrategia por gráfico reduce el marketing de "3 en 1"** → se ofrecen tres presets y tres instancias; el motor soporta N canastas para cuando las señales sean distintas.
- **El cap corta la martingala antes de recuperar** → es el comportamiento buscado: la canasta cierra por SL en lugar de seguir agregando riesgo.

## Migration Plan

```
Fase 0  Port "solo señales" del MT4 -> CSV de referencia
Fase 1  Esqueleto: MarketContext + BasketState + Executor + RiskPolicy
Fase 2  Scalper Pro + paridad de señales
Fase 3  Caps de riesgo + limite diario + pruebas de rechazo
Fase 4  Fibonacci Focus y TrendMaster sobre el mismo contrato
Fase 5  Panel + harness + documentacion de operacion
```

Rollback: el EA nuevo es aditivo. Los `.mq4` de referencia no se tocan, así que el sistema anterior sigue disponible si una fase no converge.

## Open Questions

- ¿"Fibonacci Focus" debe implementar retrocesos reales antes del lanzamiento, o se mantiene la regla actual y se renombra?
- ¿Se necesita un tope agregado a nivel de cuenta entre varios gráficos? Requiere un registro compartido fuera del alcance de v1.
- ¿El EA debe restringirse a AUDCAD por defecto o aceptar cualquier símbolo con validación opcional?
