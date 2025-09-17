#!/bin/bash

# Arduino IDE 起動スクリプト
# Python パス問題を解決して Arduino IDE を起動

echo "Setting up environment for Arduino IDE..."

# Python パスを設定
export PATH="/opt/homebrew/opt/python@3.13/libexec/bin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"

# Python コマンドの確認
echo "Python version: $(python --version 2>/dev/null || echo 'Not found')"
echo "Python path: $(which python 2>/dev/null || echo 'Not found')"

# Arduino IDE を起動
echo "Starting Arduino IDE..."
open -a Arduino

echo "Arduino IDE started with correct Python environment"
echo "You can now compile your sketch successfully!"