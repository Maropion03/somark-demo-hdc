# SoScan 构建/部署封装 (Windows / PowerShell)
# 用法: .\dev.ps1 {build|install|launch|run|log|devices}
# 内联 DevEco 工具链环境,不污染全局 shell。

param(
    [Parameter(Position = 0)]
    [string]$Command,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = 'Stop'

$DEVECO = 'C:\Program Files\Huawei\DevEco Studio'
$env:DEVECO_SDK_HOME = Join-Path $DEVECO 'sdk'
$HVIGORW  = Join-Path $DEVECO 'tools\hvigor\bin\hvigorw.bat'
$HDC      = Join-Path $DEVECO 'sdk\default\openharmony\toolchains\hdc.exe'
$NODE_BIN = Join-Path $DEVECO 'tools\node'
$JBR      = Join-Path $DEVECO 'jbr'

$PROJ    = $PSScriptRoot
$HAP     = Join-Path $PROJ 'entry\build\default\outputs\default\entry-default-signed.hap'
$BUNDLE  = 'ai.somark.demo'
$ABILITY = 'EntryAbility'

foreach ($p in @($HVIGORW, $HDC, $NODE_BIN, $JBR)) {
    if (-not (Test-Path $p)) { throw "未找到: $p (请确认 DevEco Studio 安装路径)" }
}

function Invoke-Build {
    $env:JAVA_HOME = $JBR
    $env:PATH = "$NODE_BIN;$JBR\bin;$env:PATH"
    Push-Location $PROJ
    try { & $HVIGORW assembleHap; if ($LASTEXITCODE -ne 0) { throw "build 失败 (exit $LASTEXITCODE)" } }
    finally { Pop-Location }
}

function Invoke-Install {
    if (-not (Test-Path $HAP)) { throw "未找到 HAP: $HAP (先跑 build)" }
    & $HDC install $HAP
    if ($LASTEXITCODE -ne 0) { throw "install 失败 (exit $LASTEXITCODE)" }
}

function Invoke-Launch {
    & $HDC shell aa start -a $ABILITY -b $BUNDLE
    if ($LASTEXITCODE -ne 0) { throw "launch 失败 (exit $LASTEXITCODE)" }
}

switch ($Command) {
    'build'   { Invoke-Build }
    'install' { Invoke-Install }
    'launch'  { Invoke-Launch }
    'run'     { Invoke-Build; Invoke-Install; Invoke-Launch }
    'log'     { & $HDC hilog @Rest }
    'devices' { & $HDC list targets }
    default   { Write-Host "用法: .\dev.ps1 {build|install|launch|run|log|devices}"; exit 1 }
}
