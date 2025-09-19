/*
 * Minimal BLE (NUS) -> USB HID keyboard bridge for XIAO nRF52840
 * - Based on Adafruit TinyUSB HID keyboard example
 * - Adds Bluefruit BLEUart (Nordic UART Service) RX -> types received ASCII
 * - No Serial/CDC to keep enumeration simple and stable
 */

#include <Adafruit_TinyUSB.h>
#include <bluefruit.h>

// ---------- USB HID (Boot keyboard, no report ID) ----------
uint8_t const desc_hid_report[] = { TUD_HID_REPORT_DESC_KEYBOARD() };
Adafruit_USBD_HID usb_hid(desc_hid_report, sizeof(desc_hid_report),
                          HID_ITF_PROTOCOL_KEYBOARD, 2, false);

// ---------- BLE (NUS) ----------
BLEUart bleuart; // Nordic UART Service

// ---------- RX buffer ----------
#define RX_BUF_SIZE 128
volatile bool has_rx = false;
char rx_buf[RX_BUF_SIZE];

// Map ASCII to HID key + modifier (very small subset)
static bool ascii_to_hid(char c, uint8_t &keycode, uint8_t &modifier) {
  modifier = 0;
  if (c >= 'a' && c <= 'z') { keycode = 0x04 + (c - 'a'); return true; }
  if (c >= 'A' && c <= 'Z') { keycode = 0x04 + (c - 'A'); modifier = 0x02; return true; }
  if (c >= '1' && c <= '9') { keycode = 0x1E + (c - '1'); return true; }
  if (c == '0') { keycode = 0x27; return true; }
  if (c == ' ') { keycode = 0x2C; return true; }
  if (c == '\n' || c == '\r') { keycode = 0x28; return true; }
  if (c == '.') { keycode = 0x37; return true; }
  if (c == ',') { keycode = 0x36; return true; }
  return false;
}

static void type_text(const char* text) {
  if (!text) return;

  for (const char* p = text; *p; ++p) {
    // Wake host if suspended
    if (TinyUSBDevice.suspended()) TinyUSBDevice.remoteWakeup();

    if (!usb_hid.ready()) return; // skip if not ready

    uint8_t kc = 0, mod = 0;
    if (!ascii_to_hid(*p, kc, mod)) continue;

    uint8_t keycodes[6] = { kc, 0, 0, 0, 0, 0 };
    usb_hid.keyboardReport(0, mod, keycodes);
    delay(6);
    usb_hid.keyboardRelease(0);
    delay(6);
  }
}

// BLE RX callback (ISR context)
void ble_rx_callback(uint16_t /*conn_handle*/) {
  // Read into buffer and flag for main loop
  int n = bleuart.read(rx_buf, RX_BUF_SIZE - 1);
  if (n > 0) {
    rx_buf[n] = '\0';
    has_rx = true;
  }
}

void setup() {
  // Start HID first (same style as Adafruit example)
  usb_hid.begin();

  // Wait until device is mounted before proceeding
  while (!TinyUSBDevice.mounted()) { delay(1); }

  // BLE setup
  Bluefruit.begin();
  Bluefruit.setName("Xiao Keyboard");

  bleuart.begin();
  bleuart.setRxCallback(ble_rx_callback);

  // Advertise NUS + name
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
  if (has_rx) {
    has_rx = false;
    type_text(rx_buf);
  }
  delay(2);
}

