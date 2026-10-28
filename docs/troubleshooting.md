# Android TV エミュレータ トラブルシューティング

## 1. 仮想化アクセラレーション (WHPX / AEHD) エラー

### 症状
- エミュレータ起動時に `emulator: ERROR: x86 emulation currently requires hardware acceleration!` と表示される。
- 動作が極端に重く、起動に数分以上かかる。

### 原因と対処
1. **Windows ハイパーバイザー プラットフォーム (WHPX) の有効化**:
   - スタートメニューから「Windows の機能の有効化または無効化」を開く。
   - **「Windows ハイパーバイザー プラットフォーム」** (Windows Hypervisor Platform) にチェックを入れて再起動。
2. **コマンドでの確認**:
   ```powershell
   & "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -accel-check
   ```
   出力に `WHPX is installed and usable.` と出れば正常です。

---

## 2. エミュレータが起動途中でフリーズする / タイムアウトする

### 原因と対処
1. **スナップショット破損の可能性**:
   - キャッシュを破棄してコールドブートします。
     ```powershell
     .\scripts\start-tv.ps1 -ColdBoot -TimeoutSec 300
     ```
2. **GPU レンダリングの相性**:
   - `~/.android/avd/AndroidTV_1080p.avd/config.ini` 内の `hw.gpu.mode` を `auto` から `swiftshader_indirect` (ソフトウェア描画) に一時変更して試してください。

---

## 3. アプリのインストールに失敗する (`INSTALL_FAILED_*`)

### 原因と対処
1. **`INSTALL_FAILED_NO_MATCHING_ABIS`**:
   - アプリが ARM ネイティブライブラリ (.so) のみを含んでいる場合、x86 イメージでは動作しません。
   - 対処: `sdkmanager` から `system-images;android-34;android-tv;arm64-v8a` を導入して ARM 向け AVD を作成するか、APK ビルド時に x86/x86_64 アーキテクチャを含めてください。
2. **`INSTALL_FAILED_VERSION_DOWNGRADE`**:
   - 既に新しいバージョンのアプリが入っているためダウングレードが拒否されています。
   - 対処: `adb uninstall <パッケージ名>` で一度削除してから再インストールしてください。

---

## 4. リモコン操作が効かない / フォーカスが見えない

### 原因と対処
1. TV ホーム画面やアプリが読み込み中（ダイアログ表示中など）の場合、キー入力が無視されることがあります。
2. 一度 `[H]` キーでホーム画面に戻り、十字キーを押してフォーカスの枠が表示されるか確認してください。
