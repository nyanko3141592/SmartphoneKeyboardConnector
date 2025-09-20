//
//  BLEManager.swift
//  EasyKeyboard
//
//  Created by 高橋直希 on 2025/09/17.
//

import Foundation
import CoreBluetooth
import os.log

class BLEManager: NSObject, ObservableObject {

    // MARK: - Properties

    @Published var isScanning = false
    @Published var isConnected = false
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var connectedDevice: CBPeripheral?
    @Published var statusMessage = "Not connected"

    // Modes
    @Published var immediateSendEnabled = false
    @Published var unicodeModeEnabled = false
    @Published var immediateClearEnabled = false

    enum MouseButton: String {
        case left = "LEFT"
        case right = "RIGHT"
        case middle = "MIDDLE"
    }

    private var centralManager: CBCentralManager!
    private var textCharacteristic: CBCharacteristic?
    private var statusCharacteristic: CBCharacteristic?

    // MARK: - Service and Characteristic UUIDs
    // Nordic UART Service (NUS) - ファームウェアと一致させる
    private let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let textCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    private let statusCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    private let logger = Logger(subsystem: "com.easykeyboard", category: "BLEManager")

    // MARK: - Initialization

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Public Methods

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            logger.warning("Bluetooth not ready")
            statusMessage = "Bluetooth not ready"
            return
        }

        discoveredDevices.removeAll()
        // 一時的に全デバイスをスキャンしてデバッグ
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        isScanning = true
        statusMessage = "Scanning for all devices..."
        logger.info("Started scanning for ALL BLE devices (debug mode)")
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        statusMessage = "Scan stopped"
        logger.info("Stopped scanning")
    }

    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        centralManager.connect(peripheral, options: nil)
        statusMessage = "Connecting..."
        logger.info("Connecting to \(peripheral.name ?? "Unknown")")
    }

    func disconnect() {
        guard let device = connectedDevice else { return }
        centralManager.cancelPeripheralConnection(device)
        logger.info("Disconnecting from \(device.name ?? "Unknown")")
    }

    func sendText(_ text: String) {
        logger.info("Attempting to send text: \(text)")

        guard let peripheral = connectedDevice else {
            logger.error("Cannot send text: no connected device")
            return
        }

        guard let characteristic = textCharacteristic else {
            logger.error("Cannot send text: text characteristic not found")
            logger.error("Available characteristics: \(peripheral.services?.map { service in service.characteristics?.map { $0.uuid.uuidString }.joined(separator: ", ") ?? "none" }.joined(separator: "; ") ?? "none")")
            return
        }

        guard let data = text.data(using: .utf8) else {
            logger.error("Cannot send text: failed to encode as UTF-8")
            return
        }

        logger.info("Sending to characteristic: \(characteristic.uuid.uuidString)")
        logger.info("Data size: \(data.count) bytes")

        // Try both write types to see which works
        if characteristic.properties.contains(.writeWithoutResponse) {
            let maxLength = peripheral.maximumWriteValueLength(for: .withoutResponse)
            logger.info("Using writeWithoutResponse, max length: \(maxLength)")

            var offset = 0
            while offset < data.count {
                let chunkSize = min(maxLength, data.count - offset)
                let chunk = data.subdata(in: offset..<(offset + chunkSize))
                peripheral.writeValue(chunk, for: characteristic, type: .withoutResponse)
                offset += chunkSize
            }
        } else if characteristic.properties.contains(.write) {
            let maxLength = peripheral.maximumWriteValueLength(for: .withResponse)
            logger.info("Using write with response, max length: \(maxLength)")

            var offset = 0
            while offset < data.count {
                let chunkSize = min(maxLength, data.count - offset)
                let chunk = data.subdata(in: offset..<(offset + chunkSize))
                peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
                offset += chunkSize
            }
        } else {
            logger.error("Characteristic does not support write operations")
            logger.error("Properties: \(characteristic.properties.rawValue)")
        }

        logger.info("Text send attempt completed")
    }

    func sendMouseMove(dx: Int, dy: Int) {
        guard isConnected else { return }
        guard dx != 0 || dy != 0 else { return }
        sendMouseCommand("MOVE:\(dx):\(dy)")
    }

    func sendMouseClick(_ button: MouseButton) {
        guard isConnected else { return }
        sendMouseCommand("CLICK:\(button.rawValue)")
    }

    func sendMouseDoubleClick(_ button: MouseButton) {
        guard isConnected else { return }
        sendMouseCommand("DOUBLE:\(button.rawValue)")
    }

    func sendMouseScroll(dy: Int) {
        guard isConnected else { return }
        guard dy != 0 else { return }
        sendMouseCommand("SCROLL:\(dy)")
    }

    private func sendMouseCommand(_ command: String) {
        let payload = "CMD:MOUSE:\(command)\n"
        sendText(payload)
    }

    // MARK: - Immediate send helpers

    /// Send only appended content from oldText -> newText.
    /// If text was shortened (deletion), this does nothing.
    func sendDelta(old oldText: String, new newText: String) {
        guard isConnected else { return }

        let oldChars = Array(oldText)
        let newChars = Array(newText)

        // 1) 削除（Backspace）判定
        if newChars.count < oldChars.count {
            let diff = oldChars.count - newChars.count
            sendBackspace(diff)
            return
        }

        // 2) 追加文字（または置換による末尾以外の挿入）
        var i = 0
        while i < oldChars.count && i < newChars.count && oldChars[i] == newChars[i] {
            i += 1
        }

        let appended = newChars.suffix(newChars.count - i)
        guard !appended.isEmpty else { return }

        let appendedString = String(appended)
        if unicodeModeEnabled {
            sendUnicode(appendedString)
        } else {
            sendText(appendedString)
        }
    }

    /// Backspace キーイベント相当（ASCII BS 0x08）を複数回送信
    func sendBackspace(_ count: Int = 1) {
        guard count > 0 else { return }
        let bs = String(repeating: "\u{0008}", count: count)
        sendText(bs)
    }

    /// Return/Enter キーイベント相当（改行）を送信
    func sendReturn() {
        // 改行は "\n" とし、ファームウェア側で Enter にマップする想定
        sendText("\n")
    }

    /// Send text as Unicode code points (hex), for firmware that expects explicit code points.
    /// Format: "U+XXXX" tokens separated by spaces. Example: "A あ" -> "U+0041 U+3042".
    func sendUnicode(_ text: String) {
        let scalars = text.unicodeScalars.map { scalar in
            String(format: "U+%04X", scalar.value)
        }
        let payload = scalars.joined(separator: " ")
        sendText(payload)
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            logger.info("Bluetooth powered on")
            statusMessage = "Bluetooth ready"
        case .poweredOff:
            logger.warning("Bluetooth powered off")
            statusMessage = "Bluetooth is off"
            isConnected = false
        case .resetting:
            statusMessage = "Bluetooth resetting"
        case .unauthorized:
            logger.error("Bluetooth unauthorized")
            statusMessage = "Bluetooth unauthorized"
        case .unsupported:
            logger.error("Bluetooth unsupported")
            statusMessage = "Bluetooth not supported"
        case .unknown:
            statusMessage = "Bluetooth state unknown"
        @unknown default:
            statusMessage = "Bluetooth state unknown"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // デバッグ情報を詳細に出力
        let name = peripheral.name ?? "Unknown"
        let uuid = peripheral.identifier.uuidString
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []

        logger.info("Found device: \(name) UUID: \(uuid) RSSI: \(RSSI)")
        if !services.isEmpty {
            logger.info("  Services: \(services.map { $0.uuidString }.joined(separator: ", "))")
        }

        // "Xiao" を含むデバイス名、または特定のサービスUUIDを持つデバイスを追加
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            if name.lowercased().contains("xiao") || name.lowercased().contains("keyboard") ||
               name.lowercased().contains("nordic") || services.contains(serviceUUID) {
                discoveredDevices.append(peripheral)
                logger.info("✅ Added to list: \(name)")
            } else if name != "Unknown" {
                // デバッグ用：すべての名前付きデバイスを表示
                discoveredDevices.append(peripheral)
                logger.info("📱 Added device (debug): \(name)")
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("Connected to \(peripheral.name ?? "Unknown")")
        connectedDevice = peripheral
        isConnected = true
        statusMessage = "Connected"
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        statusMessage = "Connection failed"
        isConnected = false
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            logger.error("Disconnected with error: \(error.localizedDescription)")
            statusMessage = "Disconnected: \(error.localizedDescription)"
        } else {
            logger.info("Disconnected")
            statusMessage = "Disconnected"
        }

        isConnected = false
        connectedDevice = nil
        textCharacteristic = nil
        statusCharacteristic = nil

        // Auto-reconnect if it was unexpected
        if error != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.connect(to: peripheral)
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            logger.error("Service discovery failed: \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services else {
            logger.error("No services found")
            return
        }

        logger.info("Discovered \(services.count) services")
        for service in services {
            logger.info("Service UUID: \(service.uuid.uuidString)")
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics(nil, for: service)  // 全Characteristicを探索
                logger.info("✅ Found keyboard service, discovering characteristics...")
            } else {
                // デバッグ用: 他のサービスも探索
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            logger.error("Characteristic discovery failed: \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else {
            logger.error("No characteristics found for service: \(service.uuid.uuidString)")
            return
        }

        logger.info("Found \(characteristics.count) characteristics for service: \(service.uuid.uuidString)")

        for characteristic in characteristics {
            logger.info("  Characteristic UUID: \(characteristic.uuid.uuidString)")
            logger.info("  Properties: \(characteristic.properties.rawValue)")

            if characteristic.uuid == textCharacteristicUUID {
                textCharacteristic = characteristic
                logger.info("✅ Found text characteristic (Write)")
            } else if characteristic.uuid == statusCharacteristicUUID {
                statusCharacteristic = characteristic
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                    logger.info("✅ Found status characteristic (Notify)")
                }
            } else if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                // もしかしたら違うUUIDを使っている可能性
                textCharacteristic = characteristic
                logger.info("📝 Using alternative write characteristic: \(characteristic.uuid.uuidString)")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("❌ Write failed: \(error.localizedDescription)")
        } else {
            logger.info("✅ Write successful to \(characteristic.uuid.uuidString)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == statusCharacteristicUUID,
           let data = characteristic.value,
           let status = String(data: data, encoding: .utf8) {
            logger.info("Status update: \(status)")
            statusMessage = status
        }
    }
}
