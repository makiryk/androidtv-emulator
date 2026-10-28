<#
.SYNOPSIS
    Android TV リモコン操作スクリプト
.DESCRIPTION
    PC から Android TV エミュレータへリモコンキー入力（D-pad, OK, Back, Home, Media等）またはテキストを送信します。
    引数なしで実行した場合は、コンソール上で矢印キー等を直接押して操作できる対話モードになります。
#>
[CmdletBinding()]
param(
    [string]$Key,
    [string]$Text
)

$ErrorActionPreference = 'Stop'

$sdk = "C:\Users\mira\AppData\Local\Android\Sdk"
$adbExe = Join-Path $sdk "platform-tools\adb.exe"

if (-not (Test-Path $adbExe)) {
    Write-Error "adb not found at: $adbExe"
    exit 1
}

# 稼働中のデバイス確認
$devicesOutput = & $adbExe devices
$emuDevices = $devicesOutput | Select-String -Pattern "emulator-\d+\s+device"

if (-not $emuDevices) {
    Write-Error "接続中の Android エミュレータが見つかりません。先に start-tv.ps1 で起動してください。"
    exit 1
}
$targetDev = ($emuDevices[0].Line -split '\s+')[0]

# キーマップ定義
$keyMap = @{
    "Up"          = 19  # KEYCODE_DPAD_UP
    "Down"        = 20  # KEYCODE_DPAD_DOWN
    "Left"        = 21  # KEYCODE_DPAD_LEFT
    "Right"       = 22  # KEYCODE_DPAD_RIGHT
    "Select"      = 23  # KEYCODE_DPAD_CENTER
    "OK"          = 23  # 同上
    "Back"        = 4   # KEYCODE_BACK
    "Home"        = 3   # KEYCODE_HOME
    "Menu"        = 82  # KEYCODE_MENU
    "PlayPause"   = 85  # KEYCODE_MEDIA_PLAY_PAUSE
    "FastForward" = 90  # KEYCODE_MEDIA_FAST_FORWARD
    "Rewind"      = 89  # KEYCODE_MEDIA_REWIND
    "VolumeUp"    = 24  # KEYCODE_VOLUME_UP
    "VolumeDown"  = 25  # KEYCODE_VOLUME_DOWN
    "Mute"        = 164 # KEYCODE_VOLUME_MUTE
}

function Send-KeyEvent([string]$keyName) {
    if ($keyMap.ContainsKey($keyName)) {
        $code = $keyMap[$keyName]
        & $adbExe -s $targetDev shell input keyevent $code
    } else {
        Write-Error "無効なキー名です: $keyName。指定可能なキー: $($keyMap.Keys -join ', ')"
        exit 1
    }
}

# 1. 単発テキスト送信
if ($Text) {
    Write-Host "テキストを送信中: $Text" -ForegroundColor Yellow
    # 空白は %s に置換
    $escapedText = $Text -replace ' ', '%s'
    & $adbExe -s $targetDev shell input text "$escapedText"
    exit 0
}

# 2. 単発キー送信
if ($Key) {
    Send-KeyEvent $Key
    exit 0
}

# 3. 対話モード (Interactive Mode)
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Android TV リモコン対話モード ($targetDev)" -ForegroundColor Cyan
Write-Host "  [↑][↓][←][→] : 十字キー移動"
Write-Host "  [Enter / Space]: 決定 (Select / OK)"
Write-Host "  [Backspace / ESC]: 戻る (Back)"
Write-Host "  [H]           : ホーム (Home)"
Write-Host "  [P]           : 再生 / 一時停止"
Write-Host "  [+] / [-]     : 音量 Up / Down"
Write-Host "  [Q]           : 終了"
Write-Host "=========================================" -ForegroundColor Cyan

while ($true) {
    $rawKey = [Console]::ReadKey($true)
    switch ($rawKey.Key) {
        "UpArrow"    { Send-KeyEvent "Up"; Write-Host "↑ (Up)" -NoNewline }
        "DownArrow"  { Send-KeyEvent "Down"; Write-Host "↓ (Down)" -NoNewline }
        "LeftArrow"  { Send-KeyEvent "Left"; Write-Host "← (Left)" -NoNewline }
        "RightArrow" { Send-KeyEvent "Right"; Write-Host "→ (Right)" -NoNewline }
        "Enter"      { Send-KeyEvent "Select"; Write-Host " [OK] " -NoNewline }
        "Spacebar"   { Send-KeyEvent "Select"; Write-Host " [OK] " -NoNewline }
        "Backspace"  { Send-KeyEvent "Back"; Write-Host " [Back] " -NoNewline }
        "Escape"     { Send-KeyEvent "Back"; Write-Host " [Back] " -NoNewline }
        "H"          { Send-KeyEvent "Home"; Write-Host " [Home] " -NoNewline }
        "P"          { Send-KeyEvent "PlayPause"; Write-Host " [Play/Pause] " -NoNewline }
        "Add"        { Send-KeyEvent "VolumeUp"; Write-Host " [Vol+] " -NoNewline }
        "Subtract"   { Send-KeyEvent "VolumeDown"; Write-Host " [Vol-] " -NoNewline }
        "Q"          {
            Write-Host "`nリモコン対話モードを終了しました。" -ForegroundColor Yellow
            return
        }
    }
}
