# Tasks

## 1. Modelo de riesgo del panel

- [x] 1.1 En `Include/LmRobot/UI/Dashboard.mqh`, agregar `LM_RISK_MIN_PCT`, `LM_RISK_MAX_PCT`, `LM_RISK_STEP_PCT` y los helpers `LmRiskInControlRange`, `LmRiskCanStep`, `LmNextRiskPct` y `LmRiskButtonDirection`; verificar con asserts que 4.0 + paso da 4.5, 4.0 - paso da 3.5, 0.5 no baja, 10.0 no sube, 0.08 queda fuera de rango y el redondeo no acumula error de punto flotante.
- [x] 1.2 Agregar `riskPct`, `riskInRange`, `canDecrease` y `canIncrease` a `DashboardState`; poblarlos en `LmBuildDashboardState` y `LmBuildPortfolioDashboardState`, compararlos en `LmDashboardStateEquals` y emitir la línea `Riesgo: X.XX%` (con la leyenda de fuera de rango) en `LmDashboardLines`; verificar que un cambio solo de `riskPct` hace que `Update` redibuje y que el texto aparece en la última línea.
- [x] 1.3 Actualizar `TestDashboardFields` para esperar 9 líneas en modo único, comprobar la línea de riesgo y ajustar el caso de portafolio de dos estrategias a 6 líneas; verificar que `tests/TestRunner.mq5` compila con `powershell -ExecutionPolicy Bypass -File tools\build.ps1 -Source tests\TestRunner.mq5` sin errores.

## 2. Riesgo vivo en el runtime

- [x] 2.1 Agregar `bool SetRiskPct(const double pct)` a `CLmRuntime`: rechazar valores no finitos o `<= 0`, escribir `m_config.risk.riskPct` y reflejarlo en `Config()`; verificar que un valor válido se lee de vuelta y que `0`, negativo o `NaN` no modifican el riesgo previo.
- [x] 2.2 Agregar una prueba de runtime con topes de volumen amplios que abra la primera orden, llame a `SetRiskPct` con el doble de riesgo y avance un paso de grid; verificar que el volumen del nuevo paso crece en la proporción esperada y que la posición anterior conserva su volumen y su SL.
- [x] 2.3 Documentar en `docs/riesgo.md` que el riesgo es un valor vivo ajustable, que no se recorta el input, que aplica a la próxima orden y a los pasos siguientes de una canasta abierta, y que subir el riesgo puede hacer que `MaxBasketLossPct` rechace el paso; verificar que las fórmulas y los ejemplos del documento siguen coincidiendo con `LmInitialLot`.

## 3. Botones en el renderer

- [x] 3.1 Crear en `CChartDashboardRenderer` los objetos `LMROBOT_PANEL_BTN_RISK_DOWN` y `LMROBOT_PANEL_BTN_RISK_UP` como `OBJ_BUTTON`, ubicados debajo de la última línea, con texto `-`/`+`, sin selección y con colores atenuados cuando `canDecrease`/`canIncrease` sean falsos; verificar que un render posterior reutiliza los objetos y actualiza posición, color y estado sin crearlos de nuevo.
- [x] 3.2 Actualizar `TestDashboardCleanup` y `TestDashboardNoObjectsPerTick` a 11 objetos (9 etiquetas + 2 botones), y agregar asserts de que `Clear()` elimina también los botones y de que `CreatedCount()` no aumenta en renders sucesivos; verificar que ambos tests pasan en `TestRunner`.
- [x] 3.3 Actualizar la sección "Panel de estado" de `docs/operacion.md` con la línea de riesgo, el significado de `+`/`-`, el rango 0.5–10, el paso 0.5 y el comportamiento cuando el input queda fuera de rango; verificar que el texto describe el panel que producen los tests.

## 4. Integración con el EA

- [x] 4.1 Extraer de `OnTick` en `EA/LmRobot.mq5` una función `RefreshPanel()` que lea `g_runtime.Config()`, arme las vistas y actualice `g_dashboard`; reemplazar el bloque original por la llamada y verificar que `EA\LmRobot.mq5` compila sin errores ni advertencias.
- [x] 4.2 Implementar `OnChartEvent` para `CHARTEVENT_OBJECT_CLICK`: resolver el botón con `LmRiskButtonDirection`, calcular el nuevo riesgo con `LmNextRiskPct`, aplicar `g_runtime.SetRiskPct` cuando cambie, desmarcar el botón con `OBJPROP_STATE=false`, ignorar clics fuera de rango y llamar a `RefreshPanel()`; verificar en el tester visual o en una cuenta demo que un clic modifica el riesgo mostrado, que en 0.5/10.0 el botón correspondiente no responde y que un reinicio vuelve al valor del input.
- [ ] 4.3 Verificar manualmente con una canasta abierta que el clic no altera el volumen ni el SL de las posiciones existentes y que el siguiente paso de grid usa el riesgo ajustado; registrar el resultado en la sesión de aplicación.

## 5. Verificación final

- [ ] 5.1 Ejecutar la suite completa en `tests/TestRunner.mq5` en un gráfico de MT5 y confirmar que todos los tests, incluidos los nuevos de riesgo y panel, terminan sin fallos.
- [x] 5.2 Compilar `EA\LmRobot.mq5` y `tests\TestRunner.mq5` con `tools\build.ps1` y confirmar 0 errores y 0 advertencias.
- [x] 5.3 Ejecutar `openspec validate add-risk-control-buttons` y confirmar que el cambio valida sin errores.

## 6. Modalidades manual y automática

- [x] 6.1 En `Include/LmRobot/Risk/RiskPolicy.mqh`, agregar el enum `ENUM_LM_RISK_MODE` (`Manual`/`Auto`), los campos `riskMode`, `riskBasePct` y `autoRiskMaxPct` a `RiskConfig` y sus valores por defecto; verificar con asserts que la configuración por defecto queda en modo automático, con `riskBasePct = riskPct` y `autoRiskMaxPct = 6.0`, y que los tests del control manual fijan `riskMode = LM_RISK_MANUAL` explícitamente.
- [x] 6.2 En `Include/LmRobot/Risk/RiskPolicy.mqh`, agregar la función pura `LmAutoRiskPct` con la fórmula `clamp(RiskPct * clamp(ATR_medio / ATR_actual, VolFactorMin, VolFactorMax), 0.5, AutoRiskMaxPct)` redondeada a dos decimales, tope saneado a 0.5–10.0 y factor `1.0` sin ATR; verificar con asserts volatilidad alta, volatilidad baja, tope por defecto 6.0, tope personalizado 3.0, base por encima del tope, redondeo y ausencia de lectura de ATR.
- [x] 6.3 En `EA/LmRobot.mq5`, agregar los inputs `RiskMode` (por defecto `Auto`) y `AutoRiskMaxPct` (por defecto `6.0`, rango válido 0.5–10.0), validar el tope en `OnInit` y mapear ambos junto con `RiskPct` en el `RuntimeConfig`; verificar que el EA compila sin errores ni advertencias, que al iniciar sin tocar el input el panel muestra `(auto)` y que un tope fuera de rango impide iniciar.
- [x] 6.4 En `Include/LmRobot/Core/Runtime.mqh`, recalcular `m_config.risk.riskPct` con `LmAutoRiskPct` al inicio de `ProcessTick` cuando `riskMode == Auto`, y hacer que `SetRiskPct` devuelva `false` sin escribir en modo automático; verificar con tests de runtime que el riesgo sigue al ATR y que un ajuste manual no lo pisa.
- [x] 6.5 En `Include/LmRobot/Core/Runtime.mqh`, agregar `SetRiskMode`: al pasar a `Auto`, capturar `riskBasePct = riskPct` y recalcular con el ATR vigente; al pasar a `Manual`, conservar el último riesgo automático. Verificar con tests que la base no se recompone en ticks sucesivos y que las conmutaciones repetidas conservan la continuidad.
- [x] 6.6 En `Include/LmRobot/Core/Runtime.mqh`, pasar `avgAtrPips = atrPips` a `LmPlanInitialOrder` en la apertura inicial y en el recálculo de `OpenGrid` cuando el modo es automático, y conservar el `avgAtrPips` real en modo manual; verificar que dos corridas con el mismo riesgo y distinto ATR producen el mismo lote en automático y distinto lote en manual.
- [x] 6.7 En `Include/LmRobot/UI/Dashboard.mqh`, agregar `riskMode` a `DashboardState`, incluirlo en `LmDashboardStateEquals` y emitir la línea `Riesgo: X.XX% (manual|auto)`; en modo automático o fuera de rango manual, `canDecrease`/`canIncrease` deben ser falsos y la leyenda de fuera de rango debe aparecer solo en manual; agregar el helper `LmRiskModeButton` y verificar con tests de panel.
- [x] 6.8 En `CChartDashboardRenderer`, agregar `LMROBOT_PANEL_BTN_RISK_MODE` con texto `Modo: Manual`/`Modo: Auto`, siempre habilitado y ubicado entre `-` y `+`; actualizar `TestDashboardCleanup` y `TestDashboardNoObjectsPerTick` a 12 objetos (9 etiquetas + 3 botones) en modo único y a las líneas + 3 botones en portafolio, verificando que `Clear()` elimina los tres botones y que un render posterior no crea objetos nuevos.
- [x] 6.9 En `EA/LmRobot.mq5`, hacer que `OnChartEvent` resuelva el botón de modo y llame a `SetRiskMode` alternando la modalidad, y que ignore los clics de `+`/`-` cuando `riskMode == Auto`; verificar que el botón de modo refresca el panel, que en manual `+`/`-` sigue aplicando un paso y que en automático no modifican el riesgo.
- [x] 6.10 Actualizar `docs/riesgo.md` y `docs/operacion.md` con las modalidades, la fórmula automática, el tope `AutoRiskMaxPct` (default 6.0, rango 0.5–10.0), la conmutación en caliente con continuidad, el rango manual 0.5–10, el factor de lote `1.0` en automático y el reinicio al valor del input; verificar que las fórmulas y ejemplos coinciden con `LmAutoRiskPct`, `LmVolatilityFactor` y `LmInitialLot`.
- [ ] 6.11 Verificar en cuenta demo: que al iniciar sin cambiar `RiskMode` la modalidad es automática y parte de `RiskPct`; conmutar manual→auto y comprobar que la base es el riesgo vivo, conmutar auto→manual y comprobar que los botones parten del último valor automático, que `+`/`-` no responden en automático, que sin ATR se usa la base acotada, que bajar `AutoRiskMaxPct` recorta el riesgo automático y que al reiniciar se vuelve al input; registrar el resultado en la sesión de aplicación.

## Workflow follow-up

- Archivar el cambio cuando la revisión del proyecto esté satisfecha.
- Verificar el resultado archivado y que las specs principales reflejen los deltas.
