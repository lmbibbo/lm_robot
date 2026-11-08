# Spec Delta

## Purpose

Expone el instrumento y el estado de mercado en unidades consistentes, para que todas las decisiones de trading usen la misma referencia sin depender de los dígitos del broker.

## ADDED Requirements

### Requirement: Unidades del instrumento normalizadas

El sistema DEBE derivar el tamaño del pip, el valor del pip y el valor del tick desde las propiedades del símbolo. Todas las distancias configurables DEBE expresarse en pips y convertirse a puntos solo en el límite de ejecución.

#### Scenario: Símbolo de 5 dígitos

- **WHEN** el símbolo tiene 5 dígitos
- **THEN** 1 pip equivale a 10 puntos y una distancia configurada de 20 pips equivale a 200 puntos

#### Scenario: Símbolo de 4 dígitos

- **WHEN** el símbolo tiene 4 dígitos
- **THEN** 1 pip equivale a 1 punto y la misma distancia de 20 pips equivale a 20 puntos

#### Scenario: Símbolo de 3 dígitos

- **WHEN** el símbolo tiene 3 dígitos (par con JPY)
- **THEN** 1 pip equivale a 10 puntos

### Requirement: Snapshot de mercado consistente

En cada tick el sistema DEBE leer bid, ask, spread, stops level y ATR una sola vez, y reutilizar esos valores durante todo el ciclo de decisión.

#### Scenario: Mismo bid y ask en todo el ciclo

- **WHEN** se procesa un tick
- **THEN** la señal, la política de riesgo y la ejecución usan el mismo par bid/ask leído al inicio del ciclo

### Requirement: Filtro de spread explícito

El sistema DEBE bloquear nuevas entradas cuando el spread supera el máximo configurado. El filtro NO DEBE cerrar, mover ni modificar posiciones abiertas.

#### Scenario: Spread por encima del máximo

- **WHEN** el spread actual supera el máximo configurado
- **THEN** no se abren órdenes nuevas y las posiciones abiertas conservan su stop loss y take profit

#### Scenario: Spread vuelve a rango

- **WHEN** el spread vuelve a estar por debajo del máximo
- **THEN** las entradas quedan habilitadas en el siguiente tick

### Requirement: Régimen de volatilidad informado

El sistema DEBE exponer un indicador de volatilidad alta calculado como ATR en pips. El indicador NO DEBE decidir por sí mismo el destino de las posiciones abiertas.

#### Scenario: Volatilidad alta detectada

- **WHEN** el ATR supera el máximo configurado
- **THEN** el indicador de volatilidad alta queda activo y solo se impide abrir entradas nuevas
