# Changelog

All notable changes to the SmartphoneKeyboardConnector project will be documented in this file.

## [Unreleased] - 2025-01-17

### Added
- iOS app (EasyKeyboard) with SwiftUI and Core Bluetooth
- XIAO nRF52840 firmware for BLE to USB HID conversion
- Nordic UART Service (NUS) for BLE communication
- Anti-freeze protection for nRF52840 TinyUSB issues
- Comprehensive debug output for troubleshooting
- Minimal HID-only Arduino sketch for enumeration test (`firmware/arduino_version/hid_minimal/`)
- Minimal BLE→HID bridge sketch added (`firmware/arduino_version/hid_ble_minimal/`) based on Adafruit HID example
- iOS: Immediate Send mode (per-character BLE send) and Unicode Mode (send U+XXXX codepoints)
- iOS: Immediate Clear toggle — 即時送信時に送信直後で入力欄を自動クリアできるオプションを追加
 - iOS: UIコンパクト化 — TextEditorを廃止し1行TextField化、Send/Testボタンを小型化
 - iOS: キーボードを閉じるボタン（TextEditor直下とキーボードアクセサリバーに追加）

### Changed
- Adjusted TinyUSB HID startup sequence to enumerate the keyboard interface reliably
- Aligned firmware BLE service/characteristic UUIDs with the iOS client configuration
- Switched Arduino sketch key handling to TinyUSB sendReport for deterministic HID output
- HID descriptor now uses explicit Report ID 1 and matching report_id in sendReport calls
- Removed blocking test key send in setup and added HID-ready guard to prevent main loop starvation
- Align USB HID init to Adafruit example: construct HID with descriptor, remove TinyUSBDevice.begin(), and use keyboardReport/keyboardRelease; fallback to Boot Keyboard descriptor (no Report ID)
- Switched from PlatformIO to Arduino IDE for firmware development
- Migrated from custom BLE service to Nordic UART Service for better compatibility
- Implemented simplified TinyUSB initialization to avoid enumeration hangs
- Added immediate BLE message processing to prevent message loss
 - Refactored main Arduino firmware to minimal HID-first, BLE-second init aligned with Adafruit HID example; reduced Serial usage to stabilize enumeration
 - iOS UI: Added toggles for Immediate Send and Unicode Mode; wired TextEditor on-change to per-character send when enabled

### Fixed
- BLE device discovery issues in iOS app
- HID enumeration infinite hang on XIAO nRF52840
- Multiple BLE message queuing problems
- Race condition in nRF52840 TinyUSB keyboardReport calls
- UUID mismatch between iOS app and firmware

### Technical Details

#### iOS App (EasyKeyboard)
- **Language**: Swift, SwiftUI
- **BLE Stack**: Core Bluetooth
- **Service**: Nordic UART Service (6E400001-B5A3-F393-E0A9-E50E24DCCA9E)
- **Text Characteristic**: 6E400002-B5A3-F393-E0A9-E50E24DCCA9E

#### Firmware (XIAO nRF52840)
- **Platform**: Arduino IDE with Seeed nRF52 Boards
- **Libraries**: Adafruit Bluefruit nRF52, Adafruit TinyUSB
- **BLE Service**: Nordic UART Service
- **USB HID**: Boot Keyboard Protocol

### Known Issues
- `usb_hid.ready()` always returns false on nRF52840 (worked around)
- TinyUSB keyboardReport may timeout under heavy load (protected by watchdog)
- iOS app discovers all BLE devices in debug mode (intentional for troubleshooting)

### Development Notes
- Original implementation used custom BLE service but switched to NUS for reliability
- Multiple iterations were required to solve nRF52840 TinyUSB enumeration and race condition issues
- Extensive research conducted on similar nRF52840 TinyUSB problems in the community

### Testing Status
- ✅ BLE communication: iOS ↔ XIAO working
- ✅ USB enumeration: No more infinite hangs
- ⚠️ USB HID output: Implementation complete, testing in progress
- ⚠️ End-to-end functionality: Pending final verification

---

## Project Structure
```
SmartphoneKeyboardConnector/
├── EasyKeyboard/           # iOS SwiftUI app
├── firmware/
│   └── arduino_version/
│       └── xiao_keyboard/  # Arduino firmware for XIAO nRF52840
├── docs/                   # Project documentation
└── CHANGELOG.md           # This file
```
