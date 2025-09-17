# Xiao BLE ファームウェア書き込みガイド

## 必要なもの
- Seeed XIAO nRF52840
- USB Type-C ケーブル（データ転送対応）
- PC (Windows/macOS/Linux)

## 方法1: PlatformIO を使う（推奨）

### 1. PlatformIO のインストール

#### macOS の場合
```bash
# Homebrew を使う場合
brew install platformio

# または Python pip を使う場合
pip3 install platformio
```

#### Windows の場合
1. [Python](https://www.python.org/) をインストール
2. コマンドプロンプトで：
```cmd
pip install platformio
```

#### VSCode 経由（最も簡単）
1. VSCode をインストール
2. 拡張機能で "PlatformIO IDE" を検索してインストール
3. VSCode を再起動

### 2. ファームウェアのビルド

```bash
# firmware ディレクトリに移動
cd /Users/takahashinaoki/Dev/Hobby/SmartphoneKeyboardConnector/firmware

# 依存関係をインストール
pio pkg install

# ビルド
pio run
```

### 3. Xiao BLE を書き込みモードにする

1. **Xiao BLE を PC に USB-C ケーブルで接続**

2. **ブートローダーモードに入る**：
   - リセットボタン（小さいボタン）を素早く**2回押す**
   - **緑色の LED が点滅**したら成功
   - ドライブとして認識される場合もあります

### 4. ファームウェアを書き込む

```bash
# 書き込み実行
pio run --target upload
```

成功メッセージ例：
```
[SUCCESS] Uploaded successfully!
```

---

## 方法2: Arduino IDE を使う

### 1. Arduino IDE のセットアップ

1. [Arduino IDE](https://www.arduino.cc/en/software) をダウンロード・インストール

2. **ボードマネージャーの追加**
   - Arduino IDE を開く
   - 設定 (Preferences) → Additional Board Manager URLs に追加：
   ```
   https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
   ```

3. **ボードのインストール**
   - ツール → ボード → ボードマネージャー
   - "Seeed nRF52" を検索してインストール

4. **ボードを選択**
   - ツール → ボード → Seeed nRF52 Boards → "Seeed XIAO nRF52840"

### 2. ライブラリのインストール

ツール → ライブラリマネージャーで以下をインストール：
- Adafruit TinyUSB Library
- Adafruit nRF52 Library

### 3. コードを Arduino IDE 用に変換

firmware/src/main.cpp を Arduino スケッチとして開く：
1. main.cpp を main.ino にリネーム
2. Arduino IDE で開く

### 4. 書き込み

1. Xiao をブートローダーモードにする（リセットボタン2回押し）
2. ツール → ポート でポートを選択
3. スケッチ → マイコンボードに書き込む（または →ボタン）

---

## 方法3: UF2 ファイルを使う（最も簡単）

### 1. UF2 ファイルの入手

PlatformIO でビルド済みの場合：
```bash
cd firmware
pio run
# .pio/build/xiaoblesense_adafruit/firmware.uf2 が生成される
```

### 2. ドラッグ&ドロップで書き込み

1. Xiao をブートローダーモードにする（リセットボタン2回押し）
2. **XIAO-SENSE** というドライブが現れる
3. firmware.uf2 ファイルをドライブにドラッグ&ドロップ
4. 自動的に書き込まれて再起動

---

## トラブルシューティング

### ブートローダーモードに入れない
- リセットボタンをもっと素早く2回押す（ダブルクリック）
- USB ケーブルを変える（充電専用ケーブルではダメ）

### macOS で権限エラーが出る
```bash
# デバイスの権限を確認
ls -la /dev/cu.*

# 必要に応じて権限を追加
sudo chmod 666 /dev/cu.usbmodem*
```

### Windows でドライバーエラー
1. [Zadig](https://zadig.akeo.ie/) をダウンロード
2. Xiao を接続してブートローダーモードに
3. Zadig で WinUSB ドライバーをインストール

### Linux で権限エラー
```bash
# ユーザーを dialout グループに追加
sudo usermod -a -G dialout $USER
# ログアウト・ログインが必要
```

### ポートが見つからない
- ブートローダーモードになっているか確認（緑LED点滅）
- 別の USB ポートを試す
- USB ハブを使っている場合は直接接続

---

## 書き込み成功の確認

1. **LED の確認**
   - 青色点滅: BLE アドバタイジング中（正常動作）
   - 赤色点滅: エラー

2. **シリアルモニタで確認**
```bash
# PlatformIO の場合
pio device monitor -b 115200

# Arduino IDE の場合
ツール → シリアルモニタ（115200 baud）
```

表示例：
```
Xiao BLE Keyboard Firmware Starting...
Initializing USB HID...
USB HID initialized
Initializing BLE...
BLE initialized
Starting BLE advertising...
Advertising started
Setup complete. Ready for connections.
```

3. **PC での認識確認**

macOS:
```bash
# USB デバイスを確認
system_profiler SPUSBDataType | grep "Xiao"
```

Windows:
- デバイスマネージャー → ヒューマンインターフェイスデバイス
- "Xiao BLE Keyboard" が表示される

Linux:
```bash
lsusb | grep Seeed
```

---

## 初回書き込み後の再書き込み

初回書き込み後は、以下の方法で再書き込みできます：

1. **通常の書き込み**（ブートローダーモード不要）
```bash
pio run --target upload
```

2. **強制的にブートローダーモードへ**
   - リセットボタン2回押し（緑LED点滅）

---

## よくある質問

**Q: 書き込みに何分くらいかかる？**
A: 通常1-2分程度です。

**Q: 書き込み中に失敗したら？**
A: ブートローダーモードにして再度書き込みを実行してください。

**Q: 元のファームウェアに戻したい場合は？**
A: Seeed の公式サンプルコードを書き込めば戻せます。

**Q: 書き込み後に iOS アプリから見つからない**
A: BLE アドバタイジングが開始されているか、シリアルモニタで確認してください。