# Android TV エミュレータ 基本・詳細設計仕様書

## 0. 要件定義とトレーサビリティ

本設計は、以下のプロジェクト要件を満たすよう構成される。

| 要件 ID | 要件名 | 要件内容 | 設計対応節 | テスト対応 |
|---|---|---|---|---|
| **R-01** | エミュレータ起動 | PC 上で Android TV の GUI 画面が正常に起動・表示されること | §1.2, §2.1, §2.2 | TS-01, TS-02 |
| **R-02** | スクリプト管理 | PowerShell からワンコマンドで起動・停止などのライフサイクル管理ができること | §2.2, §2.3, §3.1 | TS-02, TS-05 |
| **R-03** | APK 配置・導入 | ビルド済み APK をエミュレータへ導入・更新・起動できること | §2.4 | TS-04 |
| **R-04** | リモコン操作 | D-pad、決定、戻る、ホーム、メディア操作が PC から容易に行えること | §2.5 | TS-03 |
| **R-05** | 手順書・運用保守 | 初回導入〜起動〜テスト〜停止まで迷わず実行できるドキュメントがあること | §4 | TS-06 |

---

## 1. システム構成・環境仕様

### 1.1 パスおよび依存環境
- **Android SDK ルート**: `%LOCALAPPDATA%\Android\Sdk` (または `$ANDROID_HOME`)
- **JDK 17 ルート**: `C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot`
- **Android Platform-Tools (adb)**: `$SDK\platform-tools\adb.exe`
- **Cmdline-tools (sdkmanager / avdmanager)**: `$SDK\cmdline-tools\latest\bin\`
- **Emulator 本体**: `$SDK\emulator\emulator.exe`
- **Build-tools (aapt2)**: `$SDK\build-tools\34.0.0\aapt2.exe`

### 1.2 AVD（仮想デバイス）仕様
- **AVD 名**: `AndroidTV_1080p`
- **システムイメージ**: `system-images;android-34;android-tv;x86`
- **デバイス定義**: `tv_1080p` (解像度: 1920x1080, density: 320dpi)
- **仮想ハードウェア構成 (config.ini)**:
  - `hw.ramSize = 2048` (2GB RAM)
  - `vm.heapSize = 512`
  - `hw.gpu.enabled = yes`
  - `hw.gpu.mode = auto` (ホストGPUアクセラレーション利用)
  - `hw.keyboard = yes`
  - `disk.dataPartition.size = 4096M`

### 1.3 ハードウェアアクセラレーション (WHPX)
- Windows では Windows ハイパーバイザー プラットフォーム (Windows Hypervisor Platform: WHPX) を利用してエミュレータをアクセラレーションする。
- 事前に `emulator.exe -accel-check` を実行し、アクセラレーションが利用可能か判定する。

---

## 2. スクリプト構成とインターフェース詳細設計

すべてのスクリプトは `scripts/` ディレクトリに配置し、PowerShell 5.1 / 7+ 互換（文字コード UTF-8、`&&` や `||` を使わず `;` と `if ($?)` を使用）とする。

### 2.1 `scripts/setup-env.ps1` (追跡: R-01, R-02)
- **目的**: 必要な SDK パッケージ（emulator, system-images）のダウンロードおよび AVD の自動作成・最適化。
- **引数**:
  - `-Force`: 既存 AVD があっても上書き作成する（スイッチ）
- **処理フロー**:
  1. 環境チェック: JDK 17、SDK パス、および `emulator -accel-check` の確認。
  2. 環境変数一時適用: `$env:JAVA_HOME` を設定（実行後 `finally` で復元）。
  3. ライセンス同意: `yes | sdkmanager --licenses`
  4. パッケージ導入: `emulator`, `system-images;android-34;android-tv;x86`
  5. AVD 作成: `avdmanager create avd -n AndroidTV_1080p -k "system-images;android-34;android-tv;x86" -d "tv_1080p" --force`
  6. `config.ini` 最適化: `~/.android/avd/AndroidTV_1080p.avd/config.ini` にチューニングパラメータ（GPU/メモリ）を追記・更新。

### 2.2 `scripts/start-tv.ps1` (追跡: R-01, R-02)
- **目的**: Android TV エミュレータを起動し、ブート完了までを監視する。
- **引数**:
  - `-AvdName <string>`: 起動する AVD 名（既定値: `AndroidTV_1080p`）
  - `-ColdBoot`: キャッシュを使わずコールドブート（`-no-snapshot-load` を付与）
  - `-WipeData`: ユーザーデータを初期化（`-wipe-data` を付与。要 `-Force` スイッチ）
  - `-Force`: `-WipeData` 実行時の安全確認スキップ
  - `-NoWait`: ブート完了を待たずに非同期で即座に制御を戻す（スイッチ）
  - `-TimeoutSec <int>`: ブート完了のタイムアウト秒数（既定値: `180` 秒、初回やコールドブート時は自動的に `300` 秒に延長）
  - `-Scale <string>`: ウィンドウ縮小表示倍率（例: `0.75` など）
- **処理フロー**:
  1. 既に起動しているか `adb devices` でチェック。起動中なら警告を出して終了。
  2. エミュレータ引数を組み立て、バックグラウンドプロセスとして起動。
  3. `-NoWait` でない場合、エミュレータプロセスの生死監視を行いつつ、ポーリング（2秒間隔）:
     - `adb wait-for-device`
     - `adb shell getprop sys.boot_completed` が `1` かつ `init.svc.bootanim` が `stopped` になるまで待機。
  4. タイムアウト時はエラーログを出力し終了コード `1` で復帰。

### 2.3 `scripts/stop-tv.ps1` (追跡: R-02)
- **目的**: 稼働中の Android TV エミュレータを安全に終了する。
- **引数**:
  - `-TimeoutSec <int>`: 終了完了の待機タイムアウト秒数（既定値: `30` 秒）
  - `-Force`: タイムアウト時にプロセス（`emulator.exe`, `qemu-system-x86_64.exe`）を強制終了する（スイッチ）
- **処理フロー**:
  1. `adb devices` から `emulator-\d+` を取得。
  2. `adb emu kill` を発行。
  3. エミュレータプロセスが完全に終了するまで待機（ポーリング）。
  4. タイムアウト時、`-Force` があれば強制終了、なければ警告出力。

### 2.4 `scripts/install-app.ps1` (追跡: R-03)
- **目的**: ビルド済み APK をエミュレータに転送・インストールし、起動する。
- **引数**:
  - `-ApkPath <string>`: インストール対象の APK ファイルパス（必須）
  - `-Launch`: インストール後に自動起動する（スイッチ）
  - `-PackageName <string>`: 起動対象のパッケージ名（省略時は `aapt2 dump badging` から自動抽出）
- **処理フロー**:
  1. APK ファイルの存在確認。
  2. `-Launch` 指定時、`-PackageName` が未指定なら `aapt2 dump badging "<ApkPath>"` から `package: name='...'` を抽出。抽出できなければエラー。
  3. `adb install -r -g "<ApkPath>"` の実行。
  4. インストール成功後、`-Launch` があれば TV 向けインテントで起動:
     - `adb shell monkey -p <PackageName> -c android.intent.category.LEANBACK_LAUNCHER 1`
     - 上記が失敗した場合は `adb shell am start -n <PackageName>/<MainActivity>` を試行。

### 2.5 `scripts/tv-remote.ps1` (追跡: R-04)
- **目的**: PC から Android TV のリモコン操作（キーイベント）を送信する。
- **引数モード**:
  - `-Key <string>`: 単発キー送信。
  - `-Text <string>`: 任意のテキスト文字入力を送信（`adb shell input text`）。
- **対話モード** (引数なし実行時):
  - PowerShell コンソール上でキー入力を直接受け付け、即時送信する CLI。
  - `Q` または `ESC` で終了。
- **キーイベントマッピング表**:
  | 操作キー名 | KeyEvent コード | 機能説明 |
  |---|---|---|
  | `Up` | 19 (`KEYCODE_DPAD_UP`) | 上移動 |
  | `Down` | 20 (`KEYCODE_DPAD_DOWN`) | 下移動 |
  | `Left` | 21 (`KEYCODE_DPAD_LEFT`) | 左移動 |
  | `Right` | 22 (`KEYCODE_DPAD_RIGHT`) | 右移動 |
  | `Select` / `OK` | 23 (`KEYCODE_DPAD_CENTER`) | 決定 |
  | `Back` | 4 (`KEYCODE_BACK`) | 戻る |
  | `Home` | 3 (`KEYCODE_HOME`) | ホーム画面 |
  | `PlayPause` | 85 (`KEYCODE_MEDIA_PLAY_PAUSE`) | 再生 / 一時停止 |
  | `FastForward` | 90 (`KEYCODE_MEDIA_FAST_FORWARD`) | 早送り |
  | `Rewind` | 89 (`KEYCODE_MEDIA_REWIND`) | 巻き戻し |
  | `VolumeUp` | 24 (`KEYCODE_VOLUME_UP`) | 音量アップ |
  | `VolumeDown` | 25 (`KEYCODE_VOLUME_DOWN`) | 音量ダウン |
  | `Mute` | 164 (`KEYCODE_VOLUME_MUTE`) | 消音 |

---

## 3. 共通仕様・エラー処理・耐障害性

### 3.1 環境変数の退避と復元（JAVA_HOME 保護）
各スクリプトの先頭と末尾において、以下のパターンで環境変数を保護する。
```powershell
$origJavaHome = $env:JAVA_HOME
$origPath = $env:Path
try {
    $env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot"
    $env:Path = "$env:JAVA_HOME\bin;$env:Path"
    # 主処理
} finally {
    $env:JAVA_HOME = $origJavaHome
    $env:Path = $origPath
}
```

### 3.2 パス・エンコーディング
- すべてのコマンド実行パス（空白を含む Program Files や AppData）はダブルクォートで確実に囲む。
- ファイルの読み書きはすべて `-Encoding utf8` を指定。
