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

// HID report descriptor for keyboard
uint8_t const desc_hid_report[] = {
    TUD_HID_REPORT_DESC_KEYBOARD()
};

// USB HID
Adafruit_USBD_HID usb_hid;

// Nordic UART Service を使用
BLEUart bleuart;

// HID report ID for keyboard (use 0 for boot keyboard)
#define RID_KEYBOARD 0

// Text buffer
#define TEXT_BUFFER_SIZE 256
char textBuffer[TEXT_BUFFER_SIZE];
volatile bool hasNewText = false;

// Keyboard report は不要（keyboardReport メソッドを使用）
// uint8_t keyReport[8] = { 0 };

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
        Serial.println("\nUSB mounted! Waiting 2 seconds before test...");
        delay(2000);  // 2秒待ってからテスト（PCの認識を待つ）

        Serial.println("Sending test text: 'hello'");
        sendText("hello");
        Serial.println("Auto test completed");
        Serial.println("You should see 'hello' typed in any focused text field!");
    } else {
        Serial.println("\nUSB not mounted after 10 seconds, skipping auto test");
    }
}

void loop() {
    // Manual task processing for TinyUSB
    TinyUSBDevice.task();

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

    // Setup HID interface FIRST
    usb_hid.setPollInterval(1);  // Faster polling
    usb_hid.setReportDescriptor(desc_hid_report, sizeof(desc_hid_report));
    usb_hid.setStringDescriptor("TinyUSB Keyboard");

    // Use boot protocol for maximum compatibility
    usb_hid.setBootProtocol(HID_ITF_PROTOCOL_KEYBOARD);
    usb_hid.begin();

    // Initialize USB device
    TinyUSBDevice.begin(0);

    // Wait for USB mount with manual task processing
    Serial.print("Waiting for USB mount");
    unsigned long startTime = millis();
    while (!TinyUSBDevice.mounted() && (millis() - startTime < 20000)) {
        TinyUSBDevice.task();  // Manual task processing
        delay(50);
        Serial.print(".");
    }
    Serial.println();

    if (TinyUSBDevice.mounted()) {
        Serial.println("✅ USB device mounted");

        // Wait for HID enumeration with timeout and status check
        Serial.print("Waiting for HID enumeration");
        unsigned long hidStart = millis();
        bool hidReady = false;

        while ((millis() - hidStart < 5000)) {  // 5 second timeout
            TinyUSBDevice.task();
            delay(100);
            Serial.print(".");

            if (usb_hid.ready()) {
                hidReady = true;
                break;
            }

            // Status check every second
            if ((millis() - hidStart) % 1000 < 100) {
                Serial.print("[");
                Serial.print((millis() - hidStart) / 1000);
                Serial.print("s]");
            }
        }

        Serial.println();
        if (hidReady) {
            Serial.println("✅ USB HID ready!");
        } else {
            Serial.println("⚠️ USB HID timeout, but will try to continue");
            Serial.println("   This is often normal - HID may still work");
        }

        Serial.println("✅ USB HID initialization complete");
    } else {
        Serial.println("❌ USB mount failed after 20 seconds");
    }

    Serial.print("Final status - USB mounted: ");
    Serial.print(TinyUSBDevice.mounted() ? "YES" : "NO");
    Serial.print(", HID ready: ");
    Serial.println(usb_hid.ready() ? "YES" : "NO");
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
    // Check if USB is mounted and HID is ready
    if (!TinyUSBDevice.mounted()) {
        Serial.println("Error: USB device not mounted");
        return;
    }

    // Manual task processing for better reliability
    TinyUSBDevice.task();

    // Try to wait for HID to be ready, but don't fail if it's not
    unsigned long start = millis();
    bool hidReadyNow = false;
    while (!hidReadyNow && (millis() - start < 50)) {
        TinyUSBDevice.task();
        hidReadyNow = usb_hid.ready();
        if (!hidReadyNow) delay(1);
    }

    if (!hidReadyNow) {
        Serial.println("  HID not ready, trying anyway...");
    } else {
        Serial.println("  HID ready");
    }

    Serial.print("  Sending keycode: ");
    Serial.print(keycode, HEX);
    Serial.print(", modifier: ");
    Serial.println(modifier, HEX);

    // Create HID keyboard report
    uint8_t keycode_arr[6] = {keycode, 0, 0, 0, 0, 0};

    // Key press
    bool press_result = usb_hid.keyboardReport(RID_KEYBOARD, modifier, keycode_arr);
    Serial.print("    Press result: ");
    Serial.println(press_result ? "success" : "failed");

    // Always try to send release, regardless of press result
    delay(10);
    TinyUSBDevice.task();

    // Key release - send empty report
    uint8_t empty_keys[6] = {0, 0, 0, 0, 0, 0};
    bool release_result = usb_hid.keyboardReport(RID_KEYBOARD, 0, empty_keys);
    Serial.print("    Release result: ");
    Serial.println(release_result ? "success" : "failed");

    delay(50);  // Longer delay between keys
}

void sendText(const char* text) {
    if (!text || strlen(text) == 0) {
        Serial.println("Warning: Empty text received");
        return;
    }

    Serial.print("Processing ");
    Serial.print(strlen(text));
    Serial.println(" characters...");

    // USB接続状態を確認
    if (!TinyUSBDevice.mounted()) {
        Serial.println("Error: USB not connected");
        return;
    }

    Serial.println("Sending text via USB HID...");
    Serial.println("Make sure a text field is focused on your PC!");

    for (size_t i = 0; i < strlen(text); i++) {
        char c = text[i];
        uint8_t modifier = 0;
        uint8_t keycode = charToKeycode(c, modifier);

        if (keycode != 0) {
            Serial.print("  Char: '");
            Serial.print(c);
            Serial.print("' -> ");
            sendKeyPress(keycode, modifier);
        } else {
            Serial.print("Warning: Unsupported character: '");
            Serial.print(c);
            Serial.print("' (0x");
            Serial.print((int)c, HEX);
            Serial.println(")");
        }

        // Small delay between characters for reliability
        delay(10);
    }

    Serial.println("Text sending complete!");
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