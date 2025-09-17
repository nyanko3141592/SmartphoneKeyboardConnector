# BLE デバッグ手順

## 📱 nRF Connect アプリでの確認

1. **App Store から nRF Connect をダウンロード**
   - 「nRF Connect for Mobile」を検索
   - Nordic Semiconductor ASA 製のアプリ

2. **nRF Connect でスキャン**
   - アプリを開く
   - 「SCAN」ボタンをタップ
   - 「Xiao Keyboard」を探す

3. **デバイスが見つかった場合**
   - デバイス名: Xiao Keyboard
   - サービスUUID: 6E400001-B5A3-F393-E0A9-E50E24DCCA9E
   - RSSI値（信号強度）を確認

## 🔧 トラブルシューティング

### nRF Connect で見つかるが、アプリで見つからない場合

**iOS アプリの Bluetooth 権限を確認**：
```
設定 → プライバシーとセキュリティ → Bluetooth → EasyKeyboard
```

**iOS アプリを完全に再起動**：
1. アプリをタスクキルする（上にスワイプ）
2. Xcode から再ビルド

### nRF Connect でも見つからない場合

**ファームウェアを再書き込み**：
1. Xiao をリセット（リセットボタン1回押し）
2. シリアルモニタで起動メッセージを確認
3. 青LEDが点滅していることを確認

**iPhone の Bluetooth をリセット**：
1. 設定 → Bluetooth → オフ
2. 10秒待つ
3. Bluetooth → オン

## 📊 期待される表示

### シリアルモニタ（正常）
```
✅ BLE advertising started
✅ Blue LED blinking: Advertising
```

### nRF Connect アプリ
```
Device Name: Xiao Keyboard
Address: XX:XX:XX:XX:XX:XX
RSSI: -40 〜 -70 dBm
Services: Nordic UART Service
```

### iOS アプリ（EasyKeyboard）
```
Discovered Devices:
- Xiao Keyboard
```