# Proposal

## Why

`CodigoOriginalMT4.mq4` no es un sistema operable: calcula un stop loss que nunca envía al broker, deja la martingala sin tope (hasta ~274 lotes por paso) y un `return` en la línea 945 hace que Scalper Pro y TrendMaster solo se ejecuten en el primer tick de cada barra. Al mismo tiempo, el 32% del archivo son 49 indicadores de panel que no influyen en ninguna decisión y las tres estrategias comparten un mismo motor triplicado.

El port parcial `CodigoRefactorizado.mq5` confirma el problema: solo Scalper está implementado, Fibonacci y Trend son stubs, y no existe ninguna spec que diga qué debe hacer el sistema. Antes de escribir más MQL5 hay que fijar el contrato de comportamiento.

## What Changes

- **Nuevo EA MQL5** con una estrategia activa por gráfico por defecto, o las tres en modo portafolio (`Strategy=ALL`), elegidas por input. El timeframe de la señal es el del gráfico; desaparecen los inputs `Timeframe_*` que la señal ignoraba.
- **Modo portafolio `Strategy=ALL`**: una instancia opera las tres estrategias sobre el mismo símbolo, con un magic distinto por estrategia y una canasta independiente por magic. Comparte cuenta, margen y equidad, y aplica un presupuesto agregado de instancia además de los topes por canasta. Reproduce la estructura de cuenta del MT4 para la comparación justa; el valor por defecto sigue siendo una sola estrategia.
- **Motor de canasta único** que reemplaza las 18 funciones duplicadas: estado de la canasta, precio promedio ponderado por volumen, niveles de grid, TP y SL de canasta.
- **Grid con martingala capada por pérdida proyectada**, no solo por lote: cada paso se rechaza si el volumen resultante al SL excede el presupuesto de la canasta.
- **Stop loss real** por orden, enviado al broker, más SL de canasta y límite de pérdida diaria.
- **Guards que solo bloquean entradas**: volatilidad, spread, sesión y límite diario nunca interrumpen la gestión de posiciones abiertas.
- **Panel reducido** al estado de la canasta y al presupuesto de riesgo consumido. Se eliminan los 49 indicadores decorativos y los cálculos que nunca se usaban.
- **Harness de backtest** con `OnTester()` y exportación CSV para comparar la paridad de señales contra el MT4 antes de comparar resultados.
- **BREAKING**: el EA requiere una cuenta *hedging*. En una cuenta *netting* las órdenes del grid colapsan en una posición promedio y el motor no puede operar.
- **BREAKING**: al corregir el gate de barra, las tres estrategias pasan a evaluarse en cada barra. Los resultados de backtest van a diferir del MT4 original por diseño.

## Capabilities

### New Capabilities

- `market-context`: normalización del instrumento (dígitos, punto, pip, valor del tick, stops level), snapshot de mercado y régimen de volatilidad.
- `entry-signals`: las reglas de entrada de cada estrategia como funciones puras y testeables, sin lote, SL ni ejecución.
- `basket-engine`: estado de la canasta por magic (una canasta por estrategia en modo `ALL`), precio promedio ponderado, niveles de grid, TP de canasta y ciclo de vida.
- `risk-guard`: dimensionamiento del lote, presupuesto de riesgo por canasta y agregado por instancia (modo `ALL`), límite de pérdida diaria y kill switch.
- `ea-runtime`: ciclo `OnTick`, gates de entrada, selección de estrategia (única o `ALL`), ejecución acotada de órdenes, panel y requisitos de cuenta.
- `backtest-harness`: métricas de `OnTester` (incluidas las de portafolio y la atribución por estrategia), exportación CSV y comparación de paridad de señales contra la referencia MT4.

### Modified Capabilities

Las seis capacidades son nuevas. Las specs principales que hoy existen en `openspec/specs/` se crearon durante la implementación de este mismo change, así que el delta se aplica como `ADDED` para las requirements nuevas y `MODIFIED`/`RENAMED` para las que este refinamiento modifica.

## Impact

- **Código nuevo**: `EA/LmRobot.mq5` e `Include/LmRobot/` (Core, Risk, Execution, Strategies, UI). No se modifican los `.mq4` de referencia ni los `.mq5` existentes.
- **Dependencias**: MetaEditor 5 para compilar; `CTrade`; cuenta hedging; símbolo con `SYMBOL_TRADE_STOPS_LEVEL` válido.
- **Alcance de símbolo**: el original declara AUDCAD pero no lo valida. El motor será agnóstico al símbolo y la validación quedará como configuración.
- **Fuera de alcance de esta versión**: Fibonacci real, ejecución multi-símbolo, optimización genética, licenciamiento y firma del binario. El modo `Strategy=ALL` es multi-estrategia sobre **un solo símbolo** y sí está en alcance; la exposición agregada entre **varios gráficos o instancias** queda fuera.
- **Verificación**: backtests de paridad de señales contra `CodigoOriginalMT4.mq4`, backtest de portafolio con `Strategy=ALL` y pruebas de que los caps de riesgo —por canasta y agregados— se respetan en todos los caminos de apertura.
