# risk-guard Specification

## Purpose

Decide el volumen de cada orden y aplica los límites de exposición y de pérdida que protegen la cuenta, con prioridad absoluta sobre cualquier señal de entrada.

## Requirements

### Requirement: Lote calculado por riesgo

El volumen inicial de una canasta DEBE calcularse como `(riesgo% / 100) * balance / (SL_efectivo_pips * valor_pip_por_lote) * factor_volatilidad`, normalizado al paso de volumen del símbolo y acotado entre el mínimo y el máximo permitidos por el broker. `riesgo%` DEBE ser el riesgo vivo de la instancia y su fuente DEBE depender de la modalidad: en `Manual` arranca en el input `RiskPct` y puede ajustarse en runtime; en `Auto` se deriva del input `RiskPct` al iniciar o del riesgo vivo capturado al conmutar, ajustado por la volatilidad según la política automática.

`SL_efectivo_pips` DEBE ser `max(SL_pips, ATR_pips * multiplicador ATR)`, de modo que la distancia de riesgo crezca proporcionalmente con el ATR y el lote disminuya cuando la volatilidad sube. En modo `Manual`, `factor_volatilidad` DEBE ser `clamp(ATR_medio / ATR_actual, mínimo, máximo)`, con `1.0` cuando no hay lectura válida. En modo `Auto`, `factor_volatilidad` DEBE ser `1.0` para no duplicar la señal de volatilidad que ya transporta `riesgo%`. La misma `SL_efectivo_pips` DEBE usarse como stop loss enviado al broker.

#### Scenario: Balance y stop loss definen el lote

- **WHEN** el balance es 10.000, el riesgo configurado es 0.5% y el stop loss efectivo de canasta es 40 pips con un valor de 10 unidades por pip por lote
- **THEN** el volumen inicial es 0.12 lotes, normalizado al paso del símbolo

#### Scenario: Stop loss proporcional al ATR

- **WHEN** el ATR supera el piso `SL_pips` multiplicado por el multiplicador configurado
- **THEN** el stop loss efectivo, el lote y la pérdida proyectada usan la distancia derivada del ATR

#### Scenario: Ajuste por volatilidad relativa

- **WHEN** el modo es manual y el ATR actual difiere de la media de las últimas barras
- **THEN** el lote se multiplica por la razón media/actual, acotada entre el mínimo y el máximo configurados

#### Scenario: Lote fuera de rango

- **WHEN** el cálculo produce un volumen menor al mínimo del broker
- **THEN** se usa el mínimo del broker o se rechaza la apertura si el mínimo implica superar el presupuesto de riesgo

### Requirement: Presupuesto de pérdida de canasta

Antes de abrir cualquier orden, el sistema DEBE calcular la pérdida proyectada de la canasta completa en su stop loss: `(volumen actual + volumen nuevo) * SL_efectivo_pips * valor_pip_por_lote`, donde `SL_efectivo_pips` es la distancia derivada del ATR cuando está disponible. Si esa pérdida supera el porcentaje máximo del balance configurado, la orden NO DEBE enviarse.

#### Scenario: Paso de grid rechazado por riesgo

- **WHEN** agregar el siguiente paso de grid haría que la canasta pierda más que el presupuesto configurado al tocar el stop loss
- **THEN** el paso se rechaza y la canasta queda con las posiciones que ya tenía

#### Scenario: Paso de grid aceptado

- **WHEN** la pérdida proyectada con el nuevo paso sigue dentro del presupuesto
- **THEN** el paso se envía con el volumen calculado

### Requirement: Presupuesto agregado en modo portafolio

En modo `ALL`, antes de abrir cualquier orden el sistema DEBE comparar la pérdida proyectada de todas las canastas abiertas más la orden nueva contra un presupuesto agregado de instancia. Si lo supera, la orden NO DEBE enviarse. Los presupuestos por canasta siguen siendo independientes y el rechazo agregado NO DEBE impedir la gestión de las canastas existentes.

#### Scenario: Apertura rechazada por el agregado

- **WHEN** la pérdida proyectada de las tres canastas más la orden nueva supera `MaxAggregateLossPct`
- **THEN** la orden no se envía y las canastas abiertas conservan su gestión

#### Scenario: Gestión con el agregado agotado

- **WHEN** el presupuesto agregado está agotado y una canasta alcanza su take profit
- **THEN** el cierre se ejecuta igual y solo se bloquean las aperturas

### Requirement: Topes de volumen

El sistema DEBE aplicar topes independientes: volumen máximo por orden, volumen máximo por canasta y cantidad máxima de pasos de grid. En modo `ALL` DEBE aplicar además un tope de volumen concurrente agregado. Un tope alcanzado NO DEBE impedir cerrar, mover o reducir posiciones existentes.

#### Scenario: Tope de pasos alcanzado

- **WHEN** la canasta ya tiene la cantidad máxima de pasos configurada
- **THEN** no se habilitan pasos nuevos aunque el precio alcance la distancia de grid

#### Scenario: Tope de volumen por orden

- **WHEN** el volumen calculado para un paso supera el máximo por orden
- **THEN** se usa el máximo por orden o se rechaza el paso si eso excede el presupuesto de canasta

#### Scenario: Tope agregado en modo portafolio

- **WHEN** la suma del volumen de las tres canastas más el paso nuevo supera `MaxAggregateVolume`
- **THEN** el paso no se envía y las canastas existentes siguen gestionándose

### Requirement: Stop loss obligatorio

Ninguna orden DEBE enviarse sin un stop loss válido y distinto de cero. Si el stop loss calculado no respeta la distancia mínima del broker o el margen disponible es insuficiente, la orden NO DEBE enviarse y el motivo DEBE registrarse.

#### Scenario: Sin stop loss no hay orden

- **WHEN** el stop loss calculado queda dentro del stops level del símbolo
- **THEN** la orden se rechaza y se registra el error, en lugar de enviarse sin protección

#### Scenario: Margen insuficiente

- **WHEN** el margen libre no alcanza para el volumen solicitado
- **THEN** la orden no se envía y la canasta no se modifica

### Requirement: Límite de pérdida diaria

El sistema DEBE comparar la equidad actual con la equidad registrada al inicio del día del servidor. Si la caída supera el porcentaje configurado, DEBE bloquear nuevas entradas hasta el inicio del día siguiente. El valor de referencia DEBE sobrevivir a un reinicio del terminal. En modo `ALL` el límite es de la instancia completa, no por estrategia.

#### Scenario: Límite diario alcanzado

- **WHEN** la equidad cae más que el porcentaje diario configurado respecto del inicio del día
- **THEN** no se abren canastas nuevas hasta el día siguiente y las posiciones abiertas siguen gestionándose

#### Scenario: Reinicio dentro del mismo día

- **WHEN** el terminal se reinicia después de alcanzar el límite diario, el mismo día del servidor
- **THEN** el bloqueo de entradas se mantiene

#### Scenario: Límite diario en modo portafolio

- **WHEN** `Strategy=ALL` alcanza el límite diario de la cuenta
- **THEN** las tres estrategias dejan de abrir y las canastas abiertas siguen gestionándose

### Requirement: Los límites no interrumpen la gestión

Cuando un límite de riesgo y una acción de gestión coinciden en el mismo tick, el sistema DEBE ejecutar primero la gestión de las posiciones abiertas: cierre por stop, take profit, trailing o reducción de exposición.

#### Scenario: Guard y cierre simultáneos

- **WHEN** el límite diario está activo y una canasta alcanza su stop loss de canasta
- **THEN** el cierre se ejecuta igual y solo se bloquean las aperturas

### Requirement: Riesgo automático por volatilidad

En modo `Auto`, el riesgo vivo DEBE calcularse como:

```
factor_vol = clamp(ATR_medio / ATR_actual, VolFactorMin, VolFactorMax)
riesgo     = clamp(RiskPct * factor_vol, 0.5, AutoRiskMaxPct)
```

El resultado DEBE redondearse a dos decimales. `ATR_actual` y `ATR_medio` DEBEN provenir de la última barra cerrada; si no hay lectura válida, `factor_vol` DEBE ser `1.0`. La base de la fórmula DEBE ser el input `RiskPct` cuando el EA inicia en `Auto`, o el riesgo vivo capturado al entrar en modo `Auto` desde `Manual`; mientras permanezca en `Auto`, esa base NO DEBE recalcularse con los valores automáticos sucesivos. El tope superior DEBE ser el input `AutoRiskMaxPct`, con valor por defecto 6.0 y rango válido 0.5–10.0; el mínimo DEBE permanecer fijo en 0.5. La función de cálculo DEBE sanear el tope a 0.5–10.0. El riesgo automático DEBE recalcularse en cada tick, aunque su valor solo cambie cuando cambie la lectura de ATR.

#### Scenario: Volatilidad actual por encima de la media

- **WHEN** `ATR_actual` es mayor que `ATR_medio` y el modo es automático
- **THEN** `factor_vol` es menor que `1.0` y el riesgo calculado es menor que `RiskPct`

#### Scenario: Volatilidad actual por debajo de la media

- **WHEN** `ATR_actual` es menor que `ATR_medio` y el modo es automático
- **THEN** `factor_vol` es mayor que `1.0` y el riesgo calculado es mayor que `RiskPct`

#### Scenario: Factor acotado

- **WHEN** la razón `ATR_medio / ATR_actual` queda fuera de `VolFactorMin`–`VolFactorMax`
- **THEN** `factor_vol` se acota al límite correspondiente antes de calcular el riesgo

#### Scenario: Riesgo acotado y redondeado

- **WHEN** `RiskPct * factor_vol` da un valor fuera de 0.5–`AutoRiskMaxPct` o con más de dos decimales
- **THEN** el riesgo vivo se acota a 0.5–`AutoRiskMaxPct` y se redondea a dos decimales antes de dimensionar y de mostrarse

#### Scenario: Tope máximo configurado

- **WHEN** `AutoRiskMaxPct` es 3.0 y `RiskPct * factor_vol` da 5.2
- **THEN** el riesgo vivo es 3.0, sin superar el tope configurado

#### Scenario: Base por encima del tope

- **WHEN** el EA inicia en `Auto` con `RiskPct=8.0` y `AutoRiskMaxPct=6.0`
- **THEN** el riesgo vivo del primer tick es como máximo 6.0

#### Scenario: Sin lectura válida de ATR

- **WHEN** el ATR actual o el ATR medio no están disponibles
- **THEN** `factor_vol` es `1.0` y el riesgo vivo es `RiskPct`, acotado a 0.5–`AutoRiskMaxPct`

#### Scenario: Estabilidad dentro de la barra

- **WHEN** la barra en curso todavía no cerró y la lectura de ATR no cambió
- **THEN** el riesgo automático conserva el mismo valor entre ticks

#### Scenario: Base al iniciar en automático

- **WHEN** el EA inicia con `RiskMode=Auto` y `RiskPct=4.0`
- **THEN** la base del cálculo es 4.0 y el primer tick calcula el riesgo automático desde esa base con el ATR vigente

#### Scenario: Base capturada al entrar en automático

- **WHEN** el riesgo manual es 4.0 y el operador conmuta a automático
- **THEN** la base del cálculo es 4.0 y los ticks siguientes recalculan desde esa base, no desde el último riesgo automático

#### Scenario: Vuelta a manual

- **WHEN** el operador conmuta de automático a manual
- **THEN** el riesgo vivo conserva el último valor automático y se usa como punto de partida de los ajustes manuales

#### Scenario: Lote sin doble ajuste por volatilidad

- **WHEN** el modo es automático y hay lectura de ATR
- **THEN** el volumen de la orden se calcula con `factor_volatilidad = 1.0` y la volatilidad incide solo a través del riesgo vivo

### Requirement: Aplicación del riesgo ajustado

El riesgo vivo DEBE aplicarse al dimensionamiento de las órdenes futuras: la apertura de canastas nuevas y cada paso de grid posterior al ajuste, recálculo o cambio de modalidad. Un cambio de riesgo o de modalidad NO DEBE redimensionar posiciones ya abiertas ni alterar su stop loss o take profit. El input `RiskPct` NO DEBE recortarse al iniciar; en modo manual, un valor fuera de 0.5–10 se usa para dimensionar y solo deshabilita los controles de ajuste. En modo automático, el riesgo calculado siempre queda dentro de 0.5–`AutoRiskMaxPct`.

#### Scenario: Próximo paso de grid en modo manual

- **WHEN** una canasta está abierta con tres pasos, el operador sube el riesgo de 4.0 a 4.5 y el precio alcanza el próximo nivel de grid
- **THEN** el nuevo paso se calcula con 4.5% y los tres pasos anteriores conservan su volumen

#### Scenario: Próximo paso de grid en modo automático

- **WHEN** una canasta está abierta y el riesgo automático cambia al cerrar una barra
- **THEN** el próximo paso de grid se calcula con el nuevo riesgo y los pasos anteriores conservan su volumen

#### Scenario: Canasta nueva

- **WHEN** una canasta se cierra después de ajustar el riesgo y la señal abre una canasta nueva
- **THEN** la primera orden se dimensiona con el riesgo vivo vigente

#### Scenario: Input fuera del rango operable en modo manual

- **WHEN** el modo es manual y el input `RiskPct` es 0.08
- **THEN** el dimensionamiento usa 0.08% sin recortarlo y los controles de ajuste quedan deshabilitados

#### Scenario: Presupuesto de canasta agotado

- **WHEN** el riesgo vigente hace que la pérdida proyectada del próximo paso supere `MaxBasketLossPct`
- **THEN** el paso se rechaza y la canasta conserva sus posiciones, en lugar de reducir el volumen del paso
