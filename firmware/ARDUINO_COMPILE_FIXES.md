# Arduino IDE コンパイルエラー修正ガイド

## エラー1: `requestConnectionParameter` 引数エラー

### エラーメッセージ
```
error: no matching function for call to 'BLEConnection::requestConnectionParameter(int, int, int, int)'
candidate expects 3 arguments, 4 provided
```

### 修正内容
```cpp
// ❌ 間違い（4つの引数）
conn->requestConnectionParameter(8, 16, 0, 200);

// ✅ 正しい（3つの引数）
conn->requestConnectionParameter(8, 0, 200);
```

**修正済み**: `xiao_keyboard.ino` の317行目を修正しました。

---

## エラー2: ライブラリの重複

### エラーメッセージ
```
Multiple libraries were found for "Adafruit_TinyUSB.h"
 Used: /Users/takahashinaoki/Documents/Arduino/libraries/Adafruit_TinyUSB_Library
 Not used: /Users/takahashinaoki/Library/Arduino15/packages/Seeeduino/hardware/nrf52/1.1.10/libraries/Adafruit_TinyUSB_Arduino
```

### 解決方法

#### 方法1: 手動でライブラリを削除
```bash
# 重複しているライブラリを削除
rm -rf ~/Documents/Arduino/libraries/Adafruit_TinyUSB_Library
```

#### 方法2: Arduino IDE でライブラリを管理
1. **ツール** → **ライブラリを管理**
2. **Adafruit TinyUSB** を検索
3. 複数バージョンがある場合は最新版のみ残す
4. 古いバージョンをアンインストール

#### 方法3: ライブラリパスの優先順位確認
Arduino IDE がライブラリを検索する順序：
1. `~/Documents/Arduino/libraries/` (ユーザーライブラリ)
2. `~/Library/Arduino15/packages/*/libraries/` (ボード付属ライブラリ)

---

## 修正後のコンパイル手順

### 1. 修正の確認
- `xiao_keyboard.ino` の317行目が以下になっていることを確認：
```cpp
conn->requestConnectionParameter(8, 0, 200);
```

### 2. ライブラリ重複の解決
```bash
# 重複ライブラリを削除
rm -rf ~/Documents/Arduino/libraries/Adafruit_TinyUSB_Library
```

### 3. Arduino IDE を再起動
- Arduino IDE を完全に終了
- 再度開いて `xiao_keyboard.ino` を読み込み

### 4. 再コンパイル
- **スケッチ** → **検証・コンパイル** (⌘R)

---

## 成功時の出力例

```
スケッチの検証が終了しました
スケッチが使用する容量: 123456 バイト (プログラム格納領域の 12%)
グローバル変数が 12345 バイト (4%) のメモリを使用。ローカル変数は 123456 バイト使用可能。
```

---

## その他のよくあるエラーと対処法

### エラー3: `TUD_HID_REPORT_DESC_KEYBOARD` が見つからない
```cpp
// 対処法: インクルード順序を確認
#include <bluefruit.h>
#include <Adafruit_TinyUSB.h>  // この順序が重要
```

### エラー4: `CHR_PROPS_WRITE` が定義されていない
```cpp
// 対処法: Bluefruit ライブラリの再インストール
// ツール → ライブラリを管理 → Adafruit Bluefruit nRF52 Libraries
```

### エラー5: ポートが見つからない
```bash
# デバイス確認
ls /dev/cu.*

# Xiao BLE をブートローダーモードに
# リセットボタンを素早く2回押す（緑LED点滅）
```

---

## 完全クリーンアップ（最後の手段）

### ライブラリとボードの完全削除
```bash
# Arduino関連データを全削除
rm -rf ~/Library/Arduino15
rm -rf ~/Documents/Arduino

# Arduino IDE 再インストール
brew uninstall --cask arduino
brew install --cask arduino
```

### セットアップの再実行
1. ボードマネージャーURL追加
2. Seeed nRF52 ボードインストール
3. 必要ライブラリインストール
4. ボード選択
5. コンパイル

---

## デバッグオプション

### 詳細エラー出力を有効にする
1. **File** → **Preferences**
2. ✅ **Show verbose output during compilation**
3. ✅ **Show verbose output during upload**

これでより詳細なエラー情報が表示されます。