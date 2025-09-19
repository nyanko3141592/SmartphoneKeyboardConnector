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
}

void loop() {
    // Process received text
    if (hasNewText) {
        // Create local copy to prevent interference
        char localBuffer[TEXT_BUFFER_SIZE];
        strncpy(localBuffer, textBuffer, TEXT_BUFFER_SIZE);
        localBuffer[TEXT_BUFFER_SIZE - 1] = '\0';

        // Clear flags immediately to allow new messages
        hasNewText = false;
        memset(textBuffer, 0, TEXT_BUFFER_SIZE);

        Serial.print("=== MAIN LOOP PROCESSING: \"");
        Serial.print(localBuffer);
        Serial.println("\" ===");

        if (TinyUSBDevice.mounted()) {
            Serial.println("USB mounted - processing text via HID");

            // Process with local copy
            sendSimpleText(localBuffer);

            Serial.println("=== MAIN LOOP PROCESSING COMPLETE ===");
            Serial.println("Ready for next message...");
        } else {
            Serial.println("ERROR: USB not mounted - cannot send text");
        }

        // Small delay to prevent overwhelming the system
        delay(50);
    }

    delay(5);  // Reduced delay for faster message processing
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
    if (!TinyUSBDevice.mounted()) {
        Serial.println("USB not mounted");
        return;
    }

    Serial.print("HID ready status: ");
    Serial.println(usb_hid.ready() ? "READY" : "NOT READY");

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

    Serial.print("Sending key: '");
    Serial.print(c);
    Serial.print("' keycode=0x");
    Serial.print(keycode, HEX);
    Serial.print(" modifier=0x");
    Serial.println(modifier, HEX);

    // If host is suspended and we have a key, try remote wakeup
    if (TinyUSBDevice.suspended()) {
        TinyUSBDevice.remoteWakeup();
        delay(2);
    }

    // Skip if HID not ready (still transferring previous report)
    if (!usb_hid.ready()) {
        Serial.println("  HID not ready, skipping this char");
        return;
    }

    uint8_t keycodes[6] = {keycode, 0, 0, 0, 0, 0};
    bool ok_press = usb_hid.keyboardReport(0, modifier, keycodes);
    Serial.print("  keyboardReport: ");
    Serial.println(ok_press ? "SUCCESS" : "FAILED");

    delay(5);

    bool ok_release = usb_hid.keyboardRelease(0);
    Serial.print("  keyboardRelease: ");
    Serial.println(ok_release ? "SUCCESS" : "FAILED");
}

void sendSimpleText(const char* text) {
    Serial.print(">> sendSimpleText called with: \"");
    Serial.print(text);
    Serial.println("\"");

    int len = strlen(text);
    Serial.print(">> Processing ");
    Serial.print(len);
    Serial.println(" characters");

    for (int i = 0; text[i] != '\0'; i++) {
        Serial.print(">> Character ");
        Serial.print(i + 1);
        Serial.print("/");
        Serial.print(len);
        Serial.print(": ");
        sendSimpleKey(text[i]);
        delay(50);
    }

    Serial.println(">> sendSimpleText complete");
}

void ble_uart_rx_callback(uint16_t conn_handle) {
    char data[TEXT_BUFFER_SIZE];
    uint16_t len = bleuart.read(data, TEXT_BUFFER_SIZE - 1);

    if (len > 0) {
        data[len] = '\0';

        Serial.print("BLE received: \"");
        Serial.print(data);
        Serial.print("\" (length: ");
        Serial.print(len);
        Serial.println(")");

        // Always queue for loop() processing to prevent callback interference
        if (!hasNewText) {  // Only store if no pending text
            strncpy(textBuffer, data, TEXT_BUFFER_SIZE - 1);
            textBuffer[TEXT_BUFFER_SIZE - 1] = '\0';
            hasNewText = true;
            Serial.println("-> Queued for processing in main loop");
        } else {
            Serial.println("-> WARNING: Previous message still pending, skipping");
        }
    }
}
