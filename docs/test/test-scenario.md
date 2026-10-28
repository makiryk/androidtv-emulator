# Android TV エミュレータ テストシナリオ（総合・結合・単体テスト仕様書）

## 0. 要件トレーサビリティマトリクス

| テスト ID | テスト分類 | 検証項目 | 追跡要件 |
|---|---|---|---|
| **TS-01** | 結合・環境構築 | SDK パッケージ導入および AVD 作成検証 | R-01, R-02 |
| **TS-02** | 結合・起動 | エミュレータ起動・ブート完了・プロセス監視 | R-01, R-02 |
| **TS-03** | 機能・操作 | リモコン操作インターフェース（単発・対話） | R-04 |
| **TS-04** | 結合・アプリ | APK インストールおよび LEANBACK 自動起動 | R-03 |
| **TS-05** | 結合・停止 | エミュレータ安全停止および残存プロセス確認 | R-02 |
| **TS-06** | 運用・手順 | テスト手順書・トラブルシュート文書検証 | R-05 |
| **TS-07** | 異常系 | 不正引数、タイムアウト、未起動時ハンドリング | R-01〜R-04 |
| **TS-08** | 非機能・環境保護 | JAVA_HOME 環境変数の不変性・退避復元検証 | R-02 |

---

## 1. テストケース詳細

### TS-01: 環境セットアップと AVD 作成検証（追跡: R-01, R-02）
- **前提条件**: JDK 17 および Android SDK が存在すること。
- **実行手順**:
  1. `.\scripts\setup-env.ps1 -Force` を実行。
- **期待結果**:
  - `emulator.exe -accel-check` が実行され、アクセラレーション状態がログ出力されること。
  - `sdkmanager` により `emulator` および `system-images;android-34;android-tv;x86` がインストールされること。
  - `avdmanager list avd` の出力に `AndroidTV_1080p` が含まれること。
  - `~/.android/avd/AndroidTV_1080p.avd/config.ini` に `hw.ramSize = 2048`, `hw.gpu.enabled = yes` が設定されていること。

### TS-02: エミュレータ起動・ブート完了検証（追跡: R-01, R-02）
- **前提条件**: `AndroidTV_1080p` AVD が作成済みであること。
- **実行手順**:
  1. `.\scripts\start-tv.ps1 -TimeoutSec 300` を実行。
- **期待結果**:
  - エミュレータの GUI ウィンドウ（1080p Android TV）が表示されること。
  - プロセス監視により `emulator.exe` または `qemu-system-x86_64.exe` が検出されること。
  - `adb devices` に `emulator-\d+\s+device` が現れること。
  - `adb shell getprop sys.boot_completed` が `1` を返し、スクリプトが終了コード `0` で完了すること。

### TS-03: リモコン操作インターフェース検証（追跡: R-04）
- **前提条件**: エミュレータが起動し、ホーム画面が表示されていること。
- **実行手順**:
  1. `.\scripts\tv-remote.ps1 -Key Down`
  2. `.\scripts\tv-remote.ps1 -Key Right`
  3. `.\scripts\tv-remote.ps1 -Key Select`
  4. `.\scripts\tv-remote.ps1 -Key Back`
  5. `.\scripts\tv-remote.ps1 -Key Home`
  6. `.\scripts\tv-remote.ps1 -Text "test"`
- **客観的判定基準**:
  - 各コマンド実行時、`adb shell dumpsys input` または UI 画面上のフォーカス枠が正常に移動・反応すること。
  - 終了コードがすべて `0` であること。

### TS-04: アプリ（APK）インストールと起動検証（追跡: R-03）
- **前提条件**: エミュレータ起動中。テスト対象 APK が指定可能であること。
- **実行手順**:
  1. `.\scripts\install-app.ps1 -ApkPath <APK_PATH> -Launch` を実行。
- **客観的判定基準**:
  - `adb install` が Success を返すこと。
  - `aapt2` によるパッケージ名の自動抽出が成功すること。
  - `adb shell dumpsys window | findstr mCurrentFocus` で該当パッケージのアクティビティがフォアグラウンド表示されていること。

### TS-05: エミュレータ安全停止および残存確認（追跡: R-02）
- **前提条件**: エミュレータ起動中。
- **実行手順**:
  1. `.\scripts\stop-tv.ps1` を実行。
- **客観的判定基準**:
  - スクリプトが正常終了すること。
  - `Get-Process emulator, qemu-system-x86_64 -ErrorAction SilentlyContinue` の結果が `$null`（完全終了）であること。
  - `adb devices` に該当エミュレータが存在しないこと。

### TS-06: 運用手順書・トラブルシュート文書検証（追跡: R-05）
- **実行手順**:
  1. ドキュメント（`docs/test-guide.md`, `docs/troubleshooting.md`）の存在と記載内容を確認。
- **客観的判定基準**:
  - 初回起動手順、APK テスト手順、リモコン操作方法、WHPX 有効化トラブル対処法が抜けなく記載されていること。

### TS-07: 異常系・エラーハンドリング検証（追跡: R-01〜R-04）
- **実行手順**:
  1. エミュレータ未起動時に `.\scripts\stop-tv.ps1` を実行 → 「起動中のエミュレータが見つかりません」の警告メッセージが出て終了すること。
  2. 存在しない APK パスで `.\scripts\install-app.ps1 -ApkPath "C:\not_found.apk"` を実行 → エラーコード `1` で終了すること。
  3. 不正なキー名 `.\scripts\tv-remote.ps1 -Key InvalidKey` を実行 → 許容キー一覧を表示してエラー終了すること。

### TS-08: 環境変数非破壊性検証（追跡: R-02）
- **実行手順**:
  1. PowerShell セッションで `$env:JAVA_HOME` を記録。
  2. `.\scripts\start-tv.ps1` などのスクリプトを実行。
  3. 実行後の `$env:JAVA_HOME` がスクリプト実行前と一致していることを確認。
