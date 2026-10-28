<#
.SYNOPSIS
    Android TV エミュレータ起動スクリプト
.DESCRIPTION
    指定した AVD を起動し、GUI 表示およびブート完了（sys.boot_completed）までを監視します。
#>
[CmdletBinding()]
param(
    [string]$AvdName = "AndroidTV_1080p",
    [switch]$ColdBoot,
    [switch]$WipeData,
    [switch]$Force,
    [switch]$NoWait,
    [int]$TimeoutSec = 180,
    [string]$Scale
)

$ErrorActionPreference = 'Stop'

$sdk = "C:\Users\mira\AppData\Local\Android\Sdk"
$jdk = "C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot"
$emulatorExe = Join-Path $sdk "emulator\emulator.exe"
$adbExe = Join-Path $sdk "platform-tools\adb.exe"

if (-not (Test-Path $emulatorExe)) {
    Write-Error "Emulator not found at: $emulatorExe. Please run setup-env.ps1 first."
    exit 1
}
if (-not (Test-Path $adbExe)) {
    Write-Error "adb not found at: $adbExe"
    exit 1
}

# 起動中チェック
$existing = & $adbExe devices | Select-String -Pattern "(emulator-\d+|127\.0\.0\.1:555\d)\s+device"
if ($existing) {
    Write-Warning "すでに実行中のエミュレータが存在します: $($existing[0].Line.Trim())"
    exit 0
}

if ($WipeData -and -not $Force) {
    Write-Error "-WipeData はユーザーデータを消去します。実行するには -Force を同時に指定してください。"
    exit 1
}

if ($ColdBoot -or $WipeData) {
    if ($TimeoutSec -lt 300) {
        $TimeoutSec = 300
    }
}

# 起動引数の組み立て
$emuArgs = @("-avd", $AvdName, "-gpu", "auto")
if ($ColdBoot) {
    $emuArgs += "-no-snapshot-load"
}
if ($WipeData) {
    $emuArgs += "-wipe-data"
}
if ($Scale) {
    $emuArgs += @("-scale", $Scale)
}

Write-Host "=== Android TV Emulator 起動開始: $AvdName ===" -ForegroundColor Cyan
Write-Host "オプション: $($emuArgs -join ' ')"

$origJavaHome = $env:JAVA_HOME
$origPath = $env:Path

try {
    $env:JAVA_HOME = $jdk
    $env:Path = "$jdk\bin;$env:Path"

    # エミュレータをバックグラウンドプロセスとして起動
    $proc = Start-Process -FilePath $emulatorExe -ArgumentList $emuArgs -PassThru

    if ($NoWait) {
        Write-Host "エミュレータを非同期で起動しました (PID: $($proc.Id))。" -ForegroundColor Green
        exit 0
    }

    Write-Host "ブート完了を待機中 (最大 $TimeoutSec 秒)..." -ForegroundColor Yellow
    $startTime = [DateTime]::UtcNow
    $bootCompleted = $false

    while (([DateTime]::UtcNow - $startTime).TotalSeconds -lt $TimeoutSec) {
        # プロセス生死チェック
        if ($proc.HasExited) {
            Write-Error "エミュレータプロセスが予期せず終了しました (ExitCode: $($proc.ExitCode))。"
            exit 1
        }

        # adb wait-for-device 状態確認
        $devs = & $adbExe devices 2>$null
        $targetDev = ($devs | Select-String -Pattern "(emulator-\d+|127\.0\.0\.1:555\d)\s+device")
        if (-not $targetDev) {
            & $adbExe connect 127.0.0.1:5555 | Out-Null
            $devs = & $adbExe devices 2>$null
            $targetDev = ($devs | Select-String -Pattern "(emulator-\d+|127\.0\.0\.1:555\d)\s+device")
        }
        
        if ($targetDev) {
            $devName = ($targetDev[0].Line -split '\s+')[0]
            $bootProp = (& $adbExe -s $devName shell getprop sys.boot_completed 2>$null).Trim()
            $animProp = (& $adbExe -s $devName shell getprop init.svc.bootanim 2>$null).Trim()

            # sys.boot_completed が 1、かつ bootanim が停止または未実行（スナップショット復帰時）
            if ($bootProp -eq "1" -and ($animProp -eq "stopped" -or [string]::IsNullOrWhiteSpace($animProp))) {
                $bootCompleted = $true
                break
            }
        }
        Start-Sleep -Seconds 3
    }

    if ($bootCompleted) {
        Write-Host "=== エミュレータのブートが正常に完了しました ($devName) ===" -ForegroundColor Green
        exit 0
    } else {
        Write-Error "タイムアウト ($TimeoutSec 秒): エミュレータの起動完了を確認できませんでした。"
        exit 1
    }
} finally {
    $env:JAVA_HOME = $origJavaHome
    $env:Path = $origPath
}
