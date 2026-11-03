# ea-runtime Specification

## Purpose

Orquesta el ciclo del EA: cuándo evalúa señales, cuándo gestiona posiciones abiertas, qué exige de la cuenta y qué información muestra al operador.

## Requirements

### Requirement: Señal por barra, gestión por tick

La evaluación de señales DEBE ocurrir una sola vez por barra cerrada. La gestión de posiciones abiertas DEBE ocurrir en cada tick, independientemente de si la señal se evaluó o no.

#### Scenario: Varios ticks dentro de la misma barra

- **WHEN** llegan diez ticks dentro de la misma barra
- **THEN** la señal se evalúa una vez y la gestión de la canasta se ejecuta en los diez ticks

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

### Requirement: Una estrategia por gráfico

El sistema DEBE operar una sola estrategia por instancia, seleccionada por un parámetro de entrada. Un valor inválido DEBE impedir la inicialización.

#### Scenario: Selección de estrategia

- **WHEN** el operador elige Scalper Pro
- **THEN** solo se evalúa esa señal y las otras dos no abren posiciones ni consumen presupuesto

### Requirement: Validación previa de la orden

Antes de enviar una orden, el sistema DEBE normalizar el volumen al paso del símbolo, verificar los límites de volumen, respetar el stops level y el freeze level, y comprobar el margen disponible.

#### Scenario: Volumen no alineado al paso

- **WHEN** el volumen calculado no es múltiplo del paso de volumen del símbolo
- **THEN** se normaliza al múltiplo válido más cercano antes de enviar

### Requirement: Panel de estado de canasta

El panel DEBE mostrar la estrategia activa, la dirección de la canasta, el volumen total, el precio promedio ponderado, el próximo nivel de grid, el presupuesto de riesgo consumido y el resultado del día. El panel NO DEBE recalcular indicadores ni recrear objetos en cada tick.

#### Scenario: Actualización eficiente

- **WHEN** no cambió ningún valor relevante del panel
- **THEN** el panel no se redibuja

### Requirement: Limpieza al desinicializar

Al desinicializar, el sistema DEBE eliminar todos los objetos gráficos que creó y DEBE dejar el comentario del gráfico limpio.

#### Scenario: Remoción del EA

- **WHEN** el operador quita el EA del gráfico
- **THEN** no quedan objetos ni textos del EA en el gráfico
