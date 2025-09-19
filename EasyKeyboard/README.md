# EasyKeyboard iOS App

スマートフォンのソフトウェアキーボードを使用して PC に文字入力を送信する iOS アプリケーション

## セットアップ手順

### 1. Xcode プロジェクトの設定

#### Bluetooth 権限の追加

Xcode でプロジェクトを開き、以下の設定を行ってください：

1. プロジェクトナビゲータで `EasyKeyboard` プロジェクトを選択
2. `Info` タブを選択
3. `Custom iOS Target Properties` セクションに以下のキーを追加：

```
NSBluetoothAlwaysUsageDescription
値: "This app uses Bluetooth to connect to your keyboard device"

NSBluetoothPeripheralUsageDescription
値: "This app needs Bluetooth to communicate with the Xiao BLE keyboard"
```

または、プロジェクトの `Info.plist` ソースコードに直接追加：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect to your keyboard device</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to communicate with the Xiao BLE keyboard</string>
```

### 2. Capabilities の設定

1. プロジェクト設定の `Signing & Capabilities` タブを選択
2. `+ Capability` をクリック
3. `Background Modes` を追加
4. 以下のオプションをチェック：
   - `Uses Bluetooth LE accessories`
   - `Acts as a Bluetooth LE accessory` (必要に応じて)

### 3. Minimum Deployment Target

- iOS 14.0 以上に設定

## プロジェクト構造

```
EasyKeyboard/
├── EasyKeyboardApp.swift    # アプリのエントリーポイント
├── ContentView.swift        # メインUI
├── BLEManager.swift        # Bluetooth通信管理
└── Assets.xcassets        # アセット
```

## 主要コンポーネント

### BLEManager
- Core Bluetooth を使用した BLE 通信管理
- デバイススキャン、接続、データ送信機能
- 自動再接続機能

### ContentView
- テキスト入力インターフェース
- デバイス選択UI
- 接続状態表示

## 使用方法

1. アプリを起動
2. "Connect" ボタンをタップ
3. Xiao BLE デバイスを選択
4. テキストを入力
5. 必要に応じて以下のモードを切り替え
   - "Immediate Send (per character)": 入力のたびに文字単位で即時送信
     - 併用オプション: "Immediate Clear (after send)" — 送信直後に入力欄を自動クリア
   - "Unicode Mode (send U+XXXX)": 送信内容を Unicode 符号位置 (U+XXXX) 列に変換して送信
   - "テキストフィールドなしモード（QWERTYボタン）":
     - 画面下部にキーボードを表示（四角いキー、全面がタップ判定）
     - レイアウトは `keyboard-layout.json`（アプリバンドル内）に基づく
     - 文字キーは即時送信、Backspace/Enter/Tabはそれぞれ特殊送信
6. バッチ送信する場合は "Send to PC" ボタンで送信

### キーイベント送信について
- バックスペース: テキストが短くなった（削除）と検知した場合、ASCII Backspace(0x08)を送信します
- リターン(Enter): Returnキー押下時に改行(\n)を送信します
  - いずれもファームウェア側で適切にHIDキーへマッピングされている必要があります

## 必要な環境

- Xcode 14.0 以上
- iOS 14.0 以上の実機
- Bluetooth 対応デバイス

## ビルドと実行

```bash
# Xcode でプロジェクトを開く
open EasyKeyboard.xcodeproj

# または Xcode から直接実行
# Product > Run (⌘R)
```

## トラブルシューティング

### Bluetooth 権限が求められない場合
- Settings > Privacy > Bluetooth でアプリの権限を確認
- デバイスを再起動

### デバイスが見つからない場合
- Xiao BLE の電源を確認
- Bluetooth が有効になっているか確認
- デバイスが他のデバイスに接続されていないか確認

### 即時送信で日本語入力が乱れる
- IME の変換中はテキストが頻繁に書き換わるため、即時送信で望まない文字列が送られる場合があります。
- 日本語/中国語/韓国語などの変換入力時は即時送信をオフにしてバッチ送信をご利用ください。
- Unicode モードはコードポイント列を送るだけなので、受信側（ファームウェア）が対応していない場合は文字入力になりません。
