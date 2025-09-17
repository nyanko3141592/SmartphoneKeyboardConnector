# Python パスエラーの修正

## エラー: `exec: "python": executable file not found in $PATH`

Arduino IDE が Python コマンドを見つけられない問題の解決方法です。

## 🔧 解決方法

### 方法1: シェル設定ファイルに PATH を追加（推奨）

```bash
# ~/.zshrc に Python パスを追加
echo 'export PATH="/opt/homebrew/opt/python@3.13/libexec/bin:$PATH"' >> ~/.zshrc

# 設定を反映
source ~/.zshrc

# Python コマンドの確認
which python
```

### 方法2: Arduino IDE を Terminal から起動

Python パスを設定してから Arduino IDE を起動：

```bash
# パスを設定
export PATH="/opt/homebrew/opt/python@3.13/libexec/bin:$PATH"

# Arduino IDE を起動
open -a Arduino

# または直接実行
/Applications/Arduino.app/Contents/MacOS/Arduino
```

### 方法3: 環境変数設定ファイルを作成

```bash
# 環境変数設定ファイルを作成
cat > ~/.arduino_env << 'EOF'
export PATH="/opt/homebrew/opt/python@3.13/libexec/bin:$PATH"
EOF

# Arduino IDE 起動前に読み込み
source ~/.arduino_env && open -a Arduino
```

## 🚀 完全な修正手順

### 1. Python パスを追加
```bash
echo 'export PATH="/opt/homebrew/opt/python@3.13/libexec/bin:$PATH"' >> ~/.zshrc
```

### 2. ターミナルを再起動またはソース実行
```bash
source ~/.zshrc
```

### 3. Python コマンドの確認
```bash
which python
# 出力: /opt/homebrew/opt/python@3.13/libexec/bin/python
```

### 4. Arduino IDE を再起動
1. 現在の Arduino IDE を完全に終了
2. ターミナルから Arduino IDE を起動：
```bash
open -a Arduino
```

### 5. 再コンパイル
- スケッチを開く: `firmware/arduino_version/xiao_keyboard/xiao_keyboard.ino`
- **スケッチ** → **検証・コンパイル** (⌘R)

## ✅ 成功の確認

### 修正が成功した場合の出力：
```
スケッチの検証が終了しました
スケッチが使用する容量: XXXXX バイト (プログラム格納領域の XX%)
グローバル変数が XXXXX バイト (XX%) のメモリを使用。ローカル変数は XXXXX バイト使用可能。
```

### 問題が解決されたかの確認：
1. ❌ `exec: "python": executable file not found in $PATH` エラーが表示されない
2. ❌ `Multiple libraries were found` 警告が表示されない
3. ✅ コンパイルが正常完了

## 🔧 追加のトラブルシューティング

### Intel Mac の場合
```bash
# Homebrew のパスが異なる場合
echo 'export PATH="/usr/local/opt/python@3.13/libexec/bin:$PATH"' >> ~/.zshrc
```

### 他の Python インストール方法
```bash
# システム Python のシンボリックリンク作成（管理者権限必要）
sudo ln -sf /usr/bin/python3 /usr/local/bin/python

# pyenv を使用している場合
pyenv global 3.13.7
pyenv rehash
```

### Arduino IDE の Python 設定確認
1. **Arduino IDE** → **設定**
2. **Show verbose output during compilation** を有効
3. コンパイル時に Python のパスを確認

## 📋 次のステップ

1. ✅ Python パス修正完了
2. ✅ ライブラリ重複解決完了
3. 🔄 Arduino IDE でコンパイル実行
4. 📱 Xiao BLE への書き込み

これで Arduino IDE でのコンパイルが成功するはずです！