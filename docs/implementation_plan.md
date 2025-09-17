# 実装計画書

## プロジェクト構成

### リポジトリ構造
```
SmartphoneKeyboardConnector/
├── ios-app/              # iOSアプリケーション
│   ├── KeyboardConnector/
│   ├── KeyboardConnector.xcodeproj
│   └── Tests/
├── firmware/             # Xiao BLEファームウェア
│   ├── src/
│   ├── lib/
│   └── platformio.ini
├── docs/                 # ドキュメント
├── tools/                # 開発支援ツール
└── examples/             # サンプルコード
```

## 実装フェーズ

### Phase 1: 基盤構築

#### 1.1 開発環境セットアップ
- [ ] Xcodeプロジェクト作成
- [ ] PlatformIOプロジェクト作成
- [ ] Git リポジトリ初期化
- [ ] CI/CD パイプライン設定

#### 1.2 プロトタイプ実装
- [ ] iOS: 基本UIの実装（テキストフィールド＋送信ボタン）
- [ ] Firmware: BLE advertising実装
- [ ] iOS-Firmware: BLE接続確立

### Phase 2: コア機能実装

#### 2.1 iOS アプリケーション
```swift
// 主要クラス構造
class BLEManager {
    // BLE接続管理
    func scanForDevices()
    func connect(to device: CBPeripheral)
    func sendText(_ text: String)
}

class KeyboardViewController {
    // UI制御
    @IBOutlet weak var textField: UITextField
    func sendButtonTapped()
}

class TextEncoder {
    // Unicode エンコーディング
    func encodeToUTF8(_ text: String) -> Data
}
```

#### 2.2 Xiao BLE ファームウェア
```cpp
// 主要モジュール構造
class BLEService {
    void begin();
    void advertise();
    void onReceive(uint8_t* data, size_t length);
};

class HIDKeyboard {
    void begin();
    void sendUnicodeString(const char* str);
    void sendKeyStroke(uint8_t key);
};

class TextBuffer {
    void push(const char* text);
    bool hasData();
    String pop();
};
```

### Phase 3: 統合テスト

#### 3.1 機能テスト項目
- [ ] BLE接続の安定性
- [ ] 日本語入力の正確性
- [ ] 特殊文字の対応
- [ ] 長文送信の動作
- [ ] 複数デバイス切り替え

#### 3.2 性能テスト項目
- [ ] レイテンシー測定
- [ ] スループット測定
- [ ] バッテリー消費測定
- [ ] メモリ使用量測定

### Phase 4: 品質向上

#### 4.1 UX改善
- [ ] 接続状態のビジュアル表示
- [ ] エラーメッセージの最適化
- [ ] ショートカット機能
- [ ] 履歴機能（オプション）

#### 4.2 安定性向上
- [ ] 自動再接続機能
- [ ] エラーリカバリー
- [ ] メモリリーク対策
- [ ] クラッシュレポート実装

## 実装詳細

### iOS アプリケーション実装計画

#### Core Bluetooth実装
```swift
// BLE通信の基本実装
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager)
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral)
}

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?)
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic)
}
```

#### UI実装
- SwiftUIまたはUIKit選択
- ダークモード対応
- Dynamic Type対応
- 横向き対応

### Xiao BLE ファームウェア実装計画

#### BLE GATT設計
```cpp
// サービスとキャラクタリスティック定義
#define SERVICE_UUID        "12345678-1234-5678-1234-56789abcdef0"
#define CHAR_UUID_TEXT      "12345678-1234-5678-1234-56789abcdef1"
#define CHAR_UUID_STATUS    "12345678-1234-5678-1234-56789abcdef2"
```

#### USB HID実装
```cpp
// HIDレポートディスクリプタ
const uint8_t HID_REPORT_DESCRIPTOR[] = {
    0x05, 0x01,  // Usage Page (Generic Desktop)
    0x09, 0x06,  // Usage (Keyboard)
    // ... 標準キーボード記述子
};
```

## テストケース設計

### ユニットテスト
- iOS: XCTest使用
- Firmware: Unity Test Framework使用

### 統合テスト
- 実機による手動テスト
- 自動化可能な部分はXCUITest使用

### 受け入れテスト
- ユーザーシナリオベース
- 実使用環境でのテスト

## リスク管理

### 技術的リスク
| リスク | 影響度 | 対策 |
|--------|--------|------|
| BLE接続不安定 | 高 | リトライロジック実装 |
| Unicode変換エラー | 中 | フォールバック機構 |
| HIDドライバ非互換 | 低 | 標準仕様準拠 |

### プロジェクトリスク
| リスク | 影響度 | 対策 |
|--------|--------|------|
| Xiao BLE在庫切れ | 中 | 代替ボード調査 |
| iOS審査リジェクト | 中 | ガイドライン確認 |

## デバッグ・トラブルシューティング計画

### デバッグツール
- iOS: Xcode Instruments
- BLE: nRF Connect
- Firmware: Serial Monitor
- パケット: Wireshark

### ログ設計
```swift
// iOS ログレベル
enum LogLevel {
    case debug, info, warning, error
}
```

```cpp
// Firmware ログマクロ
#define LOG_DEBUG(msg) if(LOG_LEVEL >= 4) Serial.println(msg)
#define LOG_ERROR(msg) if(LOG_LEVEL >= 1) Serial.println(msg)
```

## メンテナンス計画

### 定期更新
- iOS: OS アップデート対応
- Firmware: ライブラリ更新
- ドキュメント: 変更反映

### 監視項目
- クラッシュレート
- 接続成功率
- ユーザーフィードバック