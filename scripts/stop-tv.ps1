<#
.SYNOPSIS
    Android TV エミュレータ停止スクリプト
.DESCRIPTION
    実行中のエミュレータに対して安全な停止 (adb emu kill) を発行し、プロセス終了を確認します。
#>
[CmdletBinding()]
param(
    [int]$TimeoutSec = 30,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$sdk = "C:\Users\mira\AppData\Local\Android\Sdk"
$adbExe = Join-Path $sdk "platform-tools\adb.exe"

if (-not (Test-Path $adbExe)) {
    Write-Error "adb not found at: $adbExe"
    exit 1
}

Write-Host "=== Android TV Emulator 停止処理 ===" -ForegroundColor Cyan

# 稼働中のデバイス検出
$devicesOutput = & $adbExe devices
$emuDevices = $devicesOutput | Select-String -Pattern "(emulator-\d+|127\.0\.0\.1:555\d)\s+device"

if (-not $emuDevices) {
    & $adbExe connect 127.0.0.1:5555 | Out-Null
    $devicesOutput = & $adbExe devices
    $emuDevices = $devicesOutput | Select-String -Pattern "(emulator-\d+|127\.0\.0\.1:555\d)\s+device"
}

if (-not $emuDevices) {
    Write-Warning "実行中のエミュレータは見つかりませんでした。"
    exit 0
}

foreach ($devLine in $emuDevices) {
    $devId = ($devLine.Line -split '\s+')[0]
    Write-Host "エミュレータ ($devId) を停止します..." -ForegroundColor Yellow
    & $adbExe -s $devId emu kill
}

Write-Host "プロセスの終了待機中 (最大 $TimeoutSec 秒)..." -ForegroundColor Yellow
$startTime = [DateTime]::UtcNow
$stopped = $false

while (([DateTime]::UtcNow - $startTime).TotalSeconds -lt $TimeoutSec) {
    $emuProcs = Get-Process -Name "emulator", "qemu-system-x86_64" -ErrorAction SilentlyContinue
    if (-not $emuProcs) {
        $stopped = $true
        break
    }
    Start-Sleep -Seconds 2
}

if ($stopped) {
    Write-Host "エミュレータは正常に停止しました。" -ForegroundColor Green
    exit 0
} else {
    if ($Force) {
        Write-Warning "タイムアウトのため、残存プロセスを強制終了します。"
        Get-Process -Name "emulator", "qemu-system-x86_64" -ErrorAction SilentlyContinue | Stop-Process -Force
        Write-Host "強制終了を完了しました。" -ForegroundColor Green
        exit 0
    } else {
        Write-Error "エミュレータの停止がタイムアウトしました。強制終了する場合は -Force を指定してください。"
        exit 1
    }
}
