# Arduino IDE セットアップ トラブルシューティング

## エラー: `bluefruit.h: No such file or directory`

このエラーは **ボード設定が間違っている** か **ライブラリがインストールされていない** ことが原因です。

### 🔧 解決手順

#### 1. ボードマネージャーの設定確認

1. **Arduino IDE** → **設定** (Preferences)
2. **追加のボードマネージャのURL** に以下が追加されているか確認：
   ```
   https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
   ```

#### 2. Seeed nRF52 ボードのインストール

1. **ツール** → **ボード** → **ボードマネージャー**
2. 検索欄に "**seeed nrf52**" と入力
3. **Seeed nRF52 Boards by Seeed Studio** を見つけてインストール
4. インストール完了まで待つ（数分かかる場合があります）

#### 3. 正しいボードを選択

1. **ツール** → **ボード** → **Seeed nRF52 Boards** → **Seeed XIAO nRF52840**
2. ボード名が Arduino IDE のタイトルバーに表示されることを確認

現在の設定: `Board: "Arduino Micro"` ❌
正しい設定: `Board: "Seeed XIAO nRF52840"` ✅

#### 4. ライブラリのインストール確認

1. **ツール** → **ライブラリを管理**
2. 以下がインストール済みか確認：
   - **Adafruit TinyUSB Library** (by Adafruit)
   - **Adafruit Bluefruit nRF52 Libraries** (by Adafruit)

#### 5. 再コンパイル

正しいボードを選択後、再度コンパイル：
- **スケッチ** → **検証・コンパイル** (⌘R)

---

## 詳細なセットアップ手順

### ステップ1: Arduino IDE の準備

```bash
# Arduino IDE がインストールされていない場合
brew install --cask arduino
```

### ステップ2: ボードマネージャーURL追加

1. Arduino IDE を開く
2. **Arduino IDE** → **設定** を選択
3. **追加のボードマネージャのURL** 欄をクリック
4. 以下のURLを追加：
   ```
   https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
   ```
5. **OK** をクリック

### ステップ3: ボードのインストール

1. **ツール** → **ボード** → **ボードマネージャー** を選択
2. 上部の検索欄に "**seeed nrf52**" と入力
3. **Seeed nRF52 Boards by Seeed Studio** が表示される
4. **インストール** ボタンをクリック
5. ダウンロード完了まで待つ（インターネット接続必要）

### ステップ4: ライブラリのインストール

1. **ツール** → **ライブラリを管理** を選択
2. **Adafruit TinyUSB Library** を検索してインストール
3. **Adafruit Bluefruit nRF52 Libraries** を検索してインストール

### ステップ5: ボード選択

1. **ツール** → **ボード** を選択
2. **Seeed nRF52 Boards** カテゴリを展開
3. **Seeed XIAO nRF52840** を選択
4. Arduino IDE のタイトルバーに表示されることを確認

---

## 確認方法

### ボード設定の確認
Arduino IDE のタイトル部分に以下が表示されればOK：
```
Arduino IDE - Board: "Seeed XIAO nRF52840" on ...
```

### ライブラリの確認
```cpp
// このコードがエラーなくコンパイルできれば成功
#include <bluefruit.h>
#include <Adafruit_TinyUSB.h>

void setup() {
  // 空でOK
}

void loop() {
  // 空でOK
}
```

---

## よくあるエラーと解決法

### エラー1: `Package index download failed`
**原因**: インターネット接続の問題
**解決法**:
- Wi-Fi接続を確認
- ファイアウォール設定を確認
- しばらく時間をおいて再試行

### エラー2: ボードマネージャーに "Seeed nRF52" が表示されない
**原因**: ボードマネージャーURLが正しく追加されていない
**解決法**:
- 設定でURLを再確認
- Arduino IDE を再起動
- ボードマネージャーを再読み込み

### エラー3: `Compilation error: 'Bluefruit' was not declared in this scope`
**原因**: ライブラリがインストールされていない
**解決法**:
- Adafruit Bluefruit nRF52 Libraries を再インストール
- Arduino IDE を再起動

### エラー4: `avrdude: stk500_recv(): programmer is not responding`
**原因**: 間違ったボードが選択されている
**解決法**:
- ボード設定を **Seeed XIAO nRF52840** に変更
- ポート設定を確認

---

## 緊急時の代替方法

### 方法1: Arduino IDE の完全再インストール
```bash
# 現在のArduino IDE を削除
rm -rf ~/Library/Arduino15
brew uninstall --cask arduino

# 再インストール
brew install --cask arduino
```

### 方法2: 別バージョンのArduino IDE を試す
Arduino IDE 2.x 系を試す場合：
```bash
brew install --cask arduino-ide
```

### 方法3: 手動でライブラリをダウンロード
1. [Adafruit GitHub](https://github.com/adafruit/Adafruit_nRF52_Arduino) からZIPをダウンロード
2. **スケッチ** → **ライブラリをインクルード** → **.ZIP形式のライブラリをインストール**

---

## 成功の確認

最終的に以下が表示されれば成功：

```
コンパイルが完了しました。

スケッチが使用する容量: XXXXX バイト (プログラム格納領域の XX%)
グローバル変数が XXXXX バイト (XX%) のメモリを使用。ローカル変数は XXXXX バイト使用可能。
```

**次のステップ**: Xiao BLE をブートローダーモードにして書き込み実行