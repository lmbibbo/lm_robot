# Spec Delta

## Purpose

Decide el volumen de cada orden y aplica los límites de exposición y de pérdida que protegen la cuenta, con prioridad absoluta sobre cualquier señal de entrada.

## ADDED Requirements

### Requirement: Lote calculado por riesgo

El volumen inicial de una canasta DEBE calcularse como `(riesgo% / 100) * balance / (SL_pips * valor_pip_por_lote)`, normalizado al paso de volumen del símbolo y acotado entre el mínimo y el máximo permitidos por el broker.

#### Scenario: Balance y stop loss definen el lote

- **WHEN** el balance es 10.000, el riesgo configurado es 0.5% y el stop loss de canasta es 40 pips con un valor de 10 unidades por pip por lote
- **THEN** el volumen inicial es 0.12 lotes, normalizado al paso del símbolo

#### Scenario: Lote fuera de rango

- **WHEN** el cálculo produce un volumen menor al mínimo del broker
- **THEN** se usa el mínimo del broker o se rechaza la apertura si el mínimo implica superar el presupuesto de riesgo

### Requirement: Presupuesto de pérdida de canasta

Antes de abrir cualquier orden, el sistema DEBE calcular la pérdida proyectada de la canasta completa en su stop loss: `(volumen actual + volumen nuevo) * SL_pips * valor_pip_por_lote`. Si esa pérdida supera el porcentaje máximo del balance configurado, la orden NO DEBE enviarse.

#### Scenario: Paso de grid rechazado por riesgo

- **WHEN** agregar el siguiente paso de grid haría que la canasta pierda más que el presupuesto configurado al tocar el stop loss
- **THEN** el paso se rechaza y la canasta queda con las posiciones que ya tenía

#### Scenario: Paso de grid aceptado

- **WHEN** la pérdida proyectada con el nuevo paso sigue dentro del presupuesto
- **THEN** el paso se envía con el volumen calculado

### Requirement: Topes de volumen

El sistema DEBE aplicar tres topes independientes: volumen máximo por orden, volumen máximo por canasta y cantidad máxima de pasos de grid. Un tope alcanzado NO DEBE impedir cerrar, mover o reducir posiciones existentes.

#### Scenario: Tope de pasos alcanzado

- **WHEN** la canasta ya tiene la cantidad máxima de pasos configurada
- **THEN** no se habilitan pasos nuevos aunque el precio alcance la distancia de grid

#### Scenario: Tope de volumen por orden

- **WHEN** el volumen calculado para un paso supera el máximo por orden
- **THEN** se usa el máximo por orden o se rechaza el paso si eso excede el presupuesto de canasta

### Requirement: Stop loss obligatorio

Ninguna orden DEBE enviarse sin un stop loss válido y distinto de cero. Si el stop loss calculado no respeta la distancia mínima del broker o el margen disponible es insuficiente, la orden NO DEBE enviarse y el motivo DEBE registrarse.

#### Scenario: Sin stop loss no hay orden

- **WHEN** el stop loss calculado queda dentro del stops level del símbolo
- **THEN** la orden se rechaza y se registra el error, en lugar de enviarse sin protección

#### Scenario: Margen insuficiente

- **WHEN** el margen libre no alcanza para el volumen solicitado
- **THEN** la orden no se envía y la canasta no se modifica

### Requirement: Límite de pérdida diaria

El sistema DEBE comparar la equidad actual con la equidad registrada al inicio del día del servidor. Si la caída supera el porcentaje configurado, DEBE bloquear nuevas entradas hasta el inicio del día siguiente. El valor de referencia DEBE sobrevivir a un reinicio del terminal.

#### Scenario: Límite diario alcanzado

- **WHEN** la equidad cae más que el porcentaje diario configurado respecto del inicio del día
- **THEN** no se abren canastas nuevas hasta el día siguiente y las posiciones abiertas siguen gestionándose

#### Scenario: Reinicio dentro del mismo día

- **WHEN** el terminal se reinicia después de alcanzar el límite diario, el mismo día del servidor
- **THEN** el bloqueo de entradas se mantiene

### Requirement: Los límites no interrumpen la gestión

Cuando un límite de riesgo y una acción de gestión coinciden en el mismo tick, el sistema DEBE ejecutar primero la gestión de las posiciones abiertas: cierre por stop, take profit, trailing o reducción de exposición.

#### Scenario: Guard y cierre simultáneos

- **WHEN** el límite diario está activo y una canasta alcanza su stop loss de canasta
- **THEN** el cierre se ejecuta igual y solo se bloquean las aperturas
