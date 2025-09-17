# 技術選定書

## 選定技術スタック

### iOS アプリケーション

#### 開発言語
- **選定**: Swift 5.9+
- **理由**:
  - iOS開発の標準言語
  - Core Bluetoothとの親和性
  - 型安全性と最新機能

#### UIフレームワーク
- **選定**: SwiftUI
- **理由**:
  - 宣言的UI
  - iOS 14+で安定
  - 将来性
- **代替案**: UIKit（複雑なカスタマイズが必要な場合）

#### 依存関係管理
- **選定**: Swift Package Manager
- **理由**:
  - Xcode統合
  - シンプルな設定
  - Apple公式

### Xiao BLE ファームウェア

#### ハードウェア
- **選定**: Seeed Xiao nRF52840
- **スペック**:
  - Nordic nRF52840 SoC
  - ARM Cortex-M4F 64MHz
  - 256KB RAM, 1MB Flash
  - Bluetooth 5.0
  - USB 2.0
- **理由**:
  - BLEとUSB両対応
  - Arduino互換
  - 小型・低消費電力

#### 開発環境
- **選定**: PlatformIO
- **理由**:
  - マルチプラットフォーム対応
  - ライブラリ管理機能
  - VSCode統合
- **代替案**: Arduino IDE（シンプルさ重視の場合）

#### フレームワーク
- **選定**: Arduino Framework + Adafruit nRF52
- **理由**:
  - 豊富なライブラリ
  - BLE/HID実装済み
  - コミュニティサポート

### 通信プロトコル

#### BLE仕様
- **バージョン**: Bluetooth 5.0
- **プロファイル**: カスタムGATTサービス
- **MTU**: 247バイト（ネゴシエーション後）
- **セキュリティ**: LE Secure Connections

#### データフォーマット
- **選定**: Protocol Buffers Lite
- **理由**:
  - 効率的なシリアライゼーション
  - スキーマ定義
  - 前方/後方互換性
- **代替案**: JSON（デバッグしやすさ重視の場合）

### 開発ツール

#### バージョン管理
- **選定**: Git + GitHub
- **ブランチ戦略**: GitHub Flow

#### CI/CD
- **iOS**: GitHub Actions + TestFlight
- **Firmware**: GitHub Actions + PlatformIO CI

#### コード品質
- **iOS**:
  - SwiftLint（コードスタイル）
  - SwiftFormat（自動フォーマット）
- **Firmware**:
  - cpplint（コードスタイル）
  - cppcheck（静的解析）

## 技術比較表

### BLEモジュール比較

| 項目 | Xiao nRF52840 | ESP32-C3 | Raspberry Pi Pico W |
|------|---------------|----------|---------------------|
| BLE | 5.0 | 5.0 | 5.2 |
| USB | Native | 要変換IC | Native |
| 消費電力 | ◎ | ○ | △ |
| 価格 | ¥2,000 | ¥1,500 | ¥1,800 |
| サイズ | 20x17.5mm | 25x18mm | 51x21mm |
| **総合評価** | **◎** | ○ | △ |

### iOSフレームワーク比較

| 項目 | SwiftUI | UIKit | React Native | Flutter |
|------|---------|-------|--------------|---------|
| 開発速度 | ◎ | ○ | ◎ | ◎ |
| パフォーマンス | ◎ | ◎ | ○ | ○ |
| BLE統合 | ◎ | ◎ | △ | △ |
| 学習曲線 | ○ | △ | ○ | △ |
| **総合評価** | **◎** | ○ | △ | △ |

### データ形式比較

| 項目 | Protocol Buffers | JSON | MessagePack | カスタムバイナリ |
|------|------------------|------|-------------|-----------------|
| サイズ効率 | ◎ | △ | ○ | ◎ |
| 可読性 | ○ | ◎ | △ | × |
| スキーマ | ◎ | △ | △ | × |
| ライブラリ | ◎ | ◎ | ○ | × |
| **総合評価** | **◎** | ○ | ○ | △ |

## ライブラリ選定

### iOS側ライブラリ

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.25.0"),
    .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.0"),
]
```

### Firmware側ライブラリ

```ini
; platformio.ini
lib_deps =
    adafruit/Adafruit nRF52 Library @ ^1.3.0
    nanopb/Nanopb @ ^0.4.8
    sandeepmistry/BLEPeripheral @ ^0.4.0
```

## セキュリティ考慮

### BLEセキュリティ
- **ペアリング**: Numeric Comparison
- **暗号化**: AES-CCM 128bit
- **認証**: MITM Protection有効

### アプリセキュリティ
- **キーチェーン**: デバイス情報保存
- **App Transport Security**: 有効
- **Code Signing**: 必須

## パフォーマンス要件

### レイテンシー目標
- BLE接続: < 500ms
- データ送信: < 50ms
- キーストローク反映: < 100ms

### 消費電力目標
- Xiao待機時: < 1mA
- アクティブ時: < 15mA
- iOS影響: バッテリー1%/時間以下

## 移行・互換性戦略

### 将来の拡張性
- Android対応準備
- Web Bluetooth API対応
- 他BLEデバイス対応

### バージョン互換性
- iOS: 14.0以上
- Bluetooth: 4.2以上（5.0推奨）
- USB: 2.0以上

## コスト分析

### 初期開発コスト
- Xiao nRF52840: ¥2,000
- Apple Developer Program: ¥12,980/年
- 開発機材: 既存利用

### 運用コスト
- App Store配信: Developer Program内
- アップデート: 工数のみ
- サポート: コミュニティベース

## リスク評価

### 技術的リスク
| 技術選定 | リスク | 軽減策 |
|----------|--------|--------|
| SwiftUI | iOS版依存 | UIKit fallback |
| nRF52840 | 供給不安定 | ESP32-C3代替 |
| Protocol Buffers | 学習コスト | JSON fallback |

## 決定事項サマリー

### 確定技術スタック
1. **iOS**: Swift + SwiftUI + Core Bluetooth
2. **Firmware**: Arduino (PlatformIO) + Adafruit nRF52
3. **通信**: BLE 5.0 + Protocol Buffers
4. **ハードウェア**: Seeed Xiao nRF52840

### 今後の検討事項
- テスト自動化ツール選定
- 分析ツール導入
- ドキュメント生成ツール