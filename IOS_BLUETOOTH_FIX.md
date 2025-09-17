# iOS Bluetooth 権限修正手順

## ❌ エラー: "Bluetooth not ready"

nRF Connect では見つかるのに、EasyKeyboard アプリで "Bluetooth not ready" エラーが出る問題の解決方法。

## ✅ 解決手順

### 1. Xcode でプロジェクト設定を開く

1. **EasyKeyboard.xcodeproj** を Xcode で開く
2. 左側のナビゲータで **EasyKeyboard** プロジェクトをクリック
3. **TARGETS** → **EasyKeyboard** を選択

### 2. Info.plist に Bluetooth 権限を追加

#### 方法A: Xcode GUI から追加

1. **Info** タブを選択
2. **Custom iOS Target Properties** セクション
3. **+** ボタンをクリックして以下を追加：

| Key | Type | Value |
|-----|------|-------|
| Privacy - Bluetooth Always Usage Description | String | This app uses Bluetooth to connect to your keyboard device |
| Privacy - Bluetooth Peripheral Usage Description | String | This app needs Bluetooth to communicate with the Xiao Keyboard |

#### 方法B: Info.plist ソースコードに直接追加

1. Info タブの右クリック → **Open As** → **Source Code**
2. `</dict>` タグの前に以下を追加：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect to your keyboard device</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to communicate with the Xiao Keyboard</string>
```

### 3. アプリの設定確認

1. **Signing & Capabilities** タブ
2. **Background Modes** を追加（まだない場合）
   - **+ Capability** → **Background Modes**
   - ✅ **Uses Bluetooth LE accessories**
   - ✅ **Acts as a Bluetooth LE accessory**

### 4. iOS デバイスの設定確認

#### iPhone の設定
1. **設定** → **プライバシーとセキュリティ** → **Bluetooth**
2. **EasyKeyboard** がリストにあることを確認
3. スイッチが **オン** になっていることを確認

#### アプリを完全削除して再インストール
1. iPhone から EasyKeyboard アプリを削除（長押し → ×）
2. Xcode から **Product** → **Clean Build Folder** (⌘⇧K)
3. **Product** → **Run** (⌘R) で再ビルド＆インストール

### 5. 初回起動時の権限リクエスト

アプリ初回起動時に以下のダイアログが表示されるはずです：
```
"EasyKeyboard" Would Like to Use Bluetooth
This app uses Bluetooth to connect to your keyboard device
[Don't Allow] [OK]
```

**必ず [OK] を選択**してください。

## 🔍 確認方法

### Xcode コンソールで確認
```
✅ "Bluetooth powered on" と表示される
✅ "Started scanning for ALL BLE devices" と表示される
✅ "Found device: Xiao Keyboard" と表示される
```

### アプリ画面で確認
- Scan ボタンを押すと "Xiao Keyboard" が表示される
- 接続すると青LEDが点灯に変わる

## 🚨 それでも動作しない場合

### iOS 14以降の追加設定

iOS 14以降では、さらに以下の権限が必要な場合があります：

```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>bluetooth-peripheral</string>
</array>
```

### CBCentralManager の初期化オプション

BLEManager.swift の初期化部分を確認：
```swift
centralManager = CBCentralManager(delegate: self, queue: nil, options: [
    CBCentralManagerOptionShowPowerAlertKey: true
])
```

## ✅ 最終チェックリスト

- [ ] NSBluetoothAlwaysUsageDescription 追加済み
- [ ] NSBluetoothPeripheralUsageDescription 追加済み
- [ ] Background Modes 設定済み
- [ ] iPhone の Bluetooth 設定で許可済み
- [ ] アプリを削除して再インストール済み
- [ ] 初回起動時に権限を許可済み
- [ ] Xcode コンソールで "Bluetooth powered on" 確認済み