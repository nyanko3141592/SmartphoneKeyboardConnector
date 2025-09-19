// Exact Adafruit TinyUSB HID keyboard example (no BLE)
// Source: File > Examples > Adafruit TinyUSB Library > HID > hid_keyboard

#include "Adafruit_TinyUSB.h"
#include <Adafruit_NeoPixel.h>

// HID report descriptor using TinyUSB's template
// Single Report (no ID) descriptor
uint8_t const desc_hid_report[] =
{
  TUD_HID_REPORT_DESC_KEYBOARD()
};

// USB HID object. For ESP32 these values cannot be changed after this declaration
// desc report, desc len, protocol, interval, use out endpoint
Adafruit_USBD_HID usb_hid(desc_hid_report, sizeof(desc_hid_report), HID_ITF_PROTOCOL_KEYBOARD, 2, false);

//------------- Input Pins -------------//
// Array of pins and its keycode.
#ifdef ARDUINO_ARCH_RP2040
  uint8_t pins[] = { D0, D1, D2, D3 };
#else
  uint8_t pins[] = { A0, A1, A2, A3 };
#endif

uint8_t pincount = sizeof(pins)/sizeof(pins[0]);
uint8_t hidcode[] = { HID_KEY_ARROW_RIGHT, HID_KEY_ARROW_LEFT, HID_KEY_ARROW_DOWN, HID_KEY_ARROW_UP };

#if defined(ARDUINO_SAMD_CIRCUITPLAYGROUND_EXPRESS) || defined(ARDUINO_NRF52840_CIRCUITPLAY) || defined(ARDUINO_FUNHOUSE_ESP32S2)
  bool activeState = true;
#else
  bool activeState = false;
#endif

//------------- Neopixel -------------//
// #define PIN_NEOPIXEL  8
#ifdef PIN_NEOPIXEL
#ifndef NEOPIXEL_NUM
  #define NEOPIXEL_NUM  10
#endif
Adafruit_NeoPixel pixels = Adafruit_NeoPixel(NEOPIXEL_NUM, PIN_NEOPIXEL, NEO_GRB + NEO_KHZ800);
#endif

void hid_report_callback(uint8_t report_id, hid_report_type_t report_type, uint8_t const* buffer, uint16_t bufsize);

void setup()
{
  // Notes: following commented-out functions has no affect on ESP32
  // usb_hid.setBootProtocol(HID_ITF_PROTOCOL_KEYBOARD);
  // usb_hid.setPollInterval(2);
  // usb_hid.setReportDescriptor(desc_hid_report, sizeof(desc_hid_report));
  // usb_hid.setStringDescriptor("TinyUSB Keyboard");

  // Set up output report (on control endpoint) for Capslock indicator
  usb_hid.setReportCallback(NULL, hid_report_callback);

  usb_hid.begin();

  // led pin
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);

#ifdef PIN_NEOPIXEL
  pixels.begin();
  pixels.setBrightness(50);
  #ifdef NEOPIXEL_POWER
  pinMode(NEOPIXEL_POWER, OUTPUT);
  digitalWrite(NEOPIXEL_POWER, NEOPIXEL_POWER_ON);
  #endif
#endif

  // overwrite input pin with PIN_BUTTONx
#ifdef PIN_BUTTON1
  pins[0] = PIN_BUTTON1;
#endif
#ifdef PIN_BUTTON2
  pins[1] = PIN_BUTTON2;
#endif
#ifdef PIN_BUTTON3
  pins[2] = PIN_BUTTON3;
#endif
#ifdef PIN_BUTTON4
  pins[3] = PIN_BUTTON4;
#endif

  for (uint8_t i=0; i<pincount; i++)
  {
    pinMode(pins[i], activeState ? INPUT_PULLDOWN : INPUT_PULLUP);
  }

  // wait until device mounted
  while( !TinyUSBDevice.mounted() ) delay(1);
}

void loop()
{
  delay(2);

  static bool keyPressedPreviously = false;

  uint8_t count=0;
  uint8_t keycode[6] = { 0 };

  for(uint8_t i=0; i < pincount; i++)
  {
    if ( activeState == digitalRead(pins[i]) )
    {
      keycode[count++] = hidcode[i];
      if (count == 6) break;
    }
  }

  if ( TinyUSBDevice.suspended() && count )
  {
    TinyUSBDevice.remoteWakeup();
  }

  if ( !usb_hid.ready() ) return;

  if ( count )
  {
    uint8_t const report_id = 0;
    uint8_t const modifier = 0;
    keyPressedPreviously = true;
    usb_hid.keyboardReport(report_id, modifier, keycode);
  }else
  {
    if ( keyPressedPreviously )
    {
      keyPressedPreviously = false;
      usb_hid.keyboardRelease(0);
    }
  }
}

// Output report callback for LED indicator such as Caplocks
void hid_report_callback(uint8_t report_id, hid_report_type_t report_type, uint8_t const* buffer, uint16_t bufsize)
{
  (void) report_id;
  (void) bufsize;
  if ( report_type != HID_REPORT_TYPE_OUTPUT ) return;
  uint8_t ledIndicator = buffer[0];
  digitalWrite(LED_BUILTIN, ledIndicator & KEYBOARD_LED_CAPSLOCK);
#ifdef PIN_NEOPIXEL
  pixels.fill(ledIndicator & KEYBOARD_LED_CAPSLOCK ? 0xff0000 : 0x000000);
  pixels.show();
#endif
}
