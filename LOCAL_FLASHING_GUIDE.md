# 📱 Local Firmware Flashing Guide

## 🎯 Overview

This guide covers three methods for flashing firmware to the Xiao BLE locally:
1. **Arduino IDE** (Recommended for development)
2. **UF2 File** (Easiest for end users)
3. **PlatformIO** (Advanced developers)

## 🚀 Method 1: Arduino IDE (Development)

### Prerequisites
- Arduino IDE installed
- Seeed nRF52 boards package
- Required libraries

### Setup Steps

1. **Install Board Package**
```
File → Preferences → Additional Boards Manager URLs
Add: https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json

Tools → Board → Boards Manager → Search "Seeed nRF52" → Install
```

2. **Install Libraries**
```
Tools → Manage Libraries → Install:
- Adafruit TinyUSB Library
- Adafruit Bluefruit nRF52 Libraries
```

3. **Solve Python PATH Issue**
```bash
# Use the startup script
cd /path/to/SmartphoneKeyboardConnector
./start_arduino.sh
```

### Compilation & Upload

1. **Open Sketch**
```
File → Open → firmware/arduino_version/xiao_keyboard/xiao_keyboard.ino
```

2. **Configure Board**
```
Tools → Board → Seeed nRF52 Boards → Seeed XIAO nRF52840
```

3. **Compile**
```
Sketch → Verify/Compile (⌘R)
```

4. **Prepare Device**
- Connect Xiao BLE via USB-C
- Double-press reset button (green LED blinking)

5. **Select Port & Upload**
```
Tools → Port → /dev/cu.usbmodem*
Sketch → Upload (⌘U)
```

6. **Verify**
```
Tools → Serial Monitor (115200 baud)
Expected output:
=== Xiao BLE Keyboard Starting ===
USB HID initialized successfully
BLE initialized
Setup complete. Ready for connections.
```

## 📦 Method 2: UF2 File (Easy)

### Download Firmware

**Option A: From GitHub Releases**
1. Go to: https://github.com/USERNAME/SmartphoneKeyboardConnector/releases
2. Download `xiao-keyboard-firmware.uf2`

**Option B: Automated Download**
```bash
#!/bin/bash
# download_latest_firmware.sh

curl -s https://api.github.com/repos/USERNAME/SmartphoneKeyboardConnector/releases/latest \
  | grep "browser_download_url.*uf2" \
  | cut -d '"' -f 4 \
  | xargs curl -L -o xiao-keyboard-latest.uf2

echo "✅ Downloaded: xiao-keyboard-latest.uf2"
```

### Flash Process

1. **Connect Device**
- USB-C cable to computer
- Double-press reset button
- Green LED should blink

2. **Verify Bootloader Mode**
- Finder shows "XIAO-SENSE" drive
- Or check: `ls /Volumes/XIAO-SENSE`

3. **Flash Firmware**
- Drag `xiao-keyboard-firmware.uf2` to XIAO-SENSE drive
- Device automatically reboots
- Blue LED starts blinking (BLE advertising)

4. **Verification**
- Connect via serial monitor or iOS app
- Device should appear as "Xiao Keyboard"

## ⚙️ Method 3: PlatformIO (Advanced)

### Prerequisites
```bash
pip install platformio
```

### Build & Flash

```bash
cd firmware
pio run                    # Build
pio run -t upload         # Upload via USB
```

### Generate UF2
```bash
pio run
# UF2 file: .pio/build/xiaoblesense_adafruit/firmware.uf2
```

## 🔧 Quick Deploy Script

```bash
#!/bin/bash
# quick_deploy.sh

echo "🚀 Building and deploying firmware..."

# Build locally
cd firmware
pio run

# Check build result
if [ -f ".pio/build/xiaoblesense_adafruit/firmware.uf2" ]; then
    echo "✅ Firmware built successfully"
    echo "📱 Ready to flash:"
    echo "   1. Double-press Xiao reset button"
    echo "   2. Drag firmware.uf2 to XIAO-SENSE drive"
    open .pio/build/xiaoblesense_adafruit/
else
    echo "❌ Build failed"
    exit 1
fi
```

## 🐛 Troubleshooting

### Arduino IDE Issues

**Python Not Found**
```bash
# Solution: Use startup script
./start_arduino.sh
```

**Permission Denied**
```bash
# Already fixed - tools have execute permissions
# If issue persists:
chmod +x /Users/takahashinaoki/Library/Arduino15/packages/Seeeduino/hardware/nrf52/1.1.10/tools/adafruit-nrfutil/macos/adafruit-nrfutil
```

**Board Not Found**
- Ensure Seeed nRF52 package installed
- Select correct board: Tools → Board → Seeed XIAO nRF52840

### Device Issues

**Port Not Detected**
```bash
# Check available ports
ls /dev/cu.*

# Put device in bootloader mode
# Double-press reset button (green LED blinking)
```

**Upload Fails**
1. Verify bootloader mode (green LED)
2. Check USB cable connection
3. Try different USB port
4. Restart Arduino IDE

**Device Not Responding**
1. Hold reset button for 10 seconds
2. Double-press reset for bootloader
3. Re-flash firmware

### UF2 Method Issues

**Drive Not Appearing**
- Try different USB cable
- Double-press reset more quickly
- Check USB port functionality

**Flash Appears Successful But Device Not Working**
- Verify UF2 file integrity
- Check for corrupted download
- Try re-downloading firmware

## 📊 LED Status Reference

| LED Color | Status | Meaning |
|-----------|--------|---------|
| Green Blinking | Bootloader | Ready for firmware upload |
| Blue Blinking | BLE Advertising | Waiting for device connection |
| Blue Solid | BLE Connected | Successfully connected to device |
| No LED | USB Mode | Acting as USB HID keyboard |

## 🎯 Best Practices

### For Development
1. Use Arduino IDE with startup script
2. Keep Serial Monitor open for debugging
3. Test both USB HID and BLE modes

### For Production
1. Use stable releases from GitHub
2. Verify firmware signature/checksum
3. Document firmware version in use

### For Distribution
1. Include installation video tutorial
2. Provide multiple download sources
3. Test on different operating systems

## 📝 Next Steps After Flashing

1. **Test USB HID Mode**
   - Connect to PC via USB
   - Verify keyboard input works

2. **Test BLE Mode**
   - Install iOS "EasyKeyboard" app
   - Pair with Xiao device
   - Send test messages

3. **Configure Device**
   - Adjust connection parameters if needed
   - Set device name via BLE commands
   - Configure key mappings

This completes the local firmware flashing workflow for all skill levels and use cases.