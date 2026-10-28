# Android TV エミュレータ環境 & テストスイート

Windows PC 上で Android TV アプリを確認テストするためのエミュレータ立ち上げ・管理スクリプトおよびドキュメント群です。

## 主な機能・構成予定
- `scripts/start-tv.ps1` : Android TV エミュレータの起動（GUI表示・最適化オプション）
- `scripts/stop-tv.ps1` : エミュレータの安全な停止
- `scripts/install-app.ps1` : ビルド済み APK のインストール・更新
- `scripts/tv-remote.ps1` : PC からのリモコンキー操作（D-pad, OK, Back, Home）
- `docs/test-guide.md` : PC での確認テスト実施ガイド
- `docs/troubleshooting.md` : トラブルシューティング

## プロジェクト管理
- 管理ファイル: `~/.ai-handoff/projects/androidtv-emulator/`
