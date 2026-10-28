<#
.SYNOPSIS
    Android TV エミュレータ環境のセットアップと AVD 作成スクリプト
.DESCRIPTION
    Android SDK の emulator、Android TV システムイメージをダウンロードし、
    tv_1080p AVD (AndroidTV_1080p) を作成して config.ini を最適化します。
#>
[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { Join-Path $env:LOCALAPPDATA "Android\Sdk" }
$jdk = "C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot"
$avdName = "AndroidTV_1080p"
$targetSystemImage = "system-images;android-34;android-tv;x86"
$deviceProfile = "tv_1080p"

Write-Host "=== Android TV Emulator Setup ===" -ForegroundColor Cyan

# 依存チェック
if (-not (Test-Path $sdk)) {
    Write-Error "Android SDK not found at: $sdk"
    exit 1
}
if (-not (Test-Path $jdk)) {
    Write-Error "JDK 17 not found at: $jdk"
    exit 1
}

$origJavaHome = $env:JAVA_HOME
$origPath = $env:Path

try {
    $env:JAVA_HOME = $jdk
    $env:Path = "$jdk\bin;$env:Path"

    $sdkmanager = Join-Path $sdk "cmdline-tools\latest\bin\sdkmanager.bat"
    $avdmanager = Join-Path $sdk "cmdline-tools\latest\bin\avdmanager.bat"

    Write-Host "[1/5] ライセンスの同意確認..." -ForegroundColor Yellow
    # 自動同意
    $yesProcess = Start-Process -FilePath "cmd.exe" -ArgumentList "/c echo y | `"$sdkmanager`" --licenses" -NoNewWindow -PassThru -Wait
    
    Write-Host "[2/5] emulator および Android TV システムイメージのインストール..." -ForegroundColor Yellow
    Write-Host "対象パッケージ: emulator, $targetSystemImage"
    & $sdkmanager "emulator" $targetSystemImage
    if ($LASTEXITCODE -ne 0) {
        Write-Error "SDK パッケージのインストールに失敗しました (ExitCode: $LASTEXITCODE)"
        exit $LASTEXITCODE
    }

    $emulatorExe = Join-Path $sdk "emulator\emulator.exe"
    if (Test-Path $emulatorExe) {
        Write-Host "[3/5] ハードウェアアクセラレーション (WHPX) チェック..." -ForegroundColor Yellow
        & $emulatorExe -accel-check
    }

    Write-Host "[4/5] AVD ($avdName) の作成..." -ForegroundColor Yellow
    $forceArg = if ($Force) { "--force" } else { "" }
    & cmd.exe /c "echo no | `"$avdmanager`" create avd -n $avdName -k `"$targetSystemImage`" -d $deviceProfile $forceArg"

    Write-Host "[5/5] config.ini のチューニング最適化..." -ForegroundColor Yellow
    $avdHome = Join-Path $HOME ".android\avd\$avdName.avd"
    $configFile = Join-Path $avdHome "config.ini"

    if (Test-Path $configFile) {
        $content = Get-Content $configFile -Encoding utf8
        $lines = @()
        $settings = @{
            "hw.ramSize" = "2048"
            "vm.heapSize" = "512"
            "hw.gpu.enabled" = "yes"
            "hw.gpu.mode" = "auto"
            "hw.keyboard" = "yes"
            "disk.dataPartition.size" = "4096M"
        }

        foreach ($line in $content) {
            if ($line -match '^\s*([^=\s]+)\s*=\s*(.*)$') {
                $k = $matches[1].Trim()
                $v = $matches[2].Trim()
                if ($settings.ContainsKey($k)) {
                    $v = $settings[$k]
                    $settings.Remove($k)
                }
                $lines += "$k=$v"
            }
        }
        foreach ($k in $settings.Keys) {
            $v = $settings[$k]
            $lines += "$k=$v"
        }

        # Java Properties は BOM 付き UTF-8 だとパースエラーになるため BOM なし UTF-8 で保存
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllLines($configFile, $lines, $utf8NoBom)
        Write-Host "config.ini を最適化しました: $configFile" -ForegroundColor Green
    } else {
        Write-Warning "config.ini が見つかりませんでした: $configFile"
    }

    Write-Host "=== セットアップが完了しました ===" -ForegroundColor Green
} finally {
    $env:JAVA_HOME = $origJavaHome
    $env:Path = $origPath
}
