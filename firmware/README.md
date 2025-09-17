# Xiao BLE Keyboard Firmware

Bluetooth LE から受信したテキストを USB HID キーボード入力として送信するファームウェア

## 必要なハードウェア

- Seeed XIAO nRF52840 (BLE + USB対応)
- USB Type-C ケーブル（**データ転送対応**）
- PC (Windows/macOS/Linux)

## 開発環境のセットアップ（Arduino IDE 推奨）

### 1. Arduino IDE のインストール

#### macOS の場合
```bash
# Homebrew を使用
brew install --cask arduino

# または公式サイトからダウンロード
# https://www.arduino.cc/en/software
```

#### Windows/Linux の場合
[Arduino 公式サイト](https://www.arduino.cc/en/software) からダウンロード・インストール

### 2. ボードマネージャーの設定

1. Arduino IDE を開く
2. **Arduino IDE** → **設定** (Preferences) を選択
3. **追加のボードマネージャのURL** に以下を追加：
```
https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
```

### 3. Seeed nRF52 ボードのインストール

1. **ツール** → **ボード** → **ボードマネージャー** を選択
2. "**Seeed nRF52**" を検索
3. **Seeed nRF52 Boards by Seeed Studio** をインストール

### 4. 必要ライブラリのインストール

1. **ツール** → **ライブラリを管理** を選択
2. 以下のライブラリを検索してインストール：
   - **Adafruit TinyUSB Library** (by Adafruit)
   - **Adafruit Bluefruit nRF52 Libraries** (by Adafruit)

## ファームウェアの書き込み

### 1. Arduino スケッチの準備

```bash
# firmware ディレクトリで Arduino 用フォルダを作成
mkdir arduino_version
cp src/main.cpp arduino_version/xiao_keyboard.ino
```

もしくは既存の `arduino_version/xiao_keyboard.ino` を使用

### 2. Arduino IDE での設定

1. **xiao_keyboard.ino** を Arduino IDE で開く
2. **ツール** → **ボード** → **Seeed nRF52 Boards** → **Seeed XIAO nRF52840** を選択
3. **ツール** → **ポート** → Xiao BLE のポートを選択

### 3. Xiao BLE をブートローダーモードにする

1. Xiao BLE を USB-C ケーブルで PC に接続
2. **リセットボタンを素早く2回押す**（ダブルクリック）
3. **緑色の LED が点滅**したら成功
4. **XIAO-SENSE** ドライブが表示される場合もあります

### 4. 書き込み実行

1. Arduino IDE で **スケッチ** → **マイコンボードに書き込む** (⌘U / Ctrl+U)
2. 書き込み完了まで待つ（通常1-2分）

## 書き込み成功の確認

### シリアルモニタでの確認

1. Arduino IDE で **ツール** → **シリアルモニタ** を選択
2. ボーレートを **115200** に設定

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

### LED の確認

- **青色LED点滅**: BLE アドバタイジング中（正常動作）
- **青色LED点灯**: BLE デバイス接続中
- **緑色LED点滅**: ブートローダーモード
- **赤色LED**: エラー状態

## PC での認識確認

### macOS
```bash
# USB デバイスを確認
system_profiler SPUSBDataType | grep -A 10 -B 5 "Keyboard"

# または
ioreg -p IOUSB | grep -i keyboard
```

### Windows
1. デバイスマネージャーを開く
2. **ヒューマンインターフェイスデバイス** を展開
3. "HID Keyboard Device" または類似の名前を確認

### Linux
```bash
# USB デバイス一覧
lsusb | grep -i keyboard

# 詳細情報
lsusb -v | grep -A 10 -B 5 "Keyboard"
```

## 機能

### BLE サービス

- **Service UUID**: `12345678-1234-5678-1234-56789ABCDEF0`
- **Text Characteristic**: `12345678-1234-5678-1234-56789ABCDEF1` (Write)

### USB HID

- 標準 USB キーボードとして認識
- ASCII 文字入力サポート
- 基本的な特殊文字対応

### 対応文字

- **英数字**: a-z, A-Z, 0-9
- **特殊文字**: スペース, エンター, ピリオド, コンマ
- **日本語**: UTF-8 として受信し、IME で処理

## トラブルシューティング

### ファームウェアが書き込めない

#### ブートローダーモードに入れない
- リセットボタンをもっと **素早く2回**押す（ダブルクリック）
- USB ケーブルを **データ転送対応**のものに変更
- 別の USB ポートを試す

#### Arduino IDE でポートが見つからない
```bash
# macOS でポート確認
ls /dev/cu.*

# 権限エラーの場合
sudo chmod 666 /dev/cu.usbmodem*
```

#### Windows でドライバーエラー
1. [Zadig](https://zadig.akeo.ie/) をダウンロード
2. Xiao をブートローダーモードで接続
3. Zadig で WinUSB ドライバーをインストール

### BLE 接続できない

1. **Xiao の状態確認**
   - 青色LED点滅（アドバタイジング中）
   - シリアルモニタで "Advertising started" 確認

2. **iOS デバイスの確認**
   - Bluetooth が有効
   - アプリに Bluetooth 権限が付与済み
   - 他のデバイスとの接続を切断

3. **接続距離を確認**
   - 1-2m 以内で試す
   - 電波干渉の少ない場所

### 文字が正しく入力されない

1. **キーボード設定**
   - US 配列に設定
   - IME を有効にする（日本語入力の場合）

2. **テスト用文字列**
   - まず英数字のみで試す: "hello123"
   - 成功したら日本語を試す: "こんにちは"

## 代替方法：UF2 ファイルを使用

Arduino IDE が使えない場合：

### 1. UF2 ファイルの入手
- GitHub Releases から `xiao-keyboard-firmware.uf2` をダウンロード
- または Arduino IDE でコンパイル後に生成されるファイルを使用

### 2. 書き込み
1. Xiao をブートローダーモードに（リセット2回押し）
2. **XIAO-SENSE** ドライブにUF2ファイルをドラッグ&ドロップ
3. 自動的に書き込まれて再起動

## 次のステップ

1. **ファームウェア書き込み完了**
2. **iOS アプリをビルド** (`EasyKeyboard/README.md` 参照)
3. **接続テスト**
   - iOS アプリから "Xiao Keyboard" デバイスを探す
   - 接続してテキスト送信

## ライセンス

MIT License - 詳細は LICENSE ファイルを参照