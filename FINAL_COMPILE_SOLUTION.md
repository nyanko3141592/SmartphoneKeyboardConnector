# 🎯 最終的なコンパイル解決方法

## 問題
Arduino IDE が Python を見つけられない問題が継続している。

## ✅ 完全解決方法

### 方法1: 専用起動スクリプトを使用（推奨）

```bash
# プロジェクトディレクトリで実行
cd /Users/takahashinaoki/Dev/Hobby/SmartphoneKeyboardConnector
./start_arduino.sh
```

このスクリプトが以下を実行します：
1. Python パスを正しく設定
2. Arduino IDE を適切な環境で起動
3. 環境確認メッセージを表示

### 方法2: 手動でターミナルから起動

```bash
# ターミナルで以下を実行
export PATH="/opt/homebrew/opt/python@3.13/libexec/bin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"
killall Arduino  # 既存のArduino IDEを終了
open -a Arduino
```

### 方法3: 永続的な解決（推奨）

```bash
# ~/.zshrc の内容を確認・追加
echo 'export PATH="/opt/homebrew/opt/python@3.13/libexec/bin:$PATH"' >> ~/.zshrc
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc

# 新しいターミナルを開いて確認
source ~/.zshrc
which python
python --version
```

## 🚀 Arduino IDE でのコンパイル手順

### 1. Arduino IDE の起動確認
- 上記のいずれかの方法で Arduino IDE を起動
- タイトルバーに `Board: "Seeed XIAO nRF52840"` が表示されていることを確認

### 2. スケッチを開く
```
File → Open → firmware/arduino_version/xiao_keyboard/xiao_keyboard.ino
```

### 3. コンパイル実行
- **スケッチ** → **検証・コンパイル** (⌘R)
- または ✓ ボタンをクリック

### 4. 成功メッセージの確認
```
スケッチの検証が終了しました
スケッチが使用する容量: XXXXX バイト (プログラム格納領域の XX%)
グローバル変数が XXXXX バイト (XX%) のメモリを使用。ローカル変数は XXXXX バイト使用可能。
```

## 📱 書き込み手順

### 1. Xiao BLE の準備
1. USB-C ケーブルで PC に接続
2. **リセットボタンを素早く2回押す**（ダブルクリック）
3. **緑色LED が点滅**することを確認
4. Finder で **XIAO-SENSE** ドライブが表示される（任意）

### 2. ポート選択
- **ツール** → **ポート**
- `/dev/cu.usbmodem*` のようなポートを選択

### 3. 書き込み実行
- **スケッチ** → **マイコンボードに書き込む** (⌘U)
- または → ボタンをクリック

### 4. 書き込み完了の確認
```
書き込みが完了しました。

スケッチが使用する容量: XXXXX バイト (プログラム格納領域の XX%)
```

### 5. 動作確認
1. **ツール** → **シリアルモニタ** (115200 baud)
2. 以下のメッセージが表示されれば成功：

```
=== Xiao BLE Keyboard Starting ===
Firmware: Arduino IDE Version
Device: Seeed XIAO nRF52840
Initializing USB HID...
USB HID initialized successfully
Initializing BLE...
BLE initialized
Device name: Xiao Keyboard
Starting BLE advertising...
BLE advertising started
Looking for devices in 'EasyKeyboard' iOS app...
Setup complete. Ready for connections.
USB connected
```

## 🔧 トラブルシューティング

### エラー: `exec: "python": executable file not found in $PATH`
- Arduino IDE を完全に終了: `killall Arduino`
- `./start_arduino.sh` スクリプトで再起動

### エラー: `permission denied`
- 権限は既に修正済み（前回対応）

### エラー: ポートが見つからない
```bash
# デバイス確認
ls /dev/cu.*

# Xiao をブートローダーモードに
# リセットボタンを素早く2回押す（緑LED点滅）
```

### LED の状態確認
- **緑LED点滅**: ブートローダーモード ✅
- **青LED点滅**: BLE アドバタイジング中 ✅
- **青LED点灯**: BLE 接続中 ✅

## 🎉 完了チェックリスト

- [ ] Python パス問題解決
- [ ] Arduino IDE でコンパイル成功
- [ ] Xiao BLE に書き込み成功
- [ ] シリアルモニタで動作確認
- [ ] BLE アドバタイジング開始確認

次のステップ: iOS アプリのビルドと接続テスト