# SmartphoneKeyboardConnector

スマートフォンからPCにBluetoothでテキストを送信し、XIAOデバイス経由でUSBキーボード入力として変換するシステム

## 概要

このプロジェクトは、スマートフォン（iOS）からのテキスト入力をBluetooth Low Energy (BLE)で受信し、Seeed XIAO nRF52840デバイスでUSB HIDキーボード信号に変換してPCに送信するシステムです。

## システム構成

```
[iPhone EasyKeyboard App] --BLE--> [XIAO nRF52840] --USB HID--> [PC]
```

## 必要なハードウェア

- **Seeed XIAO nRF52840** (または XIAO nRF52840 Sense)
- **iOS デバイス** (iPhone/iPad) - iOS 14以降推奨
- **PC** (Windows/Mac/Linux)
- **USB-Cケーブル**（XIAO接続用）

## プロジェクト構造

```
SmartphoneKeyboardConnector/
├── EasyKeyboard/           # iOS SwiftUI アプリ
├── firmware/
│   └── arduino_version/
│       └── xiao_keyboard/  # Arduino IDE用ファームウェア
├── docs/                   # プロジェクトドキュメント
├── CHANGELOG.md           # 開発履歴
└── README.md              # このファイル
```

## セットアップ

### 1. ファームウェア書き込み

#### Arduino IDE セットアップ
1. Arduino IDEをインストール
2. ボードマネージャーURLに追加:
   ```
   https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
   ```
3. ボードマネージャーで「Seeed nRF52」をインストール
4. 必要なライブラリをインストール:
   - Adafruit Bluefruit nRF52 Libraries
   - Adafruit TinyUSB Library

#### 書き込み手順
```bash
# ファームウェアを開く
open firmware/arduino_version/xiao_keyboard/xiao_keyboard.ino
```

1. ボード設定: **Seeed XIAO nRF52840**
2. XiaoをブートローダーモードにしてUSB接続（リセットボタン2回押し）
3. 書き込み実行

### 2. iOSアプリビルド

```bash
cd EasyKeyboard
open EasyKeyboard.xcodeproj
```

1. Info.plistにBluetooth権限を追加（必要に応じて）
2. iOSデバイスでビルド＆実行

### 3. 接続・使用方法

1. **XiaoをPCにUSB接続** - USBキーボードとして認識される
2. **iOSアプリ起動** - Bluetooth権限を許可
3. **BLE接続** - "Connect"ボタンから"Xiao Keyboard"を選択
4. **テキスト送信** - アプリでテキスト入力して"Send to PC"

## 技術仕様

### iOS App
- **フレームワーク**: SwiftUI, Core Bluetooth
- **BLEサービス**: Nordic UART Service (6E400001-B5A3-F393-E0A9-E50E24DCCA9E)
- **対応文字**: ASCII英数字、基本記号

### Firmware
- **開発環境**: Arduino IDE
- **ライブラリ**: Adafruit Bluefruit nRF52, Adafruit TinyUSB
- **プロトコル**: USB HID Boot Keyboard Protocol

## 開発状況

- ✅ **BLE通信**: iOS ↔ XIAO 完了
- ✅ **USB列挙**: nRF52840 TinyUSBハング問題解決
- ⚠️ **HID入力**: 実装完了、最終テスト中

詳細な開発履歴は [CHANGELOG.md](CHANGELOG.md) を参照してください。

## トラブルシューティング

### よくある問題

1. **BLEデバイスが見つからない**
   - iOSのBluetooth権限を確認
   - Xiaoのシリアルモニタで"Advertising started"を確認

2. **USB HIDが動作しない**
   - PCでXiaoがUSBデバイスとして認識されているか確認
   - シリアル出力で"USB MOUNTED"状態を確認

3. **ファームウェアコンパイルエラー**
   - ボード設定が「Seeed XIAO nRF52840」になっているか確認
   - 必要なライブラリが正しくインストールされているか確認

## ライセンス

MIT License

## 作者

高橋直希 - 2025年1月