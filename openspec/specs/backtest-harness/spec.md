# backtest-harness Specification

## Purpose

Permite comparar el motor nuevo contra la referencia MT4 y medir el riesgo real de cada corrida, para que la migración sea verificable en lugar de una promesa.

## Requirements

### Requirement: Exportación de señales

El sistema DEBE poder exportar un CSV con una fila por señal evaluada, con al menos: fecha y hora del servidor, estrategia, dirección resultante y timeframe.

#### Scenario: Corrida con exportación activa

- **WHEN** se ejecuta un backtest con la exportación habilitada
- **THEN** se genera un CSV ordenado por fecha con todas las señales evaluadas, incluidas las que devolvieron `NONE`

### Requirement: Comparación de paridad de señales

El sistema DEBE comparar el CSV del motor nuevo contra el CSV de referencia del MT4 y DEBE informar la cantidad de señales coincidentes, las faltantes y las sobrantes.

#### Scenario: Paridad completa

- **WHEN** ambos CSV tienen la misma secuencia de fechas y direcciones
- **THEN** el reporte indica cero diferencias y la migración de señales se considera validada

#### Scenario: Diferencia por el gate de barra

- **WHEN** el motor nuevo evalúa una barra que la referencia MT4 no evaluó por su retorno temprano
- **THEN** esa señal aparece como sobrante y queda registrada en el reporte, sin abortar la corrida

### Requirement: Comparación de portafolio

Cuando la corrida usa `Strategy=ALL`, el sistema DEBE permitir comparar la curva de equidad y las métricas de la cuenta contra el ledger combinado del MT4, además de la paridad de señales por estrategia.

#### Scenario: Portafolio contra el MT4

- **WHEN** se compara una corrida `ALL` contra la referencia MT4 de la misma ventana, feed, spread y capital
- **THEN** el reporte muestra el Net, el drawdown y la exposición de la cuenta, y el desglose por estrategia

### Requirement: Métricas de riesgo en OnTester

El sistema DEBE calcular y exponer al menos: drawdown máximo, exposición máxima en volumen, cantidad máxima de pasos de grid alcanzada y cantidad de veces que se alcanzó el límite diario. En modo `ALL` DEBE exponer además las métricas de portafolio y la atribución por estrategia (Net, drawdown y exposición por magic).

#### Scenario: Corrida que alcanza el límite diario

- **WHEN** una corrida activa el límite de pérdida diaria al menos una vez
- **THEN** el resultado de `OnTester` incluye ese conteo y el día en que ocurrió

#### Scenario: Atribución en modo portafolio

- **WHEN** una corrida usa `Strategy=ALL`
- **THEN** el resultado incluye las métricas totales de la cuenta y el desglose por estrategia, y la suma de los desgloses reconcilia con el total

### Requirement: Corridas deterministas

Una corrida DEBE depender solo de los datos históricos y de los parámetros de entrada. El sistema NO DEBE usar la hora local, variables globales del terminal ni estado persistido entre corridas para decidir operaciones.

#### Scenario: Misma corrida, mismo resultado

- **WHEN** se repite un backtest con el mismo símbolo, período, modelo de ticks y parámetros
- **THEN** las señales, las operaciones y las métricas son idénticas

### Requirement: Artefacto por corrida

Cada corrida DEBE generar un archivo identificable por configuración de estrategia (incluido `ALL`), símbolo, timeframe y fecha, sin sobrescribir el resultado de una corrida anterior.

#### Scenario: Dos corridas el mismo día

- **WHEN** se ejecutan dos backtests de la misma estrategia el mismo día con parámetros distintos
- **THEN** se generan dos archivos distintos y ninguno reemplaza al otro
