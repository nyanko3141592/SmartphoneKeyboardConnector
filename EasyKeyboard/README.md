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
5. "Send to PC" ボタンで送信

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