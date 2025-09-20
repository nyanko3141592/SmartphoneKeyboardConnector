/*
 * Xiao BLE Keyboard Firmware - Simple Version
 *
 * Simplified approach to avoid TinyUSB enumeration issues
 * Based on working examples from Seeed documentation
 */

#include <Adafruit_TinyUSB.h>
#include <bluefruit.h>

// BLE Service & Characteristics UUIDs - Nordic UART Service
#define SERVICE_UUID        "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHAR_UUID_TEXT      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"

// HID report descriptor for keyboard
// Fallback to boot keyboard descriptor (no Report ID)
uint8_t const desc_hid_report[] = {
    TUD_HID_REPORT_DESC_KEYBOARD()
};

// USB HID instance constructed with descriptor (matches Adafruit example)
Adafruit_USBD_HID usb_hid(desc_hid_report, sizeof(desc_hid_report), HID_ITF_PROTOCOL_KEYBOARD, 2, false);

// Nordic UART Service を使用
BLEUart bleuart;

// Text buffer
#define TEXT_BUFFER_SIZE 256
char textBuffer[TEXT_BUFFER_SIZE];
volatile bool hasNewText = false;

// Connection status
bool bleConnected = false;

void setup() {
    // Start HID first (align with Adafruit example)
    usb_hid.begin();
    while (!TinyUSBDevice.mounted()) { delay(1); }

    // BLE setup
    Bluefruit.begin();
    Bluefruit.setName("Xiao Keyboard");

    bleuart.begin();
    bleuart.setRxCallback(ble_uart_rx_callback);

    // Advertising
    Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
    Bluefruit.Advertising.addTxPower();
    Bluefruit.Advertising.addService(bleuart);
    Bluefruit.Advertising.addName();
    Bluefruit.Advertising.restartOnDisconnect(true);
    Bluefruit.Advertising.setInterval(32, 244);
    Bluefruit.Advertising.setFastTimeout(30);
    Bluefruit.Advertising.start(0);
}

void loop() {
    if (hasNewText) {
        hasNewText = false;
        sendSimpleText(textBuffer);
        memset(textBuffer, 0, TEXT_BUFFER_SIZE);
    }
    delay(2);
}

void setupUSBSimple() {
    Serial.println("Setting up USB HID (nRF52840 optimized)...");

    // Begin HID as in Adafruit example; core handles TinyUSB device init
    usb_hid.begin();

    // Extended wait for nRF52840 enumeration
    Serial.print("Waiting for USB mount");
    unsigned long start = millis();
    while (!TinyUSBDevice.mounted() && (millis() - start < 10000)) {
        delay(100);
        Serial.print(".");
    }
    Serial.println();

    if (TinyUSBDevice.mounted()) {
        Serial.println("✅ USB mounted");

        // Critical: Wait for full enumeration
        Serial.print("Waiting for HID enumeration");
        start = millis();
        while ((millis() - start < 5000)) {
            delay(100);
            Serial.print(".");
            // Don't exit early even if ready() is true
        }
        Serial.println();

        Serial.println("✅ HID enumeration complete");
    }

    Serial.print("Final Status - USB: ");
    Serial.print(TinyUSBDevice.mounted() ? "MOUNTED" : "NOT MOUNTED");
    Serial.print(", HID: ");
    Serial.println(usb_hid.ready() ? "READY" : "NOT READY");
}

void setupBLE() {
    Serial.println("Setting up BLE...");

    Bluefruit.begin();
    Bluefruit.setTxPower(4);
    Bluefruit.setName("Xiao Keyboard");

    // Setup Nordic UART Service
    bleuart.begin();
    bleuart.setRxCallback(ble_uart_rx_callback);

    Serial.println("BLE initialized");
}

void startAdvertising() {
    Serial.println("Starting advertising...");

    Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
    Bluefruit.Advertising.addTxPower();
    Bluefruit.Advertising.addService(bleuart);
    Bluefruit.Advertising.addName();

    Bluefruit.Advertising.restartOnDisconnect(true);
    Bluefruit.Advertising.setInterval(32, 244);
    Bluefruit.Advertising.setFastTimeout(30);
    Bluefruit.Advertising.start(0);

    Serial.println("Advertising started");
}

void sendSimpleKey(char c) {
    if (TinyUSBDevice.suspended()) TinyUSBDevice.remoteWakeup();
    if (!usb_hid.ready()) return;

    uint8_t keycode = 0;
    uint8_t modifier = 0;
    bool handled = true;

    if (c >= 'a' && c <= 'z') {
        keycode = 0x04 + (c - 'a');
    } else if (c >= 'A' && c <= 'Z') {
        modifier = 0x02; // Shift
        keycode = 0x04 + (c - 'A');
    } else if (c >= '1' && c <= '9') {
        keycode = 0x1E + (c - '1');
    } else if (c == '0') {
        keycode = 0x27;
    } else {
        switch (c) {
            case ' ': keycode = 0x2C; break;
            case '\n':
            case '\r': keycode = 0x28; break;
            case '\b': keycode = 0x2A; break; // Backspace
            case '\t': keycode = 0x2B; break; // Tab
            case '-': keycode = 0x2D; break;
            case '=': keycode = 0x2E; break;
            case '[': keycode = 0x2F; break;
            case ']': keycode = 0x30; break;
            case '\\': keycode = 0x31; break;
            case ';': keycode = 0x33; break;
            case '\'': keycode = 0x34; break;
            case '`': keycode = 0x35; break;
            case ',': keycode = 0x36; break;
            case '.': keycode = 0x37; break;
            case '/': keycode = 0x38; break;
            default:
                handled = false;
                break;
        }
    }

    if (!handled || keycode == 0) {
        return;
    }

    uint8_t keycodes[6] = {keycode, 0, 0, 0, 0, 0};
    usb_hid.keyboardReport(0, modifier, keycodes);
    delay(6);
    usb_hid.keyboardRelease(0);
    delay(6);
}

void sendSimpleText(const char* text) {
    if (!text) return;
    for (int i = 0; text[i] != '\0'; i++) {
        sendSimpleKey(text[i]);
        delay(12);
    }
}

void ble_uart_rx_callback(uint16_t conn_handle) {
    char data[TEXT_BUFFER_SIZE];
    uint16_t len = bleuart.read(data, TEXT_BUFFER_SIZE - 1);

    if (len > 0) {
        data[len] = '\0';
        if (!hasNewText) {
            strncpy(textBuffer, data, TEXT_BUFFER_SIZE - 1);
            textBuffer[TEXT_BUFFER_SIZE - 1] = '\0';
            hasNewText = true;
        }
    }
}
