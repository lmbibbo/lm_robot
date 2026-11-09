# Cómo reproducir el informe `R11_ALL_P-NS_6m.htm`

Guía para compilar `EA/LmRobot.mq5` y correr el backtest que genera el informe
de referencia R11: portafolio `Strategy=ALL`, AUDCAD H1, 2024 H1, una cuenta de
10.000 USD.

| Campo | Valor |
|---|---|
| Experto | `lm_robot\EA\LmRobot` (`EA/LmRobot.mq5`) |
| Símbolo / timeframe | AUDCAD / H1 |
| Ventana | 2024.01.01 00:00 – 2024.07.01 00:00 |
| Modelo | `Model=2` — Open prices only |
| Depósito / divisa | 10.000 USD |
| Apalancamiento | 1:100 |
| Configuración | `P-NS-ALL.set` (`Strategy=3` = ALL) |
| Informe de referencia | `R11_ALL_P-NS_6m.htm` |

---

## 1. Resultado que se espera obtener

| Métrica del reporte | Valor |
|---|---:|
| Depósito inicial | 10.000,00 |
| Balance final | 13.173,21 |
| **Net** | **+3.173,21 (+31,73 %)** |
| Profit factor | 2,36 |
| Trades | 695 (688 `tp` + 7 `end of test`) |
| Volumen operado | 57,41 lotes |
| Exposición agregada máxima | 3,03 lotes (tope 9,00) |
| Pasos de grid máximos | 5 (tope 19) |
| DD balance | 413,64 (3,36 %) |
| DD equidad | 1.049,40 (8,54 %) |
| `limits_respected` / `aggregate_respected` | SI / SI |

Atribución por magic (debe sumar exactamente el Net):

| Estrategia | Magic | Net | DD máx. | Volumen máx. |
|---|---:|---:|---:|---:|
| Scalper Pro | 202611030 | +1.122,95 | 698,48 | 1,82 |
| Fibonacci Focus | 202611031 | +900,27 | 880,18 | 1,05 |
| TrendMaster | 202611032 | +1.149,99 | 654,62 | 1,51 |
| **Suma** | | **+3.173,21** | | |

> **Invariante principal:** `portfolio_net = final_balance − 10.000` y la suma de
> `attr_*_net` debe dar `portfolio_net`. Si eso se cumple, la corrida es
> consistente aunque el Net varíe unos dólares por diferencias de historial.

---

## 2. Requisitos

1. **MetaTrader 5** instalado. La corrida de referencia usó el terminal de
   **FBS MetaTrader 5** (build 6182).
2. **Cuenta hedging.** `OnInit()` rechaza cuentas netting. En el Strategy Tester
   se usa el modo de margen de la cuenta conectada, así que hay que estar
   logueado en una cuenta demo hedging.
3. **Historial de AUDCAD H1** para 2024.01.01–2024.07.01. Si falta, el tester
   arranca sin barras o con calidad incompleta.
4. **PowerShell** para compilar con `tools/build.ps1`.

### Rutas de esta instalación

| Elemento | Ruta |
|---|---|
| Carpeta de datos del terminal | `C:\Users\palob\AppData\Roaming\MetaQuotes\Terminal\776D2ACDFA4F66FAF3C8985F75FA9FF6` |
| Repositorio / EA | `...\776D2ACDFA4F66FAF3C8985F75FA9FF6\MQL5\Experts\lm_robot` |
| Ejecutable del terminal | `C:\Program Files\FBS MetaTrader 5\terminal64.exe` |
| Sets del Strategy Tester | `...\776D2ACDFA4F66FAF3C8985F75FA9FF6\MQL5\Profiles\Tester` |
| Archivos comunes (CSV) | `C:\Users\palob\AppData\Roaming\MetaQuotes\Terminal\Common\Files` |

En otra máquina, la carpeta de datos se obtiene con **Archivo → Abrir carpeta de
datos** en MetaTrader 5. En los comandos siguientes se llama `<TERMINAL>`.

---

## 3. Preparar la corrida

### 3.1 Compilar el EA

Desde la raíz del repositorio:

```powershell
cd "<TERMINAL>\MQL5\Experts\lm_robot"
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build.ps1
```

Salida esperada:

```text
Compilando: ...\EA\LmRobot.mq5
Resultado: 0 error(es), 0 warning(s)
```

Eso genera `EA\LmRobot.ex5`, que es lo que el tester carga como
`lm_robot\EA\LmRobot`.

> También se puede compilar con MetaEditor (F7), pero el script devuelve un
> código de salida confiable y es el que usa el proyecto.

### 3.2 Copiar el set al directorio del tester

El `.ini` referencia `ExpertParameters=P-NS-ALL.set`, y MetaTrader lo busca en
`MQL5\Profiles\Tester`. Copiar el set del repositorio:

```powershell
Copy-Item `
  "reportes\sets\mt5\P-NS-ALL.set" `
  "<TERMINAL>\MQL5\Profiles\Tester\P-NS-ALL.set" -Force
```

Si el archivo no está (está en `.gitignore`), crearlo con este contenido exacto:

```ini
Strategy=3||3||0||3||N
MagicNumber=202611030||202611030||1||202611030||N
MaxAttempts=3||3||1||3||N
RetryDelayMs=250||250||1||250||N
DeadlineMs=3000||3000||1||3000||N
AtrTimeframe=0||0||1||0||N
AtrPeriod=14||14||1||14||N
MaxSpreadPips=100.0||100.0||1||100.0||N
MaxAtrPips=15.0||15.0||1||15.0||N
MaxBasketLossPct=1000.0||1000.0||1||1000.0||N
DailyLossLimitPct=1000.0||1000.0||1||1000.0||N
MaxGridSteps=19||19||1||19||N
LotMultiplier=1.667||1.667||1||1.667||N
MaxLotPerOrder=9.0||9.0||1||9.0||N
MaxVolumePerStrategy=9.0||9.0||1||9.0||N
TpPips=8.0||8.0||1||8.0||N
GridStepPips=22.0||22.0||1||22.0||N
MaxAggregateLossPct=1000.0||1000.0||1||1000.0||N
MaxAggregateVolume=9.0||9.0||1||9.0||N
UseSessionFilter=false||false||0||true||N
SessionStartHour=8||8||1||80||N
SessionEndHour=17||17||1||170||N
RiskPct=4.0||4.0||1||4.0||N
SlPips=1000.0||1000.0||1||1000.0||N
```

Formato de cada línea: `parametro=valor||inicio||paso||fin||optimizar`.
`N` significa que el parámetro no se optimiza.

### 3.3 Verificar el historial

En MetaTrader 5:

1. Abrir un gráfico **AUDCAD H1**.
2. Desplazarse hasta enero de 2024 (o usar **Herramientas → Centro de historial**)
   para forzar la descarga.
3. Confirmar que existen barras hasta julio de 2024.

Sin historial, el tester puede terminar con pocos ticks y métricas distintas.

### 3.4 Crear el runner `.ini`

Guardar este archivo como `<TERMINAL>\R11_ALL_P-NS_6m.ini`:

```ini
[Tester]
Expert=lm_robot\EA\LmRobot
ExpertParameters=P-NS-ALL.set
Symbol=AUDCAD
Period=H1
Model=2
Optimization=0
FromDate=2024.01.01
ToDate=2024.07.01
ForwardMode=0
Deposit=10000
Currency=USD
Leverage=1:100
ExecutionMode=0
Visual=0
ShutdownTerminal=1
Report=R11_ALL_P-NS_6m
ReplaceReport=1
```

El mismo archivo está versionado en
`reportes/sets/mt5/R11_ALL_P-NS_6m.ini`.

---

## 4. Ejecutar (modo headless)

Cerrar cualquier instancia abierta de MetaTrader 5 y lanzar:

```powershell
Start-Process `
  -FilePath "C:\Program Files\FBS MetaTrader 5\terminal64.exe" `
  -ArgumentList '/config:"<TERMINAL>\R11_ALL_P-NS_6m.ini"' `
  -Wait
```

`ShutdownTerminal=1` hace que el terminal se cierre al terminar el backtest, así
que el comando anterior bloquea hasta que el informe está listo.

En esta instalación la corrida tarda del orden de un minuto con
`Model=2`.

---

## 5. Ejecutar desde la interfaz (alternativa)

Si se prefiere el Strategy Tester visual:

1. **Ver → Strategy Tester** (Ctrl+R).
2. Pestaña **Ajustes**:
   - Experto: `lm_robot\EA\LmRobot`
   - Símbolo: `AUDCAD`
   - Periodo: `H1`
   - Fecha: `2024.01.01` a `2024.07.01`
   - Modelo: **Open prices only**
   - Depósito: `10000`, divisa `USD`
   - Apalancamiento: `1:100`
3. Pestaña **Parámetros de entrada** → **Cargar** →
   `MQL5\Profiles\Tester\P-NS-ALL.set`.
4. **Iniciar**.

El resultado es el mismo que el de la corrida headless.

---

## 6. Dónde quedan los resultados

| Artefacto | Ubicación |
|---|---|
| Informe HTML | `<TERMINAL>\R11_ALL_P-NS_6m.htm` |
| Gráficos del informe | `<TERMINAL>\R11_ALL_P-NS_6m-*.png` |
| CSV de métricas | `...\Terminal\Common\Files\lm_robot_run_Portafolio_ALL_AUDCAD_H1_<fecha>_<id>.csv` |
| CSV diario | `...\Terminal\Common\Files\..._daily.csv` |
| Log del tester | `<TERMINAL>\Tester\logs\<AAAAMMDD>.log` |

El EA escribe los CSV en **Common\Files** (carpeta compartida entre terminales),
no en la carpeta del experto. El nombre incluye la fecha del último tick y un
identificador de corrida; por eso no se puede predecir el nombre exacto.

Para ver el informe, abrir `R11_ALL_P-NS_6m.htm` en el navegador. Las métricas
de cabecera están en las primeras tablas; los deals, al final.

---

## 7. Cómo verificar que la corrida salió bien

### 7.1 En el log

Buscar en `<TERMINAL>\Tester\logs\<AAAAMMDD>.log`:

```text
LM_BACKTEST PORTFOLIO net=3173.21 ... agg_ok=SI strategies=3
LM_BACKTEST ATTR strategy=Scalper Pro magic=202611030 net=1122.95 ...
LM_BACKTEST ATTR strategy=Fibonacci Focus magic=202611031 net=900.27 ...
LM_BACKTEST ATTR strategy=TrendMaster magic=202611032 net=1149.99 ...
```

### 7.2 En el CSV

El CSV de `OnTester` debe contener, entre otras:

```text
final_balance,13173.21
portfolio_net,3173.21
max_aggregate_volume,3.03
aggregate_respected,SI
attr_0_net,1122.95
attr_1_net,900.27
attr_2_net,1149.99
```

### 7.3 Checks mínimos

1. `final_balance − 10000 = portfolio_net`.
2. `attr_0_net + attr_1_net + attr_2_net = portfolio_net`.
3. `aggregate_respected = SI` y `limits_respected = SI`.
4. El HTML muestra 3 magics distintos y 695 trades.
5. Los 7 cierres `end of test` existen al final del ledger.

Si el Net difiere en pocos dólares pero los cinco checks se cumplen, la
diferencia es de feed/spread/historial, no del motor.

---

## 8. Qué significa cada parámetro del set

| Parámetro | Valor | Efecto |
|---|---:|---|
| `Strategy` | `3` | `ALL`: las tres estrategias en una cuenta |
| `MagicNumber` | 202611030 | Base; cada estrategia usa base + índice |
| `RiskPct` | 4.0 | Lote inicial calculado sobre el balance |
| `SlPips` | 1000.0 | SL de canasta muy lejano (paridad con MT4 sin stop) |
| `TpPips` | 8.0 | Take profit de canasta |
| `GridStepPips` | 22.0 | Distancia entre pasos de grid |
| `LotMultiplier` | 1.667 | Multiplicador de volumen por paso |
| `MaxGridSteps` | 19 | Tope de pasos |
| `MaxLotPerOrder` | 9.0 | Tope de volumen por orden |
| `MaxVolumePerStrategy` | 9.0 | Tope de volumen por canasta |
| `MaxAggregateVolume` | 9.0 | Tope de volumen concurrente de la instancia |
| `MaxBasketLossPct` | 1000.0 | Presupuesto por canasta efectivamente apagado |
| `DailyLossLimitPct` | 1000.0 | Límite diario efectivamente apagado |
| `MaxAggregateLossPct` | 1000.0 | Presupuesto agregado efectivamente apagado |
| `MaxSpreadPips` | 100.0 | Filtro de spread permisivo |
| `MaxAtrPips` | 15.0 | Filtro de volatilidad |
| `UseSessionFilter` | false | Sin filtro de sesión |
| `MaxAttempts` / `RetryDelayMs` / `DeadlineMs` | 3 / 250 / 3000 | Ejecución acotada |

`RiskPct=4` con `SlPips=1000` produce el lote base de 0,05 por estrategia que
aparece en el informe.

---

## 9. Problemas frecuentes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `Expert not found` | El `.ex5` no está compilado o la ruta no coincide | Ejecutar `tools\build.ps1` y verificar `EA\LmRobot.ex5` |
| `Set file not found` | `P-NS-ALL.set` no está en `MQL5\Profiles\Tester` | Copiarlo (paso 3.2) |
| `LmRobot: la cuenta no es hedging` | Cuenta netting | Loguearse en una demo hedging |
| Pocos ticks / sin operaciones | Falta historial de AUDCAD | Descargar barras H1 de 2024 |
| No aparece el HTML | El terminal no cerró o `Report` apunta a otra carpeta | Buscar en la raíz de `<TERMINAL>` |
| No aparece el CSV | Se buscó en la carpeta del EA | Buscar en `...\Terminal\Common\Files` |
| Net distinto | Otro build, otro spread o historial distinto | Comparar checks de §7.3 |

---

## 10. Notas

- El informe HTML y los `.set` están en `.gitignore` (`*.htm`, `*.set`). Por eso
  `R11_ALL_P-NS_6m.htm` no aparece en GitHub aunque exista en disco. Solo están
  versionados `reportes/MANIFIESTO.md`, los CSV de R11 y los `.ini`.
- El informe de referencia y sus CSV están archivados en
  `reportes/mt5/R11_ALL_P-NS_6m.htm`, `.csv` y `_daily.csv`.
- Contexto de la comparación contra MT4: `informe6m.md` §5.6 y
  `docs/comparacion-justa.md`.
