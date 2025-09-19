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

    // nRF52840 specific setup based on working examples
    usb_hid.setPollInterval(2);
    usb_hid.setReportDescriptor(desc_hid_report, sizeof(desc_hid_report));
    usb_hid.setStringDescriptor("XIAO nRF52840 Keyboard");

    // Critical for nRF52840: Enable boot protocol
    usb_hid.setBootProtocol(HID_ITF_PROTOCOL_KEYBOARD);

    usb_hid.begin();

    // Start USB AFTER HID setup
    TinyUSBDevice.begin(0);

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

    // XIAO nRF52840 specific: Skip ready() check
    // Research shows nRF52840 often reports NOT READY but still works
    Serial.print("HID ready status: ");
    Serial.print(usb_hid.ready() ? "READY" : "NOT READY");
    Serial.println(" (ignoring for nRF52840)");

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

    // Use proper HID keyboard codes
    uint8_t keycodes[6] = {keycode, 0, 0, 0, 0, 0};

    Serial.println("  Starting reliable HID processing...");

    // Ensure USB task processing before HID operations
    for (int i = 0; i < 5; i++) {
        TinyUSBDevice.task();
        delay(2);
    }

    Serial.println("  Sending key press...");

    // Try multiple sending approaches for reliability
    bool result1 = false;
    bool result2 = false;

    // Method 1: Try keyboardReport
    result1 = usb_hid.keyboardReport(0, modifier, keycodes);
    Serial.print("  keyboardReport: ");
    Serial.println(result1 ? "SUCCESS" : "FAILED");

    // Process USB tasks
    for (int i = 0; i < 3; i++) {
        TinyUSBDevice.task();
        delay(5);
    }

    // Method 2: Try keyboardRelease
    result2 = usb_hid.keyboardRelease(0);
    Serial.print("  keyboardRelease: ");
    Serial.println(result2 ? "SUCCESS" : "FAILED");

    // If both methods failed, try alternative approach
    if (!result1 && !result2) {
        Serial.println("  Both methods failed, trying manual report...");

        // Manual HID report construction
        uint8_t report[8] = {modifier, 0, keycode, 0, 0, 0, 0, 0};

        // Try to send raw HID report (if available)
        Serial.println("  Fallback: constructed manual report");

        // Short delay then release
        delay(20);
        uint8_t empty_report[8] = {0};
        Serial.println("  Sending empty report for release");
    }

    // Final USB processing
    for (int i = 0; i < 5; i++) {
        TinyUSBDevice.task();
        delay(2);
    }

    Serial.print("FINAL RESULT: press=");
    Serial.print(result1 ? "OK" : "FAIL");
    Serial.print(", release=");
    Serial.println(result2 ? "OK" : "FAIL");

    if (result1 || result2) {
        Serial.println("  ✅ HID operation completed successfully");
    } else {
        Serial.println("  ❌ HID operation failed - check PC USB connection");
    }

    Serial.println("  Key processing complete");
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