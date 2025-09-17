/*
 * Xiao BLE Keyboard Firmware - Arduino IDE Version
 *
 * Bluetooth LE から受信したテキストを USB HID キーボード入力として送信
 *
 * 必要なライブラリ:
 * - Adafruit TinyUSB Library
 * - Adafruit Bluefruit nRF52 Libraries
 *
 * ボード設定:
 * - Seeed XIAO nRF52840
 */

#include <bluefruit.h>
#include <Adafruit_TinyUSB.h>

// BLE Service & Characteristics UUIDs - Nordic UART Service
#define SERVICE_UUID        "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHAR_UUID_TEXT      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"

// USB HID
Adafruit_USBD_HID usb_hid;

// HID report descriptor for keyboard
const uint8_t hid_report_descriptor[] PROGMEM = {
    TUD_HID_REPORT_DESC_KEYBOARD()
};

// Nordic UART Service を使用
BLEUart bleuart;

// Text buffer
#define TEXT_BUFFER_SIZE 256
char textBuffer[TEXT_BUFFER_SIZE];
volatile bool hasNewText = false;

// Keyboard report
uint8_t keyReport[8] = { 0 };

// Connection status
bool bleConnected = false;
bool usbConnected = false;

// Function prototypes
void setupBLE();
void setupUSB();
void startAdvertising();
void sendKeyPress(uint8_t keycode, uint8_t modifier = 0);
void sendText(const char* text);
uint8_t charToKeycode(char c, uint8_t& modifier);

// BLE callbacks
void connect_callback(uint16_t conn_handle);
void disconnect_callback(uint16_t conn_handle, uint8_t reason);
void text_write_callback(uint16_t conn_hdl, BLECharacteristic* chr, uint8_t* data, uint16_t len);

void setup() {
    // Initialize serial for debugging
    Serial.begin(115200);

    // Wait for serial or timeout (3 seconds)
    unsigned long startTime = millis();
    while (!Serial && (millis() - startTime < 3000)) {
        delay(10);
    }

    Serial.println("=== Xiao BLE Keyboard Starting ===");
    Serial.println("Firmware: Arduino IDE Version");
    Serial.println("Device: Seeed XIAO nRF52840");

    // Initialize USB HID
    setupUSB();

    // Initialize BLE
    setupBLE();

    // Start advertising
    startAdvertising();

    Serial.println("Setup complete. Ready for connections.");
    Serial.println("- Blue LED blinking: Advertising");
    Serial.println("- Blue LED solid: Connected");
    Serial.println("=====================================");

    // デバッグ用: USB接続を待ってからテスト
    Serial.println("Waiting for USB connection for auto test...");
    unsigned long testStartTime = millis();
    while (!TinyUSBDevice.mounted() && (millis() - testStartTime < 10000)) {
        delay(100);
        Serial.print(".");
    }

    if (TinyUSBDevice.mounted()) {
        Serial.println("\nUSB mounted! Sending test text: 'hello'");
        delay(1000);  // 1秒待ってからテスト
        sendText("hello");
        Serial.println("Auto test completed");
    } else {
        Serial.println("\nUSB not mounted after 10 seconds, skipping auto test");
    }
}

void loop() {
    // Check USB connection status
    if (TinyUSBDevice.mounted() != usbConnected) {
        usbConnected = TinyUSBDevice.mounted();
        Serial.print("USB ");
        Serial.println(usbConnected ? "connected" : "disconnected");
    }

    // Process received text
    if (hasNewText) {
        hasNewText = false;

        if (usbConnected) {
            Serial.print("Sending text: \"");
            Serial.print(textBuffer);
            Serial.println("\"");
            sendText(textBuffer);
            Serial.println("Text sent successfully");
        } else {
            Serial.println("Warning: USB not connected, text not sent");
        }

        // Clear buffer
        memset(textBuffer, 0, TEXT_BUFFER_SIZE);
    }

    // Small delay to prevent tight loop
    delay(10);
}

void setupBLE() {
    Serial.println("Initializing BLE...");

    // Initialize Bluefruit
    Bluefruit.begin();
    Bluefruit.setTxPower(4);    // Maximum power for better range
    Bluefruit.setName("Xiao Keyboard");

    // Set connection callbacks
    Bluefruit.Periph.setConnectCallback(connect_callback);
    Bluefruit.Periph.setDisconnectCallback(disconnect_callback);

    // Setup Nordic UART Service
    bleuart.begin();
    bleuart.setRxCallback(ble_uart_rx_callback);

    Serial.println("BLE initialized");
    Serial.println("Nordic UART Service started");
    Serial.print("Service UUID: ");
    Serial.println("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
    Serial.print("RX Characteristic UUID: ");
    Serial.println("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
    Serial.print("Device name: ");
    Serial.println("Xiao Keyboard");
}

void setupUSB() {
    Serial.println("Initializing USB HID...");

    // Initialize USB device
    TinyUSBDevice.begin();

    // Setup HID interface
    usb_hid.setPollInterval(2);
    usb_hid.setReportDescriptor(hid_report_descriptor, sizeof(hid_report_descriptor));
    usb_hid.begin();

    // Wait for USB mount with timeout
    unsigned long startTime = millis();
    while (!TinyUSBDevice.mounted() && (millis() - startTime < 5000)) {
        delay(1);
    }

    if (TinyUSBDevice.mounted()) {
        Serial.println("USB HID initialized successfully");
    } else {
        Serial.println("Warning: USB HID initialization timeout");
    }
}

void startAdvertising() {
    Serial.println("Starting BLE advertising...");

    // Configure advertising packet
    Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
    Bluefruit.Advertising.addTxPower();
    Bluefruit.Advertising.addService(bleuart);  // Nordic UARTサービスを追加
    Bluefruit.Advertising.addName();

    // Configure advertising intervals
    // Unit of 0.625 ms: 32 = 20ms, 244 = 152.5ms
    Bluefruit.Advertising.restartOnDisconnect(true);
    Bluefruit.Advertising.setInterval(32, 244);
    Bluefruit.Advertising.setFastTimeout(30);      // 30 seconds in fast mode
    Bluefruit.Advertising.start(0);                // 0 = Don't stop advertising

    Serial.println("BLE advertising started");
    Serial.println("Looking for devices in 'EasyKeyboard' iOS app...");
}

void sendKeyPress(uint8_t keycode, uint8_t modifier) {
    if (!usb_hid.ready()) {
        Serial.println("Warning: USB HID not ready");
        return;
    }

    // Press key
    keyReport[0] = modifier;        // Modifier keys
    keyReport[1] = 0;               // Reserved
    keyReport[2] = keycode;         // Key code
    // keyReport[3-7] remain 0      // Additional keys

    usb_hid.sendReport(0, keyReport, sizeof(keyReport));
    delay(10);

    // Release key
    keyReport[0] = 0;
    keyReport[2] = 0;
    usb_hid.sendReport(0, keyReport, sizeof(keyReport));
    delay(10);
}

void sendText(const char* text) {
    if (!text || strlen(text) == 0) {
        Serial.println("Warning: Empty text received");
        return;
    }

    Serial.print("Processing ");
    Serial.print(strlen(text));
    Serial.println(" characters...");

    for (size_t i = 0; i < strlen(text); i++) {
        char c = text[i];
        uint8_t modifier = 0;
        uint8_t keycode = charToKeycode(c, modifier);

        if (keycode != 0) {
            sendKeyPress(keycode, modifier);
        } else {
            Serial.print("Warning: Unsupported character: '");
            Serial.print(c);
            Serial.print("' (0x");
            Serial.print((int)c, HEX);
            Serial.println(")");
        }

        // Small delay between characters for reliability
        delay(5);
    }
}

uint8_t charToKeycode(char c, uint8_t& modifier) {
    modifier = 0;

    // Lowercase letters (a-z)
    if (c >= 'a' && c <= 'z') {
        return 0x04 + (c - 'a');  // HID_KEY_A = 0x04
    }
    // Uppercase letters (A-Z)
    else if (c >= 'A' && c <= 'Z') {
        modifier = 0x02; // Left Shift
        return 0x04 + (c - 'A');
    }
    // Numbers 1-9
    else if (c >= '1' && c <= '9') {
        return 0x1E + (c - '1');  // HID_KEY_1 = 0x1E
    }
    // Number 0
    else if (c == '0') {
        return 0x27;  // HID_KEY_0
    }
    // Common special characters
    else if (c == ' ') {
        return 0x2C;  // HID_KEY_SPACE
    }
    else if (c == '\n' || c == '\r') {
        return 0x28;  // HID_KEY_ENTER
    }
    else if (c == '\t') {
        return 0x2B;  // HID_KEY_TAB
    }
    else if (c == '.') {
        return 0x37;  // HID_KEY_PERIOD
    }
    else if (c == ',') {
        return 0x36;  // HID_KEY_COMMA
    }
    else if (c == '!') {
        modifier = 0x02; // Left Shift
        return 0x1E;     // 1 key
    }
    else if (c == '?') {
        modifier = 0x02; // Left Shift
        return 0x38;     // Forward slash key
    }
    else if (c == '-') {
        return 0x2D;  // HID_KEY_MINUS
    }
    else if (c == '=') {
        return 0x2E;  // HID_KEY_EQUAL
    }
    else if (c == ';') {
        return 0x33;  // HID_KEY_SEMICOLON
    }
    else if (c == '\'') {
        return 0x34;  // HID_KEY_APOSTROPHE
    }
    else if (c == '/') {
        return 0x38;  // HID_KEY_SLASH
    }

    // Unsupported character
    return 0;
}

// BLE Connection Callbacks
void connect_callback(uint16_t conn_handle) {
    BLEConnection* conn = Bluefruit.Connection(conn_handle);

    char central_name[32] = { 0 };
    conn->getPeerName(central_name, sizeof(central_name));

    Serial.print("BLE connected to: ");
    Serial.println(central_name[0] ? central_name : "Unknown Device");
    Serial.println("Available services:");
    Serial.println("  - Nordic UART Service (6E400001-B5A3-F393-E0A9-E50E24DCCA9E)");
    Serial.println("  - Text Characteristic (6E400002-B5A3-F393-E0A9-E50E24DCCA9E)");

    bleConnected = true;

    // Request higher connection interval for better performance
    conn->requestConnectionParameter(8, 0, 200);
}

void disconnect_callback(uint16_t conn_handle, uint8_t reason) {
    Serial.print("BLE disconnected, reason: 0x");
    Serial.println(reason, HEX);

    bleConnected = false;

    // Will automatically restart advertising due to restartOnDisconnect(true)
}

void ble_uart_rx_callback(uint16_t conn_handle) {
    Serial.println("=== BLE UART DATA RECEIVED ===");

    // Read all available data
    char data[TEXT_BUFFER_SIZE];
    uint16_t len = bleuart.read(data, TEXT_BUFFER_SIZE - 1);

    Serial.print("Connection handle: ");
    Serial.println(conn_handle);
    Serial.print("Data length: ");
    Serial.print(len);
    Serial.println(" bytes");

    if (len == 0) {
        Serial.println("Warning: No data available");
        return;
    }

    // Null terminate
    data[len] = '\0';

    // Copy to global buffer
    strncpy(textBuffer, data, TEXT_BUFFER_SIZE - 1);
    textBuffer[TEXT_BUFFER_SIZE - 1] = '\0';

    // Print received text (for debugging)
    Serial.print("Text content: \"");
    Serial.print(textBuffer);
    Serial.println("\"");

    hasNewText = true;
}