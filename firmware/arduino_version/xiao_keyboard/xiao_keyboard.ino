/*
 * Xiao BLE Keyboard Firmware - Simple Version
 *
 * Simplified approach to avoid TinyUSB enumeration issues
 * Based on working examples from Seeed documentation
 */

#include <bluefruit.h>
#include <Adafruit_TinyUSB.h>

// BLE Service & Characteristics UUIDs - Nordic UART Service
#define SERVICE_UUID        "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHAR_UUID_TEXT      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"

// HID report descriptor for keyboard
uint8_t const desc_hid_report[] = {
    TUD_HID_REPORT_DESC_KEYBOARD()
};

// USB HID
Adafruit_USBD_HID usb_hid;

// Nordic UART Service を使用
BLEUart bleuart;

// Text buffer
#define TEXT_BUFFER_SIZE 256
char textBuffer[TEXT_BUFFER_SIZE];
volatile bool hasNewText = false;

// Connection status
bool bleConnected = false;

void setup() {
    Serial.begin(115200);

    // Wait for serial or timeout (3 seconds)
    unsigned long startTime = millis();
    while (!Serial && (millis() - startTime < 3000)) {
        delay(10);
    }

    Serial.println("=== Xiao BLE Keyboard Starting (Simple Version) ===");

    // Setup USB HID FIRST with minimal configuration
    setupUSBSimple();

    // Setup BLE
    setupBLE();

    // Start advertising
    startAdvertising();

    Serial.println("Setup complete. Ready for connections.");

    // Simple test
    if (TinyUSBDevice.mounted()) {
        Serial.println("USB mounted - sending test 'h'");
        delay(2000);
        sendSimpleKey('h');
    }
}

void loop() {
    // Process received text
    if (hasNewText) {
        hasNewText = false;

        if (TinyUSBDevice.mounted()) {
            Serial.print("Sending: ");
            Serial.println(textBuffer);
            sendSimpleText(textBuffer);
        } else {
            Serial.println("USB not mounted");
        }

        // Clear buffer
        memset(textBuffer, 0, TEXT_BUFFER_SIZE);
    }

    delay(10);
}

void setupUSBSimple() {
    Serial.println("Setting up USB HID (simple)...");

    // Very basic setup
    usb_hid.setPollInterval(2);
    usb_hid.setReportDescriptor(desc_hid_report, sizeof(desc_hid_report));
    usb_hid.begin();

    // Start USB
    TinyUSBDevice.begin(0);

    // Wait for mount - short timeout
    Serial.print("Waiting for USB");
    for (int i = 0; i < 30; i++) {
        if (TinyUSBDevice.mounted()) break;
        delay(100);
        Serial.print(".");
    }
    Serial.println();

    Serial.print("USB Status: ");
    Serial.println(TinyUSBDevice.mounted() ? "MOUNTED" : "NOT MOUNTED");
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
    if (!TinyUSBDevice.mounted()) {
        Serial.println("USB not mounted");
        return;
    }

    uint8_t keycode = 0;
    uint8_t modifier = 0;

    // Simple character to keycode conversion
    if (c >= 'a' && c <= 'z') {
        keycode = 0x04 + (c - 'a');
    } else if (c >= 'A' && c <= 'Z') {
        modifier = 0x02; // Shift
        keycode = 0x04 + (c - 'A');
    } else if (c >= '1' && c <= '9') {
        keycode = 0x1E + (c - '1');
    } else if (c == '0') {
        keycode = 0x27;
    } else if (c == ' ') {
        keycode = 0x2C;
    } else {
        Serial.print("Unsupported char: ");
        Serial.println(c);
        return;
    }

    Serial.print("Sending key: ");
    Serial.print(c);
    Serial.print(" (0x");
    Serial.print(keycode, HEX);
    Serial.println(")");

    // Simple approach - direct report
    uint8_t keycodes[6] = {keycode, 0, 0, 0, 0, 0};

    // Press
    bool result1 = usb_hid.keyboardReport(0, modifier, keycodes);
    delay(20);

    // Release
    uint8_t empty[6] = {0};
    bool result2 = usb_hid.keyboardReport(0, 0, empty);
    delay(20);

    Serial.print("Results: press=");
    Serial.print(result1 ? "OK" : "FAIL");
    Serial.print(", release=");
    Serial.println(result2 ? "OK" : "FAIL");
}

void sendSimpleText(const char* text) {
    for (int i = 0; text[i] != '\0'; i++) {
        sendSimpleKey(text[i]);
        delay(50);
    }
}

void ble_uart_rx_callback(uint16_t conn_handle) {
    char data[TEXT_BUFFER_SIZE];
    uint16_t len = bleuart.read(data, TEXT_BUFFER_SIZE - 1);

    if (len > 0) {
        data[len] = '\0';
        strncpy(textBuffer, data, TEXT_BUFFER_SIZE - 1);
        textBuffer[TEXT_BUFFER_SIZE - 1] = '\0';
        hasNewText = true;

        Serial.print("BLE received: ");
        Serial.println(textBuffer);
    }
}