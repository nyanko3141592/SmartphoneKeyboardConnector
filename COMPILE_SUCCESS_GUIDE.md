# 🎯 Arduino IDE コンパイル成功ガイド

## ✅ Python PATH 問題は解決済み

以下の修正を完了しました：
- Python パスを ~/.zshrc に追加
- シンボリックリンクを作成
- Arduino IDE を正しい環境で起動

## 🚀 Arduino IDE でコンパイル手順

### 1. Arduino IDE の確認
現在のターミナルから起動した Arduino IDE を使用してください。

### 2. スケッチを開く
```
File → Open → firmware/arduino_version/xiao_keyboard/xiao_keyboard.ino
```

### 3. ボード設定の確認
- **ツール** → **ボード** → **Seeed nRF52 Boards** → **Seeed XIAO nRF52840**
- タイトルバーに `Board: "Seeed XIAO nRF52840"` と表示されることを確認

### 4. コンパイル実行
- **スケッチ** → **検証・コンパイル** (⌘R)
- または上部のチェックマーク ✓ ボタンをクリック

### 5. 成功の確認
以下のようなメッセージが表示されれば成功：
```
スケッチの検証が終了しました
スケッチが使用する容量: XXXXX バイト (プログラム格納領域の XX%)
グローバル変数が XXXXX バイト (XX%) のメモリを使用。ローカル変数は XXXXX バイト使用可能。
```

## 🔧 まだエラーが出る場合

### Arduino IDE を再起動
```bash
# 現在の Arduino IDE を終了
# ターミナルで以下を実行：
export PATH="/opt/homebrew/opt/python@3.13/libexec/bin:$PATH"
open -a Arduino
```

### 新しいターミナルから起動
```bash
# 新しいターミナルウィンドウで
source ~/.zshrc
open -a Arduino
```

### 詳細エラー出力を有効にする
1. **File** → **Preferences**
2. ✅ **Show verbose output during compilation**
3. 再コンパイルしてエラー詳細を確認

## 📱 コンパイル成功後の次のステップ

### 1. Xiao BLE の準備
- USB-C ケーブルで PC に接続
- **リセットボタンを素早く2回押し**（緑LED点滅）

### 2. ポート選択
- **ツール** → **ポート** → Xiao BLE のポートを選択
- 通常 `/dev/cu.usbmodem*` のような名前

### 3. 書き込み実行
- **スケッチ** → **マイコンボードに書き込む** (⌘U)
- または上部の → ボタンをクリック

### 4. 動作確認
- **ツール** → **シリアルモニタ** (115200 baud)
- 起動メッセージを確認

```
=== Xiao BLE Keyboard Starting ===
Firmware: Arduino IDE Version
USB HID initialized successfully
BLE initialized
Advertising started
Setup complete. Ready for connections.
```

## 🎉 完了！

これで Xiao BLE ファームウェアの書き込みが完了です。

次は iOS アプリをビルドして接続テストを行います。