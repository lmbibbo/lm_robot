<#
.SYNOPSIS
    Compila un archivo MQL5 con MetaEditor y devuelve un codigo de salida confiable.

.DESCRIPTION
    MetaEditor64.exe no usa el codigo de salida para reportar errores (devuelve 1
    en compilaciones correctas y 0 en compilaciones con errores). Por eso este
    script espera al proceso, lee el log Unicode y decide en base a la linea
    "Result: N errors, M warnings".

.PARAMETER Source
    Ruta del archivo .mq5 a compilar. Por defecto EA\LmRobot-H1.mq5.

.PARAMETER MetaEditor
    Ruta explicita a MetaEditor64.exe. Si se omite, se detecta desde origin.txt
    del terminal o desde las instalaciones habituales.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\build.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\build.ps1 -Source tests\TestRunner.mq5
#>
[CmdletBinding()]
param(
    [string]$Source,
    [string]$MetaEditor
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

function Resolve-MetaEditorPath {
    param([string]$Explicit)

    if ($Explicit) {
        if (-not (Test-Path -LiteralPath $Explicit)) {
            throw "No existe MetaEditor en la ruta indicada: $Explicit"
        }
        return (Resolve-Path -LiteralPath $Explicit).Path
    }

    if ($env:LMROBOT_METAEDITOR -and (Test-Path -LiteralPath $env:LMROBOT_METAEDITOR)) {
        return (Resolve-Path -LiteralPath $env:LMROBOT_METAEDITOR).Path
    }

    # repoRoot = <terminal-data>\MQL5\Experts\lm_robot
    $dataDir = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $repoRoot))
    $origin = Join-Path $dataDir 'origin.txt'
    if (Test-Path -LiteralPath $origin) {
        $install = (Get-Content -LiteralPath $origin -Raw).Trim()
        $candidate = Join-Path $install 'MetaEditor64.exe'
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    $fallbacks = @(
        'C:\Program Files\MetaTrader 5\MetaEditor64.exe',
        'C:\Program Files\MetaTrader\MetaEditor64.exe',
        'C:\Program Files\FBS MetaTrader 5\MetaEditor64.exe'
    )
    foreach ($candidate in $fallbacks) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "No se encontro MetaEditor64.exe. Use -MetaEditor o defina LMROBOT_METAEDITOR."
}

if (-not $Source) {
    $Source = Join-Path $repoRoot 'EA\LmRobot-H1.mq5'
}
elseif (-not [System.IO.Path]::IsPathRooted($Source)) {
    $Source = Join-Path $repoRoot $Source
}

if (-not (Test-Path -LiteralPath $Source)) {
    throw "No existe el archivo a compilar: $Source"
}

$Source = (Resolve-Path -LiteralPath $Source).Path
$logPath = [System.IO.Path]::ChangeExtension($Source, '.log')
$compiler = Resolve-MetaEditorPath -Explicit $MetaEditor

Write-Host "Compilando: $Source"
Write-Host "MetaEditor: $compiler"

$arguments = @("/compile:`"$Source`"", "/log:`"$logPath`"")
$process = Start-Process -FilePath $compiler -ArgumentList $arguments -Wait -PassThru

if (-not (Test-Path -LiteralPath $logPath)) {
    throw "MetaEditor no genero el log esperado: $logPath"
}

$content = Get-Content -LiteralPath $logPath -Raw -Encoding Unicode
$lines = $content -split "`r?`n"

$errors = -1
$warnings = -1
foreach ($line in $lines) {
    if ($line -match '^Result:\s*(\d+)\s+errors?,\s*(\d+)\s+warnings?') {
        $errors = [int]$Matches[1]
        $warnings = [int]$Matches[2]
    }
}

if ($errors -lt 0) {
    Write-Host "No se pudo interpretar el resultado. Contenido del log:" -ForegroundColor Red
    Write-Host $content
    throw "Compilacion sin linea 'Result:' en el log"
}

$diagnostics = $lines | Where-Object { $_ -match ':\s+(error|warning)\s+\d+:' }
foreach ($diagnostic in $diagnostics) {
    $color = if ($diagnostic -match ':\s+error\s+\d+:') { 'Red' } else { 'Yellow' }
    Write-Host $diagnostic -ForegroundColor $color
}

Write-Host ("Resultado: {0} error(es), {1} warning(s)" -f $errors, $warnings)

if ($errors -gt 0) {
    exit 1
}

exit 0
