<#
.SYNOPSIS
    Android TV アプリ (APK) インストールスクリプト
.DESCRIPTION
    指定された APK をエミュレータにインストール（-r -g）し、必要に応じて TV 向けに起動します。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ApkPath,
    [switch]$Launch,
    [string]$PackageName
)

$ErrorActionPreference = 'Stop'

$sdk = "C:\Users\mira\AppData\Local\Android\Sdk"
$adbExe = Join-Path $sdk "platform-tools\adb.exe"
$aapt2Exe = Join-Path $sdk "build-tools\34.0.0\aapt2.exe"

if (-not (Test-Path $ApkPath)) {
    Write-Error "指定された APK ファイルが存在しません: $ApkPath"
    exit 1
}
$fullApkPath = (Resolve-Path $ApkPath).Path

if (-not (Test-Path $adbExe)) {
    Write-Error "adb not found at: $adbExe"
    exit 1
}

# 稼働中のデバイス確認
$devicesOutput = & $adbExe devices
$emuDevices = $devicesOutput | Select-String -Pattern "(emulator-\d+|127\.0\.0\.1:555\d)\s+device"

if (-not $emuDevices) {
    & $adbExe connect 127.0.0.1:5555 | Out-Null
    $devicesOutput = & $adbExe devices
    $emuDevices = $devicesOutput | Select-String -Pattern "(emulator-\d+|127\.0\.0\.1:555\d)\s+device"
}

if (-not $emuDevices) {
    Write-Error "接続中の Android エミュレータが見つかりません。先に start-tv.ps1 で起動してください。"
    exit 1
}
$targetDev = ($emuDevices[0].Line -split '\s+')[0]

Write-Host "=== APK インストール開始 ===" -ForegroundColor Cyan
Write-Host "対象デバイス: $targetDev"
Write-Host "APK ファイル: $fullApkPath"

# パッケージ名の自動抽出 (Launch 指定かつ未指定時)
if ($Launch -and [string]::IsNullOrWhiteSpace($PackageName)) {
    if (Test-Path $aapt2Exe) {
        Write-Host "aapt2 からパッケージ名を抽出中..." -ForegroundColor Yellow
        $dump = & $aapt2Exe dump badging "$fullApkPath" 2>$null
        $pkgMatch = $dump | Select-String -Pattern "package:\s+name='([^']+)'"
        if ($pkgMatch) {
            $PackageName = $pkgMatch.Matches[0].Groups[1].Value
            Write-Host "パッケージ名を検出しました: $PackageName" -ForegroundColor Green
        }
    }
    if ([string]::IsNullOrWhiteSpace($PackageName)) {
        Write-Warning "パッケージ名の自動抽出ができませんでした。起動するには -PackageName を明示してください。"
    }
}

# インストール実行
Write-Host "adb install -r -g を実行中..." -ForegroundColor Yellow
$installRes = & $adbExe -s $targetDev install -r -g "$fullApkPath"
Write-Host ($installRes -join "`n")

if ($installRes -notmatch "Success") {
    Write-Error "APK のインストールに失敗しました。"
    exit 1
}

Write-Host "APK インストールが正常に完了しました。" -ForegroundColor Green

# 起動処理
if ($Launch -and -not [string]::IsNullOrWhiteSpace($PackageName)) {
    Write-Host "アプリを起動中 ($PackageName)..." -ForegroundColor Yellow
    # Leanback Launcher カテゴリによる起動
    $monkeyRes = & $adbExe -s $targetDev shell monkey -p $PackageName -c android.intent.category.LEANBACK_LAUNCHER 1 2>$null
    if ($LASTEXITCODE -ne 0 -or $monkeyRes -match "No activities found") {
        # フォールバック (通常起動)
        Write-Host "LEANBACK_LAUNCHER カテゴリが見つからないため、通常起動を試行します..." -ForegroundColor Yellow
        & $adbExe -s $targetDev shell monkey -p $PackageName 1
    }
    Write-Host "アプリ起動コマンドを送信しました。" -ForegroundColor Green
}
