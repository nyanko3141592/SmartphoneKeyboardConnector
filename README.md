# SmartphoneKeyboardConnector

スマートフォンから PC に Bluetooth でテキストやマウス操作を送信し、XIAO デバイス経由で USB キーボード・マウス入力として変換するシステム

## 概要

このプロジェクトは、スマートフォン（iOS）からのテキスト入力やマウス操作を Bluetooth Low Energy (BLE) で受信し、Seeed XIAO nRF52840 デバイスで USB HID キーボード・マウス信号に変換して PC に送信するシステムです。最新のファームウェアは Adafruit TinyUSB の公式 HID キーボード例に準拠した初期化で安定動作します。

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
│       ├── xiao_keyboard/      # メイン: BLE→HID ブリッジ（最小構成にリファクタ済み）
│       ├── hid_minimal/        # 検証用: HIDのみ（Adafruit例と同等）
│       └── hid_ble_minimal/    # 検証用: 最小 BLE→HID（安定版の参照実装）
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

#### 書き込み手順（Arduino IDE）

```bash
# ファームウェアを開く
open firmware/arduino_version/xiao_keyboard/xiao_keyboard.ino
```

1. ボード設定: **Seeed XIAO nRF52840**（Sense でも可）
2. Xiao をブートローダーモードにして USB 接続（リセットボタン 2 回押し）
3. 書き込み実行

補足:

- HID 列挙の検証には `firmware/arduino_version/hid_minimal/` を、最小 BLE→HID の比較検証には `firmware/arduino_version/hid_ble_minimal/` を用意しています。

### 2. iOS アプリビルド

```bash
cd EasyKeyboard
open EasyKeyboard.xcodeproj
```

1. Info.plist に Bluetooth 権限を追加（必要に応じて）
2. iOS デバイスでビルド＆実行

### 3. 接続・使用方法

1. **Xiao を PC に USB 接続** - USB キーボード・マウスとして認識される
2. **iOS アプリ起動** - Bluetooth 権限を許可
3. **BLE 接続** - 接続ボタンからデバイスを選択
4. **機能選択**:
   - **テキスト入力モード**: テキストフィールドに入力して Send ボタンで送信
   - **キーボードモード**: 画面下部の仮想キーボードでタイピング。iPhone 縦画面などコンパクト幅ではキーボード上にミニトラックパッドが表示され、1 本指タップ=左クリック / 2 本指タップ=右クリック / 3 本指タップ=中クリックを送信可能。
   - **フリックモード**: 12 キーかな配列のフリックキーボードでローマ字出力。コンパクト幅では同じミニトラックパッドが上部に表示され、マウス操作とフリック入力を同時に行えます。
   - **マウスモード**: フルサイズのトラックパッドでカーソル操作、クリック、スクロール。タップジェスチャはキーボード/フリックのミニ版と共通で、1/2/3 本指タップが左・右・中クリックに対応します。

## 技術仕様

### iOS App

- **フレームワーク**: SwiftUI, Core Bluetooth
- **BLE サービス**: Nordic UART Service (6E400001-B5A3-F393-E0A9-E50E24DCCA9E)
- **入力モード**:
  - テキスト入力（直接入力・音声入力）
  - 仮想キーボード（文字、数字、特殊キー）
  - フリックキーボード（12 キー配列 → ローマ字変換、括弧=や行左右に配置）
  - マウス操作（フルサイズトラックパッド、スクロール、クリック）
- **対応文字**: ASCII 英数字、基本記号、Unicode 文字

### Firmware

- **開発環境**: Arduino IDE（Seeeduino nRF52 ボードパッケージ）
- **ライブラリ**: Adafruit Bluefruit nRF52, Adafruit TinyUSB
- **USB**: Boot Keyboard Protocol（HID）、マウスプロトコル（HID）
- **初期化順**: HID 初期化 → USB マウント待ち → BLE 開始（Adafruit 例と同等）

## 開発状況

- ✅ **BLE 通信**: iOS ↔ XIAO 完了
- ✅ **USB 列挙**: nRF52840 TinyUSB ハング問題解決
- ✅ **HID キーボード入力**: 安定化（Adafruit 例と同等の初期化に統一）
- ✅ **HID マウス入力**: カーソル移動、クリック、スクロール対応
- ✅ **iOS UI**: 4 モード切り替え（テキスト入力、キーボード、フリック、マウス）＋マルチタッチトラックパッド（1/2/3 本指タップ）

詳細な開発履歴は [CHANGELOG.md](CHANGELOG.md) を参照してください。

## トラブルシューティング

### よくある問題

1. **BLE デバイスが見つからない**

   - iOS の Bluetooth 権限を確認
   - Xiao のシリアルモニタで"Advertising started"を確認

2. **USB HID が動作しない**

   - macOS の「システム情報 > USB」で `HID Keyboard` と `HID Mouse` が出るか確認
   - 検証用 `hid_minimal` スケッチで HID 列挙を先に確認（A0〜A3 で矢印キー）
   - 列挙が不安定な場合はケーブル/ポートを変更、ハブ経由を避ける

3. **ファームウェアコンパイルエラー**
   - ボード設定が「Seeed XIAO nRF52840」になっているか確認
   - 必要なライブラリが正しくインストールされているか確認

## ライセンス

MIT License
