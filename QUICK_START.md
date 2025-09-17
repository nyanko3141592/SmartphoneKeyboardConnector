# クイックスタートガイド

## 📱 ローカルでファームウェア書き込み

### 方法1: Arduino IDE（推奨・最も確実）

#### 1. Arduino IDE インストール
```bash
# macOS の場合
brew install --cask arduino

# または公式サイトから
# https://www.arduino.cc/en/software
```

#### 2. ボード設定
1. Arduino IDE → **設定** (Preferences)
2. **追加のボードマネージャのURL** に追加：
   ```
   https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
   ```
3. **ツール** → **ボード** → **ボードマネージャー**
4. "**Seeed nRF52**" を検索してインストール

#### 3. ライブラリインストール
1. **ツール** → **ライブラリを管理**
2. 以下をインストール：
   - **Adafruit TinyUSB Library** (by Adafruit)
   - **Adafruit Bluefruit nRF52 Libraries** (by Adafruit)

#### 4. Python PATH 問題の解決（重要）
```bash
# プロジェクトディレクトリで Arduino IDE を起動
cd /Users/takahashinaoki/Dev/Hobby/SmartphoneKeyboardConnector
./start_arduino.sh
```

または手動でターミナルから：
```bash
export PATH="/opt/homebrew/opt/python@3.13/libexec/bin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"
killall Arduino  # 既存のArduino IDEを終了
open -a Arduino
```

#### 5. ファームウェア書き込み
```bash
# Arduino スケッチを開く（Arduino IDE起動後）
File → Open → firmware/arduino_version/xiao_keyboard/xiao_keyboard.ino
```

1. **ツール** → **ボード** → **Seeed nRF52 Boards** → **Seeed XIAO nRF52840**
2. **スケッチ** → **検証・コンパイル** (⌘R) でコンパイル成功を確認
3. Xiao BLE をブートローダーモード（**リセットボタン2回押し、緑LED点滅**）
4. **ツール** → **ポート** → Xiao のポートを選択
5. **スケッチ** → **マイコンボードに書き込む** (⌘U)

#### 6. 動作確認
1. **ツール** → **シリアルモニタ** (115200 baud)

正常時の出力：
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

---

### 方法2: UF2ファイルをドラッグ&ドロップ（最も簡単）

#### 1. UF2ファイルの入手
- GitHub Releases から `xiao-keyboard-firmware.uf2` をダウンロード
- または Arduino IDE でコンパイル後に生成

#### 2. 書き込み
1. Xiao BLE を USB-C で接続
2. **リセットボタンを素早く2回押す**（緑LED点滅）
3. **XIAO-SENSE** ドライブが現れる
4. UF2ファイルをドライブにドラッグ&ドロップ
5. 自動的に書き込まれて再起動

---

### 方法3: PlatformIO（上級者向け）

⚠️ **注意**: 現在ライブラリの互換性問題でエラーが出る可能性があります。Arduino IDE を推奨します。

#### 1. PlatformIO インストール
```bash
# macOS の場合
brew install platformio
```

#### 2. ビルドと書き込み
```bash
cd firmware
pio run --target upload
```

---

## 🍎 iOS アプリのビルド

### 1. Xcode でプロジェクトを開く
```bash
cd EasyKeyboard
open EasyKeyboard.xcodeproj
```

### 2. Bluetooth 権限を追加

#### Xcode でのInfo.plist設定
1. プロジェクト設定 → **Info** タブ
2. **Custom iOS Target Properties** に追加：
   - Key: `NSBluetoothAlwaysUsageDescription`
   - Value: `This app uses Bluetooth to connect to your keyboard device`

#### または直接Info.plistソースに追加
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect to your keyboard device</string>
```

### 3. 実機でビルド
1. iPhone を Mac に接続
2. プロジェクト設定で Development Team を設定
3. Target Device を接続したiPhoneに設定
4. **Product** → **Run** (⌘R)

---

## 🔧 トラブルシューティング

### ファームウェア書き込みエラー

#### Python PATH エラー
```
exec: "python": executable file not found in $PATH
```
**解決方法**:
```bash
# Arduino IDE を完全に終了
killall Arduino

# 専用スクリプトで起動
./start_arduino.sh
```

#### Arduino IDE でポートが見つからない
```bash
# macOS でポート確認
ls /dev/cu.*

# 権限エラーの場合
sudo chmod 666 /dev/cu.usbmodem*
```

#### ブートローダーモードに入れない
- リセットボタンをもっと**素早く2回**押す（ダブルクリック）
- USB ケーブルを**データ転送対応**のものに変更
- 別の USB ポートを試す
- Xiao の電源を一度切って再接続

#### Windows でドライバーエラー
1. [Zadig](https://zadig.akeo.ie/) をダウンロード
2. Xiao をブートローダーモードで接続
3. Zadig で WinUSB ドライバーをインストール

### iOS アプリエラー

#### Bluetooth 権限がない
1. **Settings** → **Privacy & Security** → **Bluetooth**
2. **EasyKeyboard** を有効にする

#### ビルドエラー
- Development Team が設定されているか確認
- Bundle Identifier が一意か確認
- iOS Deployment Target が 14.0 以上か確認

#### デバイスが見つからない
1. Xiao の青LED点滅を確認（BLEアドバタイジング中）
2. iOS の Bluetooth が有効か確認
3. アプリを完全に終了して再起動
4. iPhone のBluetoothを一度オフ・オンする

---

## 🚀 動作テスト手順

### 1. 基本動作テスト
1. **ファームウェア書き込み確認**
   - シリアルモニタで起動メッセージ確認
   - 青LED点滅確認（アドバタイジング中）

2. **USB HID認識確認**
   - Xiao BLE を PC に接続
   - キーボードデバイスとして認識されることを確認

3. **BLE接続テスト**
   - iOS アプリで "Xiao Keyboard" を発見
   - 接続成功（青LED点灯）

4. **テキスト送信テスト**
   - 簡単な英数字: "hello123"
   - PC で正しく入力されることを確認

### 2. 日本語入力テスト
1. PC で Google 日本語入力等の IME を有効
2. iOS アプリから日本語テキスト送信: "こんにちは"
3. 正しく入力されることを確認

### 3. 特殊文字テスト
- 記号: `!@#$%^&*()`
- 句読点: `.,;:`
- 改行を含むテキスト

### 4. 接続安定性テスト
- アプリを一度終了して再接続
- 距離を変えて接続テスト（1-5m）
- 長時間接続の安定性確認

---

## 📋 完全チェックリスト

### 🛠 事前準備
- [ ] Seeed XIAO nRF52840 デバイス
- [ ] USB Type-C ケーブル（**データ転送対応**）
- [ ] iPhone (iOS 14.0+)
- [ ] Mac (Xcode対応)

### 📟 ファームウェア
- [ ] Arduino IDE インストール完了
- [ ] Seeed nRF52 ボードインストール完了
- [ ] 必要ライブラリインストール完了
- [ ] ファームウェア書き込み成功
- [ ] シリアルモニタで起動確認
- [ ] 青LED点滅確認（アドバタイジング）
- [ ] PC でUSBキーボード認識確認

### 📱 iOS アプリ
- [ ] Xcode プロジェクトビルド成功
- [ ] Bluetooth権限設定完了
- [ ] 実機でアプリ起動成功
- [ ] "Xiao Keyboard" デバイス発見
- [ ] BLE接続成功（青LED点灯）

### ✅ 動作確認
- [ ] 英数字テキスト送信成功
- [ ] 日本語テキスト送信成功
- [ ] 特殊文字送信成功
- [ ] 改行・複数行テキスト送信成功
- [ ] 再接続動作確認
- [ ] 長時間使用安定性確認

---

## ⚡ 緊急時の解決方法

### ファームウェアが全く動かない場合
1. **Arduino IDE で基本サンプルを試す**
   - File → Examples → 01.Basics → Blink
   - LED点滅が確認できれば Xiao は正常

2. **シリアル出力確認**
   - 115200 baud でシリアルモニタを開く
   - 何もメッセージが出ない場合は書き込み失敗

3. **完全リセット**
   - リセットボタンを長押し（5秒）
   - ブートローダーモードで再書き込み

### iOS アプリが接続できない場合
1. **iPhone のBluetooth完全リセット**
   - 設定 → 一般 → リセット → ネットワーク設定をリセット

2. **アプリ権限確認**
   - 設定 → プライバシー → Bluetooth → EasyKeyboard

3. **nRF Connect アプリで確認**
   - App Store から nRF Connect をダウンロード
   - "Xiao Keyboard" が見つかるか確認

---

## 🔗 参考リンク

- [Arduino IDE ダウンロード](https://www.arduino.cc/en/software)
- [Seeed XIAO nRF52840 公式Wiki](https://wiki.seeedstudio.com/XIAO_BLE/)
- [Adafruit nRF52 ライブラリ](https://github.com/adafruit/Adafruit_nRF52_Arduino)
- [Core Bluetooth ガイド](https://developer.apple.com/documentation/corebluetooth)
- [nRF Connect for Mobile](https://www.nordicsemi.com/Products/Development-tools/nrf-connect-for-mobile)