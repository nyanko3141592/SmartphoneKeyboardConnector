/*
 * Xiao BLE Keyboard Firmware - Simple Version
 *
 * Simplified approach to avoid TinyUSB enumeration issues
 * Based on working examples from Seeed documentation
 */

#include <Adafruit_TinyUSB.h>
#include <bluefruit.h>
#include <strings.h>
#include <string.h>

// BLE Service & Characteristics UUIDs - Nordic UART Service
#define SERVICE_UUID        "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHAR_UUID_TEXT      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"

enum {
    RID_KEYBOARD = 1,
    RID_MOUSE,
};

// HID report descriptor for keyboard + mouse composite
uint8_t const desc_hid_report[] = {
    TUD_HID_REPORT_DESC_KEYBOARD( HID_REPORT_ID(RID_KEYBOARD) ),
    TUD_HID_REPORT_DESC_MOUSE   ( HID_REPORT_ID(RID_MOUSE) )
};

// USB HID instance constructed with descriptor (matches Adafruit example)
Adafruit_USBD_HID usb_hid(desc_hid_report, sizeof(desc_hid_report), HID_ITF_PROTOCOL_NONE, 2, false);

// Nordic UART Service を使用
BLEUart bleuart;

// Text buffer
#define TEXT_BUFFER_SIZE 256
char textBuffer[TEXT_BUFFER_SIZE];
volatile bool hasNewText = false;

// Connection status
bool bleConnected = false;

// Command assembly state for multi-packet BLE messages
static char commandBuffer[TEXT_BUFFER_SIZE];
static size_t commandLength = 0;
static bool collectingCommand = false;
static size_t commandPrefixMatch = 0;
static constexpr char COMMAND_PREFIX[] = "CMD:";
static constexpr size_t COMMAND_PREFIX_LENGTH = sizeof(COMMAND_PREFIX) - 1;

void handleCommand(const char* command);
void handleMouseCommand(char* payload);
void handleKeyCommand(const char* payload);
uint8_t mouseButtonMaskFromString(const char* token);
void sendMouseMove(int dx, int dy);
void sendMouseScroll(int delta);
void sendMouseClick(uint8_t buttonMask);
void sendMouseDoubleClick(uint8_t buttonMask);
int8_t clampToInt8(int value);
void sendKeycode(uint8_t keycode);
void sendKeycodeWithModifier(uint8_t modifier, uint8_t keycode);

constexpr uint8_t KEYCODE_ARROW_LEFT = 0x50;
constexpr uint8_t KEYCODE_ARROW_RIGHT = 0x4F;
constexpr uint8_t KEYCODE_Z = 0x1D;
constexpr uint8_t MODIFIER_COMMAND = 0x08; // Left GUI acts as Command key on macOS

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
        char sendBuffer[TEXT_BUFFER_SIZE];
        strncpy(sendBuffer, textBuffer, TEXT_BUFFER_SIZE - 1);
        sendBuffer[TEXT_BUFFER_SIZE - 1] = '\0';

        hasNewText = false;
        memset(textBuffer, 0, TEXT_BUFFER_SIZE);

        sendSimpleText(sendBuffer);
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
            case '+':
#ifdef JP_KEYBOARD
                keycode = 0x33; // ';' key with Shift produces '+' on JIS layout
#else
                keycode = 0x2E; // '=' key with Shift produces '+' on US layout
#endif
                modifier = 0x02; // Shift
                break;
            case '[': keycode = 0x2F; break;
            case ']': keycode = 0x30; break;
            case '\\': keycode = 0x31; break;
            case ';': keycode = 0x33; break;
            case '\'': keycode = 0x34; break;
            case '`': keycode = 0x35; break;
            case ',': keycode = 0x36; break;
            case '.': keycode = 0x37; break;
            case '/': keycode = 0x38; break;
            case '!': modifier = 0x02; keycode = 0x1E; break; // Shift + 1
            case '?': modifier = 0x02; keycode = 0x38; break; // Shift + /
            case '{': modifier = 0x02; keycode = 0x2F; break; // Shift + [
            case '}': modifier = 0x02; keycode = 0x30; break; // Shift + ]
            case ':': modifier = 0x02; keycode = 0x33; break; // Shift + ;
            case '"': modifier = 0x02; keycode = 0x34; break; // Shift + '
            case '_': modifier = 0x02; keycode = 0x2D; break; // Shift + -
            case '|': modifier = 0x02; keycode = 0x31; break; // Shift + \
            case '<': modifier = 0x02; keycode = 0x36; break; // Shift + ,
            case '>': modifier = 0x02; keycode = 0x37; break; // Shift + .
            case '~': modifier = 0x02; keycode = 0x35; break; // Shift + `
            case '(': modifier = 0x02; keycode = 0x26; break; // Shift + 9
            case ')': modifier = 0x02; keycode = 0x27; break; // Shift + 0
            default:
                handled = false;
                break;
        }
    }

    if (!handled || keycode == 0) {
        return;
    }

    uint8_t keycodes[6] = {keycode, 0, 0, 0, 0, 0};
    usb_hid.keyboardReport(RID_KEYBOARD, modifier, keycodes);
    delay(6);
    usb_hid.keyboardRelease(RID_KEYBOARD);
    delay(6);
}

void sendSimpleText(const char* text) {
    if (!text) return;
    for (int i = 0; text[i] != '\0'; i++) {
        sendSimpleKey(text[i]);
        delay(12);
    }
}

void handleCommand(const char* command) {
    if (!command) return;

    if (strncmp(command, "MOUSE:", 6) == 0) {
        char payload[TEXT_BUFFER_SIZE];
        strncpy(payload, command + 6, sizeof(payload) - 1);
        payload[sizeof(payload) - 1] = '\0';
        handleMouseCommand(payload);
    } else if (strncmp(command, "KEY:", 4) == 0) {
        const char* payload = command + 4;
        handleKeyCommand(payload);
    }
}

void handleMouseCommand(char* payload) {
    char* action = strtok(payload, ":");
    if (!action) return;

    if (strcasecmp(action, "MOVE") == 0) {
        char* dxToken = strtok(NULL, ":");
        char* dyToken = strtok(NULL, ":");
        if (!dxToken || !dyToken) return;
        int dx = atoi(dxToken);
        int dy = atoi(dyToken);
        sendMouseMove(dx, dy);
    } else if (strcasecmp(action, "CLICK") == 0) {
        char* buttonToken = strtok(NULL, ":");
        uint8_t mask = mouseButtonMaskFromString(buttonToken);
        sendMouseClick(mask);
    } else if (strcasecmp(action, "DOUBLE") == 0) {
        char* buttonToken = strtok(NULL, ":");
        uint8_t mask = mouseButtonMaskFromString(buttonToken);
        sendMouseDoubleClick(mask);
    } else if (strcasecmp(action, "SCROLL") == 0) {
        char* deltaToken = strtok(NULL, ":");
        if (!deltaToken) return;
        int delta = atoi(deltaToken);
        sendMouseScroll(delta);
    }
}

void handleKeyCommand(const char* payload) {
    if (!payload) return;

    if (strcasecmp(payload, "LEFT") == 0) {
        sendKeycode(KEYCODE_ARROW_LEFT);
    } else if (strcasecmp(payload, "RIGHT") == 0) {
        sendKeycode(KEYCODE_ARROW_RIGHT);
    } else if (strcasecmp(payload, "UNDO") == 0) {
        sendKeycodeWithModifier(MODIFIER_COMMAND, KEYCODE_Z);
    }
}

uint8_t mouseButtonMaskFromString(const char* token) {
    if (!token) return MOUSE_BUTTON_LEFT;

    if (strcasecmp(token, "LEFT") == 0) {
        return MOUSE_BUTTON_LEFT;
    } else if (strcasecmp(token, "RIGHT") == 0) {
        return MOUSE_BUTTON_RIGHT;
    } else if (strcasecmp(token, "MIDDLE") == 0 || strcasecmp(token, "CENTER") == 0) {
        return MOUSE_BUTTON_MIDDLE;
    }

    return MOUSE_BUTTON_LEFT;
}

void sendMouseMove(int dx, int dy) {
    if (TinyUSBDevice.suspended()) TinyUSBDevice.remoteWakeup();
    if (!usb_hid.ready()) return;

    int8_t x = clampToInt8(dx);
    int8_t y = clampToInt8(dy);
    usb_hid.mouseMove(RID_MOUSE, x, y);
}

void sendMouseScroll(int delta) {
    if (TinyUSBDevice.suspended()) TinyUSBDevice.remoteWakeup();
    if (!usb_hid.ready()) return;

    int8_t scroll = clampToInt8(delta);
    usb_hid.mouseScroll(RID_MOUSE, scroll, 0);
}

void sendMouseClick(uint8_t buttonMask) {
    if (TinyUSBDevice.suspended()) TinyUSBDevice.remoteWakeup();
    if (!usb_hid.ready()) return;

    usb_hid.mouseButtonPress(RID_MOUSE, buttonMask);
    delay(12);
    usb_hid.mouseButtonRelease(RID_MOUSE);
}

void sendMouseDoubleClick(uint8_t buttonMask) {
    sendMouseClick(buttonMask);
    delay(80);
    sendMouseClick(buttonMask);
}

int8_t clampToInt8(int value) {
    if (value > 127) return 127;
    if (value < -127) return -127;
    return static_cast<int8_t>(value);
}

void sendKeycode(uint8_t keycode) {
    if (TinyUSBDevice.suspended()) TinyUSBDevice.remoteWakeup();
    if (!usb_hid.ready()) return;

    uint8_t keycodes[6] = { keycode, 0, 0, 0, 0, 0 };
    usb_hid.keyboardReport(RID_KEYBOARD, 0, keycodes);
    delay(6);
    usb_hid.keyboardRelease(RID_KEYBOARD);
    delay(6);
}

void sendKeycodeWithModifier(uint8_t modifier, uint8_t keycode) {
    if (TinyUSBDevice.suspended()) TinyUSBDevice.remoteWakeup();
    if (!usb_hid.ready()) return;

    uint8_t keycodes[6] = { keycode, 0, 0, 0, 0, 0 };
    usb_hid.keyboardReport(RID_KEYBOARD, modifier, keycodes);
    delay(6);
    usb_hid.keyboardRelease(RID_KEYBOARD);
    delay(6);
}

void ble_uart_rx_callback(uint16_t conn_handle) {
    char data[TEXT_BUFFER_SIZE];
    uint16_t len = bleuart.read(data, TEXT_BUFFER_SIZE - 1);

    if (len == 0) {
        return;
    }

    size_t idx = 0;
    while (idx < len) {
        char c = data[idx];

        if (collectingCommand) {
            if (c == '\n' || c == '\r') {
                commandBuffer[commandLength] = '\0';
                handleCommand(commandBuffer);
                commandLength = 0;
                collectingCommand = false;
            } else if (commandLength < TEXT_BUFFER_SIZE - 1) {
                if (commandLength == 0 && c == ':') {
                    idx++;
                    continue;
                }
                commandBuffer[commandLength++] = c;
            }
            idx++;
            continue;
        }

        if (commandPrefixMatch < COMMAND_PREFIX_LENGTH) {
            if (c == COMMAND_PREFIX[commandPrefixMatch]) {
                commandPrefixMatch++;
                idx++;
                if (commandPrefixMatch == COMMAND_PREFIX_LENGTH) {
                    collectingCommand = true;
                    commandLength = 0;
                    commandPrefixMatch = 0;
                }
                continue;
            } else if (commandPrefixMatch > 0) {
                idx -= commandPrefixMatch;
                commandPrefixMatch = 0;

                size_t remaining = len - idx;
                if (remaining >= TEXT_BUFFER_SIZE) {
                    remaining = TEXT_BUFFER_SIZE - 1;
                }
                memcpy(textBuffer, &data[idx], remaining);
                textBuffer[remaining] = '\0';
                hasNewText = true;
                break;
            }
        }

        size_t remaining = len - idx;
        if (remaining >= TEXT_BUFFER_SIZE) {
            remaining = TEXT_BUFFER_SIZE - 1;
        }
        memcpy(textBuffer, &data[idx], remaining);
        textBuffer[remaining] = '\0';
        hasNewText = true;
        commandPrefixMatch = 0;
        break;
    }
}
