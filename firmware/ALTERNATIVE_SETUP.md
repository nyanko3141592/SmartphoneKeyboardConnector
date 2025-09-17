# 代替セットアップ方法

PlatformIO でコンパイルエラーが出る場合の解決策

## 📱 Arduino IDE を使う方法（推奨）

### 1. Arduino IDE セットアップ

#### Arduino IDE インストール
```bash
# Homebrew の場合
brew install --cask arduino

# または公式サイトからダウンロード
# https://www.arduino.cc/en/software
```

#### ボードマネージャー設定
1. Arduino IDE を開く
2. **Arduino IDE** → **設定** (Preferences)
3. **追加のボードマネージャのURL** に追加：
```
https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
```

#### Xiao nRF52840 ボードインストール
1. **ツール** → **ボード** → **ボードマネージャー**
2. "**Seeed nRF52**" を検索してインストール

#### ライブラリインストール
1. **ツール** → **ライブラリを管理**
2. 以下をインストール：
   - **Adafruit TinyUSB Library**
   - **Adafruit Bluefruit nRF52 Libraries**

### 2. ファームウェア準備

#### Arduino用コードの作成
```bash
# firmware ディレクトリで
mkdir arduino_version
cp src/main.cpp arduino_version/xiao_keyboard.ino
```

#### ファイル修正（必要に応じて）
Arduino IDE では `#include <Arduino.h>` は不要なので削除

### 3. ボード設定

1. **ツール** → **ボード** → **Seeed nRF52 Boards** → **Seeed XIAO nRF52840**
2. **ツール** → **Port** → Xiao のポートを選択

### 4. 書き込み

1. Xiao BLE をブートローダーモードに（リセットボタン2回押し）
2. **スケッチ** → **マイコンボードに書き込む** (⌘U)

---

## 🔧 PlatformIO の問題解決

### 方法1: 古いライブラリバージョンを使用

`platformio.ini` を以下に変更：

```ini
[env:xiao_nrf52840_sense]
platform = nordicnrf52@10.5.0
board = adafruit_feather_nrf52840_sense
framework = arduino

build_flags =
    -D USE_TINYUSB
    -D CFG_DEBUG=0

lib_deps =
    adafruit/Adafruit TinyUSB Library @ 2.2.6

monitor_speed = 115200
upload_protocol = nrfutil
```

### 方法2: 別のボードを試す

```ini
[env:adafruit_feather_nrf52840]
platform = nordicnrf52
board = adafruit_feather_nrf52840
framework = arduino
```

### 方法3: クリーンビルド

```bash
# キャッシュをクリア
pio run --target clean
rm -rf .pio

# 再ビルド
pio run
```

---

## 🎯 最も確実な方法：UF2 ファイルをダウンロード

### GitHub Releases から UF2 をダウンロード

1. GitHub の Releases ページを確認
2. `xiao-keyboard-firmware.uf2` をダウンロード
3. Xiao をブートローダーモードに
4. UF2 ファイルをドラッグ&ドロップ

### 手動 UF2 作成（Arduino IDE 使用）

1. Arduino IDE でコンパイル成功後
2. **スケッチ** → **コンパイル済みバイナリを出力**
3. `/tmp/arduino_build_xxx/` で `.uf2` ファイルを探す

---

## 🛠 トラブルシューティング

### エラー: `flush() override`
- SdFat ライブラリの互換性問題
- → Arduino IDE を使用

### エラー: `Unknown board ID`
- ボード定義が見つからない
- → Arduino IDE で Seeed ボードをインストール

### エラー: `USB_VID redefined`
- 重複定義警告（通常は無視可能）
- → build_flags から USB 設定を削除

### Xiao が認識されない
```bash
# macOS でポート確認
ls /dev/cu.*

# 権限問題の場合
sudo chmod 666 /dev/cu.usbmodem*
```

---

## 📝 動作確認

### 1. シリアルモニタ
Arduino IDE：**ツール** → **シリアルモニタ** (115200 baud)

期待される出力：
```
Simple Xiao BLE Keyboard Starting...
Initializing USB HID...
USB HID initialized
Initializing BLE...
BLE initialized
Starting BLE advertising...
Advertising started
Setup complete. Ready for connections.
USB connected
```

### 2. LED 確認
- **青LED点滅**: BLE アドバタイジング中
- **青LED点灯**: BLE 接続中

### 3. PC での認識確認

**macOS:**
```bash
system_profiler SPUSBDataType | grep -A 10 -B 5 "Keyboard"
```

**Windows:**
- デバイスマネージャー → ヒューマンインターフェイスデバイス

---

## 💡 おすすめワークフロー

1. **まず Arduino IDE で動作確認**
2. **成功したら PlatformIO に移行**（オプション）
3. **CI/CD は Arduino CLI 使用**

Arduino CLI での自動化：
```bash
# Arduino CLI インストール
brew install arduino-cli

# ボード追加
arduino-cli core update-index --additional-urls https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
arduino-cli core install Seeeduino:nrf52

# コンパイル
arduino-cli compile --fqbn Seeeduino:nrf52:xiaonRF52840Sense arduino_version/xiao_keyboard

# 書き込み
arduino-cli upload -p /dev/cu.usbmodem* --fqbn Seeeduino:nrf52:xiaonRF52840Sense arduino_version/xiao_keyboard
```