# Spec Delta

## Purpose

Define las reglas de entrada de cada estrategia como funciones puras y testeables, separadas del tamaño de la orden, del stop loss y de la ejecución.

## ADDED Requirements

### Requirement: La señal solo devuelve dirección

Toda señal DEBE devolver únicamente `BUY`, `SELL` o `NONE`. La señal NO DEBE calcular volumen, stop loss, take profit, magic number ni decidir si la orden se envía.

#### Scenario: Señal sin efecto de ejecución

- **WHEN** se evalúa una señal
- **THEN** el resultado es una dirección o `NONE`, y evaluar la misma señal dos veces con las mismas entradas produce el mismo resultado

### Requirement: Señal de Scalper Pro

La estrategia Scalper Pro DEBE devolver `SELL` cuando el cierre de la barra 2 es mayor que el cierre de la barra 1, y `BUY` en caso contrario. La evaluación DEBE hacerse sobre barras cerradas del timeframe del gráfico.

#### Scenario: Barra bajista

- **WHEN** `close[2] > close[1]` al cierre de una barra
- **THEN** la señal es `SELL`

#### Scenario: Barra alcista

- **WHEN** `close[2] <= close[1]` al cierre de una barra
- **THEN** la señal es `BUY`

### Requirement: Señal de Fibonacci Focus

La estrategia Fibonacci Focus DEBE conservar la regla de la referencia MT4: si `high[1] > low[2]` devuelve `SELL` cuando el RSI del timeframe del gráfico (período 14, desplazamiento 1) es mayor que 30; si `high[1] <= low[2]` devuelve `BUY` cuando ese RSI es menor que 70. Fuera de esas condiciones DEBE devolver `NONE`.

#### Scenario: Rama de venta

- **WHEN** `high[1] > low[2]` y `RSI(14, 1) > 30`
- **THEN** la señal es `SELL`

#### Scenario: Rama de compra

- **WHEN** `high[1] <= low[2]` y `RSI(14, 1) < 70`
- **THEN** la señal es `BUY`

#### Scenario: Filtro RSI bloquea

- **WHEN** `high[1] > low[2]` y `RSI(14, 1) <= 30`
- **THEN** la señal es `NONE`

### Requirement: Señal de TrendMaster

La estrategia TrendMaster DEBE devolver `SELL` cuando `close[2] > close[1]` y el RSI (período 14, desplazamiento 1) es mayor que 30. DEBE devolver `BUY` cuando `close[2] <= close[1]` y el RSI es menor que 70. Fuera de esas condiciones DEBE devolver `NONE`.

#### Scenario: Venta confirmada por RSI

- **WHEN** `close[2] > close[1]` y `RSI(14, 1) > 30`
- **THEN** la señal es `SELL`

#### Scenario: Compra bloqueada por RSI

- **WHEN** `close[2] <= close[1]` y `RSI(14, 1) >= 70`
- **THEN** la señal es `NONE`

### Requirement: Evaluación sobre barras cerradas

Las señales DEBE evaluarse una sola vez por barra cerrada y NO DEBE usar la barra en formación (índice 0) para decidir la dirección.

#### Scenario: Sin repintado

- **WHEN** llega un tick dentro de una barra ya evaluada
- **THEN** la señal no se recalcula y la dirección no cambia hasta el cierre de la barra siguiente

#### Scenario: Misma barra, mismo resultado

- **WHEN** dos evaluaciones ocurren sobre la misma barra cerrada con los mismos datos
- **THEN** ambas devuelven la misma dirección
