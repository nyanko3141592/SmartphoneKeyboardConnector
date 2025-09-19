# SmartphoneKeyboardConnector

スマートフォンから PC に Bluetooth でテキストを送信し、XIAO デバイス経由で USB キーボード入力として変換するシステム

## 概要

このプロジェクトは、スマートフォン（iOS）からのテキスト入力を Bluetooth Low Energy (BLE)で受信し、Seeed XIAO nRF52840 デバイスで USB HID キーボード信号に変換して PC に送信するシステムです。

## システム構成

```
[iPhone EasyKeyboard App] --BLE--> [XIAO nRF52840] --USB HID--> [PC]
```

## 必要なハードウェア

- **Seeed XIAO nRF52840** (または XIAO nRF52840 Sense)
- **iOS デバイス** (iPhone/iPad) - iOS 14 以降推奨
- **PC** (Windows/Mac/Linux)
- **USB-C ケーブル**（XIAO 接続用）

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

1. Arduino IDE をインストール
2. ボードマネージャー URL に追加:
   ```
   https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
   ```
3. ボードマネージャーで「Seeed nRF52」をインストール
4. 必要なライブラリをインストール:
   - Adafr i uit Bluefruit nRF52 Libraries
   - Adafruit TinyUSB Library

#### 書き込み手順

```bash
# ファームウェアを開く
open firmware/arduino_version/xiao_keyboard/xiao_keyboard.ino
```

1. ボード設定: **Seeed XIAO nRF52840**
2. Xiao をブートローダーモードにして USB 接続（リセットボタン 2 回押し）
3. 書き込み実行

### 2. iOS アプリビルド

```bash
cd EasyKeyboard
open EasyKeyboard.xcodeproj
```

1. Info.plist に Bluetooth 権限を追加（必要に応じて）
2. iOS デバイスでビルド＆実行

### 3. 接続・使用方法

1. **Xiao を PC に USB 接続** - USB キーボードとして認識される
2. **iOS アプリ起動** - Bluetooth 権限を許可
3. **BLE 接続** - "Connect"ボタンから"Xiao Keyboard"を選択
4. **テキスト送信** - アプリでテキスト入力して"Send to PC"

## 技術仕様

### iOS App

- **フレームワーク**: SwiftUI, Core Bluetooth
- **BLE サービス**: Nordic UART Service (6E400001-B5A3-F393-E0A9-E50E24DCCA9E)
- **対応文字**: ASCII 英数字、基本記号

### Firmware

- **開発環境**: Arduino IDE
- **ライブラリ**: Adafruit Bluefruit nRF52, Adafruit TinyUSB
- **プロトコル**: USB HID Boot Keyboard Protocol

## 開発状況

- ✅ **BLE 通信**: iOS ↔ XIAO 完了
- ✅ **USB 列挙**: nRF52840 TinyUSB ハング問題解決
- ⚠️ **HID 入力**: 実装完了、最終テスト中

詳細な開発履歴は [CHANGELOG.md](CHANGELOG.md) を参照してください。

## トラブルシューティング

### よくある問題

1. **BLE デバイスが見つからない**

   - iOS の Bluetooth 権限を確認
   - Xiao のシリアルモニタで"Advertising started"を確認

2. **USB HID が動作しない**

   - PC で Xiao が USB デバイスとして認識されているか確認
   - シリアル出力で"USB MOUNTED"状態を確認

3. **ファームウェアコンパイルエラー**
   - ボード設定が「Seeed XIAO nRF52840」になっているか確認
   - 必要なライブラリが正しくインストールされているか確認

## ライセンス

MIT License

## 作者

高橋直希 - 2025 年 1 月
