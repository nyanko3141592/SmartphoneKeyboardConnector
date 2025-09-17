# 🔧 Arduino IDE 権限エラー修正完了

## エラー: `permission denied`

```
fork/exec /Users/takahashinaoki/Library/Arduino15/packages/Seeeduino/hardware/nrf52/1.1.10/tools/adafruit-nrfutil/macos/adafruit-nrfutil: permission denied
```

## ✅ 修正完了

以下のコマンドで権限問題を解決しました：

```bash
# adafruit-nrfutil に実行権限を追加
chmod +x /Users/takahashinaoki/Library/Arduino15/packages/Seeeduino/hardware/nrf52/1.1.10/tools/adafruit-nrfutil/macos/adafruit-nrfutil

# すべてのツールの権限を修正
find /Users/takahashinaoki/Library/Arduino15/packages/Seeeduino/hardware/nrf52/1.1.10/tools/ -name "*" -type f ! -perm +111 -exec chmod +x {} \;
```

## 🚀 Arduino IDE で再コンパイル

### 1. Arduino IDE でコンパイル実行
- **スケッチ** → **検証・コンパイル** (⌘R)
- または ✓ ボタンをクリック

### 2. 成功メッセージの確認
```
スケッチの検証が終了しました
スケッチが使用する容量: XXXXX バイト (プログラム格納領域の XX%)
グローバル変数が XXXXX バイト (XX%) のメモリを使用。ローカル変数は XXXXX バイト使用可能。
```

## 📱 次のステップ: Xiao BLE への書き込み

### 1. Xiao BLE をブートローダーモードに
1. USB-C ケーブルで PC に接続
2. **リセットボタンを素早く2回押す**（ダブルクリック）
3. **緑色LED が点滅**することを確認

### 2. ポート選択
- **ツール** → **ポート** → Xiao BLE のポートを選択
- 通常 `/dev/cu.usbmodem*` という名前

### 3. 書き込み実行
- **スケッチ** → **マイコンボードに書き込む** (⌘U)
- または → ボタンをクリック

### 4. 書き込み成功の確認
```
書き込みが完了しました。

スケッチが使用する容量: XXXXX バイト (プログラム格納領域の XX%)
グローバル変数が XXXXX バイト (XX%) のメモリを使用。ローカル変数は XXXXX バイト使用可能。
```

### 5. 動作確認
- **ツール** → **シリアルモニタ** (115200 baud)
- 以下のメッセージが表示されれば成功：

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
```

## 🎉 完了！

これで Xiao BLE ファームウェアの書き込みが完了します。

次は iOS アプリをビルドして接続テストを行います。