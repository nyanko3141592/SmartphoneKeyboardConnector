/*
 * Simple Xiao BLE Keyboard Firmware
 *
 * Simplified version for easier compilation
 */

#include <Arduino.h>
#include <bluefruit.h>
#include <Adafruit_TinyUSB.h>

// BLE Service & Characteristics UUIDs (Nordic UART Service to match iOS client)
#define SERVICE_UUID        "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHAR_UUID_TEXT      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"

// USB HID
Adafruit_USBD_HID usb_hid;

// HID report descriptor for keyboard
const uint8_t hid_report_descriptor[] PROGMEM = {
    TUD_HID_REPORT_DESC_KEYBOARD()
};

// BLE Service & Characteristics
BLEService        keyboardService(SERVICE_UUID);
BLECharacteristic textCharacteristic(CHAR_UUID_TEXT);

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

    // Wait for serial or timeout
    unsigned long startTime = millis();
    while (!Serial && (millis() - startTime < 3000)) {
        delay(10);
    }

    Serial.println("Simple Xiao BLE Keyboard Starting...");

    // Initialize USB HID
    setupUSB();

    // Initialize BLE
    setupBLE();

    // Start advertising
    startAdvertising();

    Serial.println("Setup complete. Ready for connections.");
}

void loop() {
    // Check USB connection
    if (TinyUSBDevice.mounted() != usbConnected) {
        usbConnected = TinyUSBDevice.mounted();
        Serial.print("USB ");
        Serial.println(usbConnected ? "connected" : "disconnected");
    }

    // Process received text
    if (hasNewText) {
        hasNewText = false;

        if (usbConnected) {
            Serial.print("Sending text: ");
            Serial.println(textBuffer);
            sendText(textBuffer);
        } else {
            Serial.println("USB not connected");
        }

        // Clear buffer
        memset(textBuffer, 0, TEXT_BUFFER_SIZE);
    }

    delay(10);
}

void setupBLE() {
    Serial.println("Initializing BLE...");

    // Initialize Bluefruit
    Bluefruit.begin();
    Bluefruit.setTxPower(4);
    Bluefruit.setName("Xiao Keyboard");

    // Set connection callbacks
    Bluefruit.Periph.setConnectCallback(connect_callback);
    Bluefruit.Periph.setDisconnectCallback(disconnect_callback);

    // Configure and start service
    keyboardService.begin();

    // Configure text characteristic (write)
    textCharacteristic.setProperties(CHR_PROPS_WRITE | CHR_PROPS_WRITE_WO_RESP);
    textCharacteristic.setPermission(SECMODE_ENC_NO_MITM, SECMODE_ENC_NO_MITM);
    textCharacteristic.setMaxLen(TEXT_BUFFER_SIZE);
    textCharacteristic.setWriteCallback(text_write_callback);
    textCharacteristic.begin();

    Serial.println("BLE initialized");
}

void setupUSB() {
    Serial.println("Initializing USB HID...");

    // Configure HID before starting TinyUSB so the interface enumerates correctly
    usb_hid.setReportDescriptor(hid_report_descriptor, sizeof(hid_report_descriptor));
    usb_hid.setPollInterval(2);
    usb_hid.begin();

    TinyUSBDevice.begin();

    // Wait for USB mount
    while (!TinyUSBDevice.mounted()) {
        delay(1);
    }

    Serial.println("USB HID initialized");
}

void startAdvertising() {
    Serial.println("Starting BLE advertising...");

    // Advertising packet
    Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
    Bluefruit.Advertising.addTxPower();
    Bluefruit.Advertising.addService(keyboardService);
    Bluefruit.Advertising.addName();

    // Start advertising
    Bluefruit.Advertising.restartOnDisconnect(true);
    Bluefruit.Advertising.setInterval(32, 244);
    Bluefruit.Advertising.setFastTimeout(30);
    Bluefruit.Advertising.start(0);

    Serial.println("Advertising started");
}

void sendKeyPress(uint8_t keycode, uint8_t modifier) {
    if (!usb_hid.ready()) return;

    // Press key
    keyReport[0] = modifier;
    keyReport[2] = keycode;
    usb_hid.sendReport(0, keyReport, sizeof(keyReport));
    delay(10);

    // Release key
    keyReport[0] = 0;
    keyReport[2] = 0;
    usb_hid.sendReport(0, keyReport, sizeof(keyReport));
    delay(10);
}

void sendText(const char* text) {
    if (!text) return;

    for (size_t i = 0; i < strlen(text); i++) {
        char c = text[i];
        uint8_t modifier = 0;
        uint8_t keycode = charToKeycode(c, modifier);

        if (keycode != 0) {
            sendKeyPress(keycode, modifier);
        }

        delay(5);
    }
}

uint8_t charToKeycode(char c, uint8_t& modifier) {
    modifier = 0;

    // Lowercase letters
    if (c >= 'a' && c <= 'z') {
        return 0x04 + (c - 'a');
    }
    // Uppercase letters
    else if (c >= 'A' && c <= 'Z') {
        modifier = 0x02; // Left Shift
        return 0x04 + (c - 'A');
    }
    // Numbers
    else if (c >= '1' && c <= '9') {
        return 0x1E + (c - '1');
    }
    else if (c == '0') {
        return 0x27;
    }
    // Special characters
    else if (c == ' ') {
        return 0x2C; // Spacebar
    }
    else if (c == '\n' || c == '\r') {
        return 0x28; // Enter
    }
    else if (c == '.') {
        return 0x37; // Period
    }
    else if (c == ',') {
        return 0x36; // Comma
    }

    return 0; // Unknown character
}

// BLE Callbacks
void connect_callback(uint16_t conn_handle) {
    Serial.println("BLE connected");
    bleConnected = true;
}

void disconnect_callback(uint16_t conn_handle, uint8_t reason) {
    Serial.println("BLE disconnected");
    bleConnected = false;
}

void text_write_callback(uint16_t conn_hdl, BLECharacteristic* chr, uint8_t* data, uint16_t len) {
    Serial.print("Received text (");
    Serial.print(len);
    Serial.println(" bytes)");

    // Copy data to buffer
    size_t copyLen = min((size_t)len, TEXT_BUFFER_SIZE - 1);
    memcpy(textBuffer, data, copyLen);
    textBuffer[copyLen] = '\0';

    hasNewText = true;
}
