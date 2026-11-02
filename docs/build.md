# Build y layout del proyecto

## Requisitos

- MetaTrader 5 instalado con MetaEditor 5 (`MetaEditor64.exe`).
- PowerShell 5.1 o superior (viene con Windows).

El proyecto vive dentro de la carpeta de datos de un terminal
(`<datos>\MQL5\Experts\lm_robot`). El compilador se resuelve solo, en este orden:

1. Parámetro `-MetaEditor <ruta>`.
2. Variable de entorno `LMROBOT_METAEDITOR`.
3. El archivo `origin.txt` de la carpeta de datos, tres niveles arriba del repo.
4. Rutas de instalación habituales.

## Layout

```
EA/                      Expert Advisor principal (LmRobot.mq5)
Include/LmRobot/         Módulos del motor, incluidos con #include
  Core/                  Contexto de mercado, utilidades, snapshot
  Risk/                  Cálculo de lote, límites y guardas
  Execution/             Envío y gestión de órdenes
  Strategies/            Estrategias de entrada y salida
  UI/                    Panel de estado en el gráfico
tests/                   Harness de pruebas (TestRunner.mq5)
tools/build.ps1          Compilador con código de salida confiable
docs/                    Documentación del proyecto
openspec/                Planificación del cambio (propuesta, diseño, specs, tareas)
```

Los módulos se incluyen con la ruta relativa a `Include/`, por ejemplo
`#include <LmRobot/Risk/LotSizing.mqh>`.

## Compilar el EA

Desde la raíz del repositorio:

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build.ps1
```

Salida esperada cuando compila bien:

```
Compilando: ...\EA\LmRobot.mq5
MetaEditor: C:\Program Files\FBS MetaTrader 5\MetaEditor64.exe
Resultado: 0 error(es), 0 warning(s)
```

y el código de salida del proceso es `0`. Si hay errores, el script los imprime y
devuelve `1`, así que sirve para encadenar en CI.

## Compilar las pruebas

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build.ps1 -Source tests\TestRunner.mq5
```

## Por qué hay un script y no se llama al compilador directo

`MetaEditor64.exe` no usa el código de salida para reportar el resultado: devuelve
`1` cuando la compilación es correcta y `0` cuando hay errores. Por eso
`tools/build.ps1` espera al proceso, lee el log Unicode que genera MetaEditor y
decide en base a la línea `Result: N errors, M warnings`.

## Artefactos

MetaEditor deja el `.ex5` y un `.log` junto a cada fuente. Ambos están ignorados
por git (`.gitignore`), igual que los artefactos de backtest y del strategy
tester.

## Ejecutar el harness de pruebas

`tests/TestRunner.mq5` compila como Expert Advisor. Se ejecuta adjuntándolo a un
gráfico en MetaTrader 5 (o desde el Strategy Tester) y escribe el resultado en la
pestaña "Expertos" / "Diario" del terminal:

```
PASS  aritmetica entera
...
RESULT: PASS  (4/4 aserciones, 0 fallidas)
```

Con el input `InjectFailure=true` se agrega una aserción falsa a propósito: el
runner reporta `RESULT: FAIL  (4/5 aserciones, 1 fallidas)` y `OnInit` devuelve
`INIT_FAILED`, con lo que el terminal aborta la inicialización. Eso verifica que
el runner falla de verdad cuando una aserción no se cumple.
