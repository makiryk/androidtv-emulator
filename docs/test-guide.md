# Android TV エミュレータ 確認テスト実施ガイド

本ガイドでは、PC 上で Android TV エミュレータを立ち上げ、開発したアプリ（APK）をインストールして動作確認テストを行う手順を解説します。

---

## 1. 事前準備（初回のみ）

エミュレータ環境のセットアップおよび仮想デバイス（AVD: `AndroidTV_1080p`）の作成を行います。

PowerShell を起動し、以下のコマンドを実行します。
```powershell
cd C:\cloud\repo\androidtv-emulator
.\scripts\setup-env.ps1
```
※既に作成済みの AVD を再作成する場合は `-Force` を付与してください。

---

## 2. エミュレータの起動

エミュレータの GUI ウィンドウを起動し、Android TV のホーム画面が表示されるまで待機します。

```powershell
.\scripts\start-tv.ps1
```

- **起動オプション**:
  - `-Scale 0.75` : PC 画面に合わせてウィンドウサイズを縮小表示
  - `-ColdBoot` : キャッシュを使用せず完全新規ブート
  - `-NoWait` : ブート完了を待たずに非同期で起動

起動が完了すると、PC 上に Android TV のホーム画面（1080p 解像度）が表示されます。

---

## 3. アプリ（APK）のインストールと起動

PC 内にあるビルド済み APK ファイルをエミュレータへインストールします。

### インストールのみ
```powershell
.\scripts\install-app.ps1 -ApkPath "C:\path\to\your-app.apk"
```

### インストール後、直ちにアプリを起動
```powershell
.\scripts\install-app.ps1 -ApkPath "C:\path\to\your-app.apk" -Launch
```
※TV 向けアプリ（`LEANBACK_LAUNCHER` インテント）が自動起動します。

---

## 4. PC からのリモコン操作

エミュレータ上のアプリを操作するため、PowerShell からリモコンキーを送信できます。

### 4.1 対話モード（おすすめ）
引数なしで実行すると、PC のキーボードを使ってリアルタイムに十字キーや決定操作が行えます。
```powershell
.\scripts\tv-remote.ps1
```

| PC キーボード | リモコン機能 | 動作 |
|---|---|---|
| **[↑] [↓] [←] [→]** | 十字キー (D-pad) | フォーカス移動 |
| **[Enter] / [Space]** | 決定 (Select / OK) | アイコン・ボタンの選択 |
| **[Backspace] / [ESC]** | 戻る (Back) | 前画面へ戻る |
| **[H]** | ホーム (Home) | TV ホーム画面に戻る |
| **[P]** | 再生 / 一時停止 | メディアの再生・停止 |
| **[+] / [-]** | 音量 Up / Down | 音量調節 |
| **[Q]** | 終了 | リモコン操作を抜ける |

### 4.2 コマンド引数モード（スクリプト・自動化用）
```powershell
# フォーカスを下に移動
.\scripts\tv-remote.ps1 -Key Down

# 決定
.\scripts\tv-remote.ps1 -Key Select

# 検索窓などに文字を入力
.\scripts\tv-remote.ps1 -Text "search query"
```

---

## 5. エミュレータの終了

確認テストが完了したら、エミュレータを安全にシャットダウンします。
```powershell
.\scripts\stop-tv.ps1
```
※タイムアウト時にプロセスを強制終了する場合は `-Force` を指定してください。
