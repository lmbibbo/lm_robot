# Tasks

## 1. Scaffold del proyecto y build

- [x] 1.1 Crear el layout `EA/LmRobot.mq5` + `Include/LmRobot/{Core,Risk,Execution,Strategies,UI}` y confirmar que MetaEditor compila un EA vacío sin errores
- [x] 1.2 Crear `tools/build.ps1` que invoque el compilador de MetaEditor y devuelva código distinto de cero ante error; verificar compilando el EA vacío y provocando un error a propósito
- [x] 1.3 Crear `tests/TestRunner.mq5` con aserciones mínimas y contador PASS/FAIL; verificar que una aserción falsa hace fallar el runner
- [x] 1.4 Ampliar `.gitignore` con `*.ex5`, `*.log` y artefactos de backtest; verificar con `git status` que un `.ex5` generado no aparece
- [x] 1.5 Documentar layout y comando de build en `docs/build.md`; verificar ejecutando el comando tal como está escrito

## 2. Market context

- [x] 2.1 Implementar detección de pip (3/5 dígitos → 10 puntos; 2/4 → 1 punto) en una función que reciba dígitos y punto como parámetros; verificar los cuatro casos con el TestRunner
- [x] 2.2 Implementar valor del pip por lote (`tick_value / (tick_size / pip_size)`); verificar el cálculo con un símbolo de 5 dígitos y otro de 4
- [x] 2.3 Implementar snapshot por tick (bid, ask, spread, stops level) leído una sola vez; verificar que dos consumidores del mismo tick obtienen el mismo par
- [x] 2.4 Crear handles de RSI (timeframe del gráfico, período 14) y ATR (timeframe y período configurables) en `OnInit`, y liberarlos en `OnDeinit`; verificar que el handle es válido y que no se crea ninguno en `OnTick`
- [x] 2.5 Implementar flags de spread máximo y volatilidad alta en pips; verificar con valores por encima y por debajo de cada umbral

## 3. Basket state

- [x] 3.1 Implementar `Scan(magic)` que filtre símbolo y magic y devuelva cantidad, dirección, volumen, promedio y precio de la última orden; verificar que ignora posiciones de otro magic
- [x] 3.2 Calcular promedio ponderado y PnL con `profit + swap + commission`; verificar con 0.01 lotes a 1.0000 y 0.02 a 1.0010 (promedio esperado 1.0007)
- [x] 3.3 Implementar el ciclo de vida plano / abierto / cerrado y el reinicio del contador de pasos; verificar que al cerrar toda la canasta el contador vuelve a cero
- [x] 3.4 Implementar la detección de paso de grid por distancia en pips desde la última orden; verificar compra que cae, venta que sube y el caso que no alcanza la distancia

## 4. Executor

- [x] 4.1 Implementar envío con normalización de volumen al step, mínimo y máximo del símbolo; verificar que un volumen no múltiplo se ajusta al válido más cercano
- [x] 4.2 Rechazar órdenes sin stop loss válido o con stop dentro del stops level; verificar que no se envía y que se registra el motivo
- [x] 4.3 Implementar reintentos acotados por cantidad y por deadline, sin bucles infinitos; verificar con un ejecutor simulado que rechaza siempre y confirmar que retorna al agotar el límite
- [x] 4.4 Implementar la modificación de SL y TP de toda la canasta; verificar que todas las posiciones quedan con el mismo SL y el mismo TP
- [x] 4.5 Verificar margen disponible antes de enviar; verificar que una orden sin margen se rechaza y la canasta no se altera

## 5. Risk policy

- [x] 5.1 Implementar lote inicial por fórmula de riesgo y clamp al broker; verificar el caso balance 10.000, riesgo 0.5%, SL 40 pips y valor 10 por pip por lote (resultado 0.12)
- [x] 5.2 Implementar pérdida proyectada y rechazo del paso de grid; verificar que un paso que excede el 2% del balance no se envía
- [x] 5.3 Implementar topes de volumen por orden, por canasta y de pasos; verificar cada tope de forma independiente
- [x] 5.4 Implementar límite diario persistente por cuenta y día del servidor; verificar que sobrevive a un reinicio simulado
- [x] 5.5 Implementar la prioridad gestión sobre apertura; verificar que con el límite diario activo un cierre por SL se ejecuta igual
- [x] 5.6 Documentar el modelo de riesgo, cada cap y su fórmula en `docs/riesgo.md`; verificar que aparecen todos los parámetros de la tabla del design

## 6. Paridad de señales (Scalper)

- [ ] 6.1 Crear el port "solo señales" de referencia y generar el CSV de referencia para AUDCAD en el período elegido; verificar que hay una fila por barra evaluada
- [ ] 6.2 Implementar la exportación CSV del motor nuevo con fecha, estrategia, dirección y timeframe; verificar que incluye las señales `NONE`
- [ ] 6.3 Implementar el comparador de CSV que reporte coincidencias, faltantes y sobrantes; verificar con dos archivos idénticos (cero diferencias) y con uno alterado
- [ ] 6.4 Implementar la señal Scalper Pro (`close[2] > close[1]`) como función pura; verificar los dos casos y el determinismo en dos evaluaciones
- [ ] 6.5 Ejecutar la comparación de Scalper contra la referencia y documentar las diferencias esperadas por el gate de barra; verificar que el reporte existe y explica cada diferencia
- [ ] 6.6 Documentar el procedimiento de paridad en `docs/paridad.md`; verificar que otra persona puede reproducir el CSV de referencia siguiendo el documento

## 7. Integración del runtime

- [ ] 7.1 Implementar `OnTick` con gestión en cada tick y evaluación de señal solo en barra cerrada; verificar con un contador que diez ticks producen una evaluación
- [ ] 7.2 Validar cuenta hedging en `OnInit` y fallar con mensaje explícito; verificar simulando una cuenta netting
- [ ] 7.3 Implementar la selección de estrategia por input y su validación; verificar un valor válido y uno inválido
- [ ] 7.4 Integrar los guards de spread, volatilidad, sesión y límite diario solo sobre aperturas; verificar que una canasta abierta sigue gestionándose con cada guard activo
- [ ] 7.5 Integrar el pipeline completo en el Strategy Tester; verificar que abre la primera orden, agrega un paso de grid, mueve TP y SL, y cierra la canasta

## 8. Señales restantes

- [ ] 8.1 Implementar Fibonacci Focus con la regla MT4 y sus tres resultados; verificar `SELL`, `BUY` y `NONE`
- [ ] 8.2 Implementar TrendMaster con la regla MT4 y sus tres resultados; verificar `SELL`, `BUY` y `NONE`
- [ ] 8.3 Conectar ambas al mismo contrato de señal; verificar que solo la estrategia seleccionada abre posiciones y que las otras dos no consumen presupuesto

## 9. Panel y operación

- [ ] 9.1 Implementar el panel con estrategia, dirección, volumen, promedio, próximo grid, presupuesto consumido y PnL del día; verificar que los siete campos aparecen y se actualizan
- [ ] 9.2 Implementar dirty flag para no redibujar sin cambios; verificar con un contador que los ticks sin cambio no incrementan redibujos
- [ ] 9.3 Implementar limpieza de objetos y comentario en `OnDeinit`; verificar que no quedan objetos del EA en el gráfico
- [ ] 9.4 Documentar operación (cuenta hedging, parámetros, límites, interpretación del panel) en `docs/operacion.md`; verificar que cada input del EA está explicado

## 10. Verificación de integración

- [ ] 10.1 Correr un backtest por estrategia y verificar en el reporte que no se superan volumen máximo, pasos máximos ni pérdida proyectada
- [ ] 10.2 Correr un período con racha adversa y verificar que el conteo de activaciones del límite diario coincide con el reporte
- [ ] 10.3 Verificar reproducibilidad: dos corridas idénticas producen el mismo CSV y las mismas métricas de `OnTester`
- [ ] 10.4 Verificar que la compilación no tiene warnings y que el EA no crea handles ni objetos gráficos por tick

## Workflow follow-up

- Archivar el change una vez que la revisión del proyecto esté satisfecha.
- Verificar el resultado archivado.
