# ea-runtime Specification

## Purpose

Orquesta el ciclo del EA: cuándo evalúa señales, cuándo gestiona posiciones abiertas, qué exige de la cuenta y qué información muestra al operador.

## Requirements

### Requirement: Señal por barra, gestión por tick

Cada estrategia activa DEBE evaluar su señal una sola vez por barra cerrada. La gestión de las canastas abiertas DEBE ocurrir en cada tick, independientemente de si la señal se evaluó o no.

#### Scenario: Varios ticks dentro de la misma barra

- **WHEN** llegan diez ticks dentro de la misma barra
- **THEN** cada estrategia activa evalúa su señal una vez y la gestión de las canastas se ejecuta en los diez ticks

#### Scenario: Modo portafolio

- **WHEN** `Strategy=ALL` y llega una barra cerrada
- **THEN** las tres señales se evalúan una vez y las tres canastas se gestionan en cada tick siguiente

### Requirement: Los guards solo bloquean entradas

Volatilidad alta, spread fuera de rango, sesión cerrada o límite diario alcanzado NO DEBE impedir el cierre, el trailing ni la modificación de posiciones abiertas.

#### Scenario: Alta volatilidad con canasta abierta

- **WHEN** el ATR supera el máximo mientras hay una canasta abierta
- **THEN** no se abren posiciones nuevas y el take profit, el stop loss y el trailing siguen gestionándose

### Requirement: Cuenta hedging obligatoria

El sistema DEBE verificar en la inicialización que la cuenta es de tipo hedging. Si la cuenta es netting, DEBE rechazar la inicialización con un mensaje explícito y NO DEBE operar.

#### Scenario: Cuenta netting

- **WHEN** el EA se adjunta a una cuenta con modo de margen netting
- **THEN** la inicialización falla y el EA no envía órdenes

### Requirement: Ejecución acotada

Toda operación de envío o modificación DEBE tener un número máximo de intentos y un tiempo máximo total. El sistema NO DEBE usar bucles de reintento sin salida ni bloquear el hilo más allá del límite configurado.

#### Scenario: Rechazo persistente del broker

- **WHEN** el broker rechaza una modificación de stop loss de forma persistente
- **THEN** el sistema agota el límite de intentos, registra el error y continúa con el siguiente tick

### Requirement: Aislamiento entre estrategias

En modo `ALL`, cada estrategia DEBE gestionar únicamente las posiciones de su magic. Un rechazo o error de una estrategia NO DEBE impedir la evaluación ni la gestión de las otras.

#### Scenario: Error en una estrategia

- **WHEN** una estrategia agota sus reintentos al enviar una orden
- **THEN** las otras dos siguen evaluando señales y gestionando sus canastas en el mismo tick

### Requirement: Selección de estrategia por instancia

El sistema DEBE operar una estrategia por instancia, o las tres en modo portafolio, según un parámetro de entrada (`SCALPER`, `FIBONACCI`, `TREND` o `ALL`). Un valor inválido DEBE impedir la inicialización.

#### Scenario: Selección de estrategia

- **WHEN** el operador elige Scalper Pro
- **THEN** solo se evalúa esa señal y las otras dos no abren posiciones ni consumen presupuesto

#### Scenario: Modo portafolio

- **WHEN** el operador elige `ALL`
- **THEN** las tres estrategias evalúan su señal, cada una abre su propia canasta con un magic distinto y ninguna queda excluida por la selección

#### Scenario: Valor inválido

- **WHEN** el parámetro de entrada no es uno de los cuatro valores admitidos
- **THEN** la inicialización falla y el EA no envía órdenes

### Requirement: Validación previa de la orden

Antes de enviar una orden, el sistema DEBE normalizar el volumen al paso del símbolo, verificar los límites de volumen, respetar el stops level y el freeze level, y comprobar el margen disponible.

#### Scenario: Volumen no alineado al paso

- **WHEN** el volumen calculado no es múltiplo del paso de volumen del símbolo
- **THEN** se normaliza al múltiplo válido más cercano antes de enviar

### Requirement: Panel de estado de canasta

El panel DEBE mostrar, por estrategia activa, la dirección de la canasta, el volumen total, el precio promedio ponderado, el próximo nivel de grid, el presupuesto de riesgo consumido, el resultado del día, el riesgo vivo usado para dimensionar, la modalidad de riesgo activa (`manual` o `auto`), los controles `+`/`-` que ajustan el riesgo en modo manual y un botón que alterna la modalidad en caliente. En modo `ALL` DEBE mostrar una fila por estrategia y una fila agregada, con un único control de riesgo para la instancia. El panel NO DEBE recalcular indicadores ni recrear objetos en cada tick.

#### Scenario: Actualización eficiente

- **WHEN** no cambió ningún valor relevante del panel
- **THEN** el panel no se redibuja

#### Scenario: Panel en modo portafolio

- **WHEN** `Strategy=ALL` y las tres estrategias tienen canastas abiertas
- **THEN** el panel muestra tres filas, una por estrategia, y una fila con el agregado

#### Scenario: Riesgo visible en modo manual

- **WHEN** el panel se dibuja con `RiskMode=Manual`
- **THEN** muestra el riesgo vivo con dos decimales y en porcentaje, la modalidad `(manual)`, los botones `-` y `+` habilitados según el rango y el botón de modo con la etiqueta `Modo: Manual`

#### Scenario: Riesgo visible en modo automático

- **WHEN** el panel se dibuja con `RiskMode=Auto`
- **THEN** muestra el riesgo automático con dos decimales y en porcentaje, la modalidad `(auto)`, los botones `-` y `+` atenuados y el botón de modo con la etiqueta `Modo: Auto`

#### Scenario: Riesgo manual fuera del rango operable

- **WHEN** el modo es manual y el riesgo vivo está fuera de 0.5–10, por ejemplo porque el input es 0.08
- **THEN** el panel muestra el valor, la leyenda de fuera de rango y los botones `-` y `+` permanecen deshabilitados

### Requirement: Limpieza al desinicializar

Al desinicializar, el sistema DEBE eliminar todos los objetos gráficos que creó y DEBE dejar el comentario del gráfico limpio.

#### Scenario: Remoción del EA

- **WHEN** el operador quita el EA del gráfico
- **THEN** no quedan objetos ni textos del EA en el gráfico

### Requirement: Modalidades de riesgo manual y automática

El EA DEBE exponer el input `RiskMode` con dos valores, `Manual` y `Auto`, con `Auto` como valor por defecto. El input DEBE definir la modalidad inicial al iniciar el EA. La modalidad DEBE poder alternarse en caliente desde el panel, sin reiniciar, y el cambio NO DEBE persistirse por cuenta o magic: al reiniciar, la modalidad vuelve a la del input.

#### Scenario: Modalidad por defecto

- **WHEN** el EA inicia sin que el operador cambie `RiskMode`
- **THEN** el riesgo se comporta en modo automático, parte del input `RiskPct` y el panel muestra `(auto)`

#### Scenario: Modalidad manual elegida en el input

- **WHEN** el operador configura `RiskMode=Manual` y reinicia el EA
- **THEN** el riesgo arranca en el input `RiskPct`, se comporta en modo manual y el panel muestra `(manual)`

#### Scenario: Reinicio del EA

- **WHEN** el EA o el terminal se reinicia después de haber conmutado la modalidad en caliente
- **THEN** la modalidad vuelve a la del input `RiskMode`, sin conservar la conmutación previa

### Requirement: Tope máximo del riesgo automático

El EA DEBE exponer el input `AutoRiskMaxPct`, con valor por defecto 6.0, como tope máximo del riesgo automático. El valor válido DEBE estar entre 0.5 y 10.0; fuera de ese rango el EA NO DEBE iniciar. El tope NO DEBE alterar el rango operable manual 0.5–10 ni ajustarse en caliente desde el panel.

#### Scenario: Tope por defecto

- **WHEN** el EA inicia sin que el operador cambie `AutoRiskMaxPct`
- **THEN** el tope del riesgo automático es 6.0%

#### Scenario: Tope personalizado

- **WHEN** el operador configura `AutoRiskMaxPct=3.0`
- **THEN** el riesgo automático nunca supera 3.0% y el rango manual sigue siendo 0.5–10

#### Scenario: Tope inválido

- **WHEN** `AutoRiskMaxPct` es menor que 0.5 o mayor que 10.0
- **THEN** el EA no inicia y registra el parámetro inválido

### Requirement: Botón de modo en caliente

El panel DEBE incluir un botón de modo, siempre habilitado, con la etiqueta `Modo: Manual` o `Modo: Auto` según la modalidad vigente. Un clic DEBE alternar la modalidad sin reiniciar el EA ni modificar posiciones abiertas.

#### Scenario: Botón de modo siempre disponible

- **WHEN** el modo es manual o automático
- **THEN** el botón de modo permanece habilitado y muestra la modalidad vigente

#### Scenario: Canasta abierta durante la conmutación

- **WHEN** el operador conmuta la modalidad mientras hay una canasta abierta
- **THEN** el volumen y el stop loss de las posiciones existentes no cambian y la modalidad nueva se usa para el próximo paso de grid

### Requirement: Continuidad del riesgo al conmutar

Al pasar de `Manual` a `Auto`, la base del cálculo automático DEBE ser el riesgo vivo en ese momento. Al pasar de `Auto` a `Manual`, el riesgo vivo DEBE conservar el último valor automático y quedar disponible para los botones `+`/`-`. Mientras permanece en `Auto`, la base NO DEBE recalcularse con los valores automáticos sucesivos.

#### Scenario: Paso de manual a automático

- **WHEN** el riesgo manual es 4.0 y el operador hace clic en el botón de modo
- **THEN** la modalidad pasa a automática, la base del cálculo es 4.0 y el riesgo mostrado es `4.0` ajustado por la volatilidad vigente, acotado a 0.5–`AutoRiskMaxPct`

#### Scenario: Paso de automático a manual

- **WHEN** el riesgo automático mostrado es 2.35 y el operador hace clic en el botón de modo
- **THEN** la modalidad pasa a manual y los botones `+`/`-` operan desde 2.35

#### Scenario: Conmutaciones sucesivas

- **WHEN** el operador alterna varias veces entre manual y automático sin cambiar el ATR
- **THEN** el riesgo automático no se compone con los valores anteriores y cada entrada en automático usa el riesgo vivo del momento como base

### Requirement: Control de riesgo en vivo en modo manual

En modo manual, el sistema DEBE permitir ajustar el riesgo vivo en pasos de 0.5 puntos porcentuales mediante dos botones en el gráfico, dentro del rango 0.5–10. Cada clic DEBE aplicar exactamente un paso y actualizar el riesgo mostrado. El ajuste NO DEBE requerir reiniciar el EA y NO DEBE modificar posiciones ya abiertas.

#### Scenario: Subir el riesgo

- **WHEN** el riesgo vivo es 4.0 y el operador hace clic en `+`
- **THEN** el riesgo vivo pasa a 4.5 y el panel muestra 4.50%

#### Scenario: Bajar el riesgo

- **WHEN** el riesgo vivo es 4.0 y el operador hace clic en `-`
- **THEN** el riesgo vivo pasa a 3.5 y el panel muestra 3.50%

#### Scenario: Límite superior

- **WHEN** el riesgo vivo es 10.0
- **THEN** el botón `+` está deshabilitado y un clic no modifica el riesgo

#### Scenario: Límite inferior

- **WHEN** el riesgo vivo es 0.5
- **THEN** el botón `-` está deshabilitado y un clic no modifica el riesgo

#### Scenario: Canasta abierta

- **WHEN** el operador ajusta el riesgo mientras hay una canasta abierta
- **THEN** el volumen y el stop loss de las posiciones existentes no cambian y el riesgo ajustado se usa para el próximo paso de grid

#### Scenario: Vuelta desde automático

- **WHEN** el operador conmuta de automático a manual y el último riesgo automático está dentro de 0.5–10
- **THEN** los botones `+`/`-` quedan habilitados y operan desde ese valor sin saltar al input `RiskPct`

### Requirement: Riesgo automático por volatilidad

En modo automático, el riesgo vivo DEBE recalcularse en cada tick a partir de la última lectura de ATR cerrada y de la base capturada al entrar en la modalidad, según la política de riesgo automático definida en `risk-guard`. Los botones `+`/`-` DEBEN permanecer deshabilitados y sus clics DEBEN ignorarse, sin alterar el riesgo calculado; el botón de modo DEBE permanecer habilitado. El riesgo automático NO DEBE requerir reiniciar el EA para actualizarse y NO DEBE modificar posiciones ya abiertas.

#### Scenario: Volatilidad alta

- **WHEN** el ATR actual supera la media de las últimas barras y la modalidad es automática
- **THEN** el riesgo vivo calculado baja respecto de la base vigente y el panel muestra el nuevo valor con `(auto)`

#### Scenario: Volatilidad baja

- **WHEN** el ATR actual está por debajo de la media de las últimas barras y la modalidad es automática
- **THEN** el riesgo vivo calculado sube respecto de la base vigente, sin superar `AutoRiskMaxPct`

#### Scenario: Sin lectura de ATR

- **WHEN** no hay una lectura válida de ATR y la modalidad es automática
- **THEN** el factor de volatilidad es `1.0` y el riesgo vivo queda en la base vigente, acotado a 0.5–`AutoRiskMaxPct`

#### Scenario: Estabilidad dentro de la barra

- **WHEN** el ATR no cambia porque la barra en curso todavía no cerró
- **THEN** el riesgo automático conserva el mismo valor al actualizarse el panel

#### Scenario: Clic ignorado en modo automático

- **WHEN** el modo es automático y el operador hace clic en `+` o `-`
- **THEN** el riesgo vivo no cambia y el panel sigue mostrando el valor automático

#### Scenario: Reinicio en modo automático

- **WHEN** el EA se reinicia con `RiskMode=Auto`
- **THEN** el riesgo vuelve a partir de `RiskPct` y se recalcula en el primer tick con el ATR vigente
