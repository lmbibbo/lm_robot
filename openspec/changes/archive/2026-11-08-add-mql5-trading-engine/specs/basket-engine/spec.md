# Spec Delta

## Purpose

Mantiene el estado de una canasta de posiciones por estrategia y define cuándo corresponde un paso de grid, cómo se calcula el take profit y cómo se protege la canasta completa.

## ADDED Requirements

### Requirement: Precio promedio ponderado

El precio promedio de la canasta DEBE calcularse como la suma de `precio de apertura * volumen` dividida por el volumen total. El take profit y el stop loss de canasta DEBE derivarse de ese promedio, no de la última orden.

#### Scenario: Promedio con volúmenes distintos

- **WHEN** la canasta tiene 0.01 lotes a 1.0000 y 0.02 lotes a 1.0010
- **THEN** el precio promedio es 1.0007 y el take profit se calcula desde ese valor

### Requirement: Disparo del paso de grid

El sistema DEBE habilitar un nuevo paso de grid cuando el precio se aleja del precio de la última orden de la canasta al menos la distancia configurada, en la dirección que agrava la posición. La habilitación NO DEBE implicar apertura: la política de riesgo decide después.

#### Scenario: Compra que cae

- **WHEN** la canasta es de compra y el precio actual está al menos `GridStepPips` por debajo de la última compra
- **THEN** el paso de grid queda habilitado para evaluación de riesgo

#### Scenario: Compra que sube

- **WHEN** la canasta es de compra y el precio no alcanzó la distancia de grid
- **THEN** no se habilita ningún paso nuevo

### Requirement: Take profit de canasta

Todas las posiciones de la canasta DEBE compartir un take profit calculado desde el precio promedio ponderado: por encima para compras y por debajo para ventas. La distancia DEBE expresarse en pips.

#### Scenario: Actualización tras un nuevo paso

- **WHEN** se abre un nuevo paso de grid
- **THEN** el take profit de todas las posiciones de la canasta se recalcula desde el nuevo promedio ponderado

### Requirement: Stop loss de canasta

Todas las posiciones de la canasta DEBE compartir un stop loss calculado desde el precio promedio ponderado: por debajo para compras y por encima para ventas. El stop loss DEBE enviarse al broker en cada posición y DEBE respetar el stops level mínimo del símbolo.

#### Scenario: Protección del lado del broker

- **WHEN** la canasta queda abierta y el terminal se desconecta
- **THEN** cada posición conserva en el broker un stop loss que limita la pérdida de la canasta

## MODIFIED Requirements

### Requirement: Identidad de la canasta

La canasta DEBE agrupar únicamente posiciones del símbolo actual cuyo magic number coincide con el de la estrategia que la gestiona. Las posiciones de otras estrategias u otros expertos NO DEBE contarse, promediarse ni modificarse. En modo `ALL` DEBE existir una canasta por estrategia.

#### Scenario: Posiciones ajenas ignoradas

- **WHEN** existen posiciones del mismo símbolo con otro magic number
- **THEN** el conteo, el volumen y el precio promedio de la canasta no las incluyen

#### Scenario: Tres canastas en modo portafolio

- **WHEN** `Strategy=ALL` y las tres estrategias tienen posiciones abiertas en el mismo símbolo
- **THEN** cada canasta agrupa solo las posiciones de su magic y no comparte promedio ni conteo

### Requirement: Dirección única

Mientras una canasta tenga posiciones abiertas, el sistema NO DEBE abrir posiciones en la dirección opuesta dentro de esa canasta. La canasta solo puede crecer en la dirección de la primera orden. La regla es por canasta: en modo `ALL` dos estrategias pueden mantener canastas de direcciones opuestas y cada una se gestiona por separado.

#### Scenario: Canasta de compra

- **WHEN** la canasta tiene posiciones de compra abiertas y la señal indica venta
- **THEN** no se abre ninguna posición de venta y la canasta permanece de compra

#### Scenario: Canastas opuestas en modo portafolio

- **WHEN** `Strategy=ALL` y Scalper tiene una canasta de compra mientras TrendMaster tiene una de venta
- **THEN** cada canasta conserva su dirección y se gestiona con su propio promedio, TP y SL

### Requirement: Ciclo de vida de la canasta

Cada canasta DEBE distinguir tres estados: sin posiciones, canasta abierta y canasta recién cerrada. Sin posiciones DEBE permitir la primera orden; con posiciones DEBE permitir solo pasos de grid; al quedar plana DEBE reiniciar el estado y el contador de pasos.

#### Scenario: Reinicio después del cierre

- **WHEN** la última posición de la canasta se cierra por take profit, stop loss o cierre manual
- **THEN** el contador de pasos, el promedio y la dirección se reinician y la próxima señal puede abrir una canasta nueva
