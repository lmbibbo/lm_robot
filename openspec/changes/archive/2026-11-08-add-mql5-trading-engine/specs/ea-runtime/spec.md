# Spec Delta

## Purpose

Orquesta el ciclo del EA: cuándo evalúa señales, cuándo gestiona posiciones abiertas, qué exige de la cuenta y qué información muestra al operador.

## ADDED Requirements

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

### Requirement: Validación previa de la orden

Antes de enviar una orden, el sistema DEBE normalizar el volumen al paso del símbolo, verificar los límites de volumen, respetar el stops level y el freeze level, y comprobar el margen disponible.

#### Scenario: Volumen no alineado al paso

- **WHEN** el volumen calculado no es múltiplo del paso de volumen del símbolo
- **THEN** se normaliza al múltiplo válido más cercano antes de enviar

### Requirement: Limpieza al desinicializar

Al desinicializar, el sistema DEBE eliminar todos los objetos gráficos que creó y DEBE dejar el comentario del gráfico limpio.

#### Scenario: Remoción del EA

- **WHEN** el operador quita el EA del gráfico
- **THEN** no quedan objetos ni textos del EA en el gráfico

## RENAMED Requirements

- FROM: `### Requirement: Una estrategia por gráfico`
- TO: `### Requirement: Selección de estrategia por instancia`

## MODIFIED Requirements

### Requirement: Señal por barra, gestión por tick

Cada estrategia activa DEBE evaluar su señal una sola vez por barra cerrada. La gestión de las canastas abiertas DEBE ocurrir en cada tick, independientemente de si la señal se evaluó o no.

#### Scenario: Varios ticks dentro de la misma barra

- **WHEN** llegan diez ticks dentro de la misma barra
- **THEN** cada estrategia activa evalúa su señal una vez y la gestión de las canastas se ejecuta en los diez ticks

#### Scenario: Modo portafolio

- **WHEN** `Strategy=ALL` y llega una barra cerrada
- **THEN** las tres señales se evalúan una vez y las tres canastas se gestionan en cada tick siguiente

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

### Requirement: Panel de estado de canasta

El panel DEBE mostrar, por estrategia activa, la dirección de la canasta, el volumen total, el precio promedio ponderado, el próximo nivel de grid, el presupuesto de riesgo consumido y el resultado del día. En modo `ALL` DEBE mostrar una fila por estrategia y una fila agregada. El panel NO DEBE recalcular indicadores ni recrear objetos en cada tick.

#### Scenario: Actualización eficiente

- **WHEN** no cambió ningún valor relevante del panel
- **THEN** el panel no se redibuja

#### Scenario: Panel en modo portafolio

- **WHEN** `Strategy=ALL` y las tres estrategias tienen canastas abiertas
- **THEN** el panel muestra tres filas, una por estrategia, y una fila con el agregado
