# 白 0213SmartphoneKeyboardConnector

スマートフォンのソフトウェアキーボードを使用して PC に文字入力を行うシステム

## 概要

若い世代のスマートフォン入力の高速性を活かし、スマホのキーボードから PC へ直接テキスト入力を可能にするプロジェクトです。

## システム構成

```
[iOS アプリ] ---(Bluetooth LE)---> [Xiao nRF52840] ---(USB HID)---> [PC]
```

1. **iOS アプリ**: テキスト入力インターフェース
2. **Xiao BLE**: ブリッジデバイス（BLE → USB HID 変換）
3. **PC**: 標準キーボードとして認識

## プロジェクト構造

```
SmartphoneKeyboardConnector/
├── docs/                    # ドキュメント
│   ├── concept.md          # コンセプト
│   ├── implementation_strategy.md  # 実装方針
│   ├── implementation_plan.md      # 実装計画
│   ├── technology_selection.md     # 技術選定
│   └── roadmap.md          # ロードマップ
├── EasyKeyboard/           # iOS アプリ
│   ├── EasyKeyboard/
│   │   ├── EasyKeyboardApp.swift
│   │   ├── ContentView.swift
│   │   ├── BLEManager.swift
│   │   └── Assets.xcassets
│   └── EasyKeyboard.xcodeproj
└── firmware/               # Xiao BLE ファームウェア
    ├── src/
    │   ├── main.cpp
    │   ├── UnicodeKeyboard.h
    │   └── UnicodeKeyboard.cpp
    ├── platformio.ini
    └── README.md
```

## 必要な環境

### ハードウェア

- iPhone (iOS 14.0+)
- Seeed XIAO nRF52840
- USB Type-C ケーブル
- PC (Windows/macOS/Linux)

### ソフトウェア

- Xcode 14.0+
- Arduino IDE（推奨）
- iOS 14.0+

## セットアップ

### 1. ファームウェアの書き込み（Arduino IDE 推奨）

#### Arduino IDE のインストール
```bash
# macOS の場合
brew install --cask arduino
```

#### ボード設定
1. Arduino IDE → 設定
2. ボードマネージャーURL に追加：
   ```
   https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
   ```
3. ボードマネージャーで "Seeed nRF52" をインストール
4. ライブラリマネージャーで以下をインストール：
   - Adafruit TinyUSB Library
   - Adafruit Bluefruit nRF52 Libraries

#### 書き込み手順
```bash
# Arduino用スケッチを開く
open firmware/arduino_version/xiao_keyboard.ino
```

1. ボード：**Seeed XIAO nRF52840** を選択
2. Xiao BLE をブートローダーモード（リセットボタン2回押し、緑LED点滅）
3. 書き込み実行（⌘U）

詳細は [firmware/README.md](firmware/README.md) を参照

### 2. iOS アプリのセットアップ

```bash
cd EasyKeyboard
open EasyKeyboard.xcodeproj
```

1. Bluetooth 権限を Info.plist に追加
2. 実機でビルド・実行

詳細は [EasyKeyboard/README.md](EasyKeyboard/README.md) を参照

## 使用方法

1. **Xiao BLE を PC に接続**

   - USB キーボードとして自動認識されます

2. **iOS アプリを起動**

   - Bluetooth 権限を許可

3. **デバイスに接続**

   - "Connect" ボタンをタップ
   - リストから "Xiao Keyboard" を選択

4. **テキスト入力と送信**
   - テキストフィールドに入力
   - "Send to PC" ボタンで送信

## 主な機能

### 現在実装済み

- ✅ BLE 接続
- ✅ ASCII 文字送信
- ✅ 基本的な日本語入力対応
- ✅ 接続状態表示
- ✅ 自動再接続

### 開発中

- 🚧 完全な Unicode サポート
- 🚧 特殊文字対応
- 🚧 ショートカットキー
- 🚧 クリップボード同期

## 技術仕様

### BLE 通信

- **プロトコル**: Bluetooth 5.0
- **Service UUID**: `12345678-1234-5678-1234-56789ABCDEF0`
- **MTU**: 最大 247 バイト（ネゴシエーション後）

### USB HID

- **デバイスクラス**: HID キーボード
- **VID**: 0x2886 (Seeed)
- **PID**: 0x8044

## トラブルシューティング

### BLE 接続できない

- Xiao の電源確認
- iOS の Bluetooth 設定確認
- アプリの権限設定確認

### 文字が正しく入力されない

- PC の IME 設定確認
- キーボードレイアウト確認（US 配列推奨）

### ファームウェアが書き込めない

- ブートローダーモード（リセットボタン 2 回押し）
- PlatformIO のインストール確認

## 開発状況

現在は MVP (Minimum Viable Product) フェーズです。
詳細なロードマップは [docs/roadmap.md](docs/roadmap.md) を参照してください。

## コントリビューション

Issue や Pull Request を歓迎します。

## ライセンス

MIT License

## 参考資料

- [湯呑みキーボード](https://elchika.com/article/3f89039b-9ba0-434e-be37-6f00b9208ab6/)
- [Seeed XIAO nRF52840 Documentation](https://wiki.seeedstudio.com/XIAO_BLE/)
- [Core Bluetooth Documentation](https://developer.apple.com/documentation/corebluetooth)

## 作者

高橋直希

## 更新履歴

- 2025/09/17: 初期実装
