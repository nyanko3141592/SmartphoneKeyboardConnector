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

    struct DebugLogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let tag: String
        let message: String
    }

    @Published var isDebugEnabled = false {
        didSet {
            if isDebugEnabled {
                appendDebugLog(tag: "INFO", message: "Debug mode enabled")
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.debugLogs.removeAll()
                }
            }
        }
    }
    @Published var debugLogs: [DebugLogEntry] = []

    private let maxDebugEntries = 200

    @Published var isScanning = false
    @Published var isConnected = false
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var connectedDevice: CBPeripheral?
    @Published var statusMessage = "Not connected"

    enum MouseButton: String {
        case left = "LEFT"
        case right = "RIGHT"
        case middle = "MIDDLE"
    }

    enum CursorKey: String {
        case left = "LEFT"
        case right = "RIGHT"
    }

    private var centralManager: CBCentralManager!
    private var textCharacteristic: CBCharacteristic?
    private var statusCharacteristic: CBCharacteristic?
    private let unicodeSendQueue = DispatchQueue(label: "com.easykeyboard.unicodeSendQueue")
    private var unicodeNextSendTime = DispatchTime.now()
    private let unicodeSendInterval = DispatchTimeInterval.milliseconds(200)
    private let lastPeripheralKey = "BLEManager.lastConnectedPeripheralID"

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
        appendDebugLog(tag: "SEND", message: text)

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

    func isRememberedDevice(_ peripheral: CBPeripheral) -> Bool {
        guard let savedID = storedPeripheralID() else { return false }
        return savedID == peripheral.identifier
    }

    @discardableResult
    func sendCursor(_ key: CursorKey) -> Bool {
        guard isConnected else { return false }
        guard textCharacteristic != nil else { return false }
        sendText("CMD:KEY:\(key.rawValue)\n")
        return true
    }

    @discardableResult
    func sendUndo() -> Bool {
        guard isConnected else { return false }
        guard textCharacteristic != nil else { return false }
        sendText("CMD:KEY:UNDO\n")
        return true
    }

    @discardableResult
    func sendJapaneseInputMode() -> Bool {
        guard isConnected else { return false }
        guard textCharacteristic != nil else { return false }
        sendText("CMD:KEY:IME_JA\n")
        return true
    }

    func clearDebugLogs() {
        DispatchQueue.main.async { [weak self] in
            self?.debugLogs.removeAll()
        }
    }

    private func appendDebugLog(tag: String, message: String) {
        guard isDebugEnabled else { return }
        let entry = DebugLogEntry(timestamp: Date(), tag: tag, message: sanitizeForLog(message))
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            debugLogs.append(entry)
            if debugLogs.count > maxDebugEntries {
                debugLogs.removeFirst(debugLogs.count - maxDebugEntries)
            }
        }
    }

    private func sanitizeForLog(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    private func sendMouseCommand(_ command: String) {
        appendDebugLog(tag: "MOUSE", message: command)
        let payload = "CMD:MOUSE:\(command)\n"
        sendText(payload)
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

    /// Send text as Unicode code points (hex), expanding each one into
    /// the key sequence expected by the firmware: `Shift+U`, `+`, the
    /// four-digit hex value, two spaces, Enter, then a short delay.
    func sendUnicode(_ text: String) {
        guard isConnected else { return }
        guard !text.isEmpty else { return }

        appendDebugLog(tag: "UNICODE", message: text)

        let sequences = text.unicodeScalars.map { scalar in
            String(format: "U+%04X  \n", scalar.value)
        }

        unicodeSendQueue.async { [weak self] in
            guard let self = self else { return }

            var deadline = max(self.unicodeNextSendTime, DispatchTime.now())
            for sequence in sequences {
                DispatchQueue.main.asyncAfter(deadline: deadline) { [weak self] in
                    self?.sendText(sequence)
                }
                deadline = deadline + self.unicodeSendInterval
            }

            self.unicodeNextSendTime = deadline
        }
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
        var didInsert = false
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            if name.lowercased().contains("xiao") || name.lowercased().contains("keyboard") ||
               name.lowercased().contains("nordic") || services.contains(serviceUUID) {
                discoveredDevices.append(peripheral)
                didInsert = true
                logger.info("✅ Added to list: \(name)")
            } else if name != "Unknown" {
                discoveredDevices.append(peripheral)
                didInsert = true
                logger.info("📱 Added device (debug): \(name)")
            }
        }

        if didInsert || peripheral.identifier == storedPeripheralID() {
            promoteSavedPeripheralIfNeeded(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("Connected to \(peripheral.name ?? "Unknown")")
        connectedDevice = peripheral
        isConnected = true
        statusMessage = "Connected"
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
        persistLastPeripheralID(peripheral.identifier)
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

// MARK: - Auto Reconnect Helpers

private extension BLEManager {
    func persistLastPeripheralID(_ uuid: UUID) {
        UserDefaults.standard.set(uuid.uuidString, forKey: lastPeripheralKey)
    }

    func storedPeripheralID() -> UUID? {
        guard let uuidString = UserDefaults.standard.string(forKey: lastPeripheralKey) else { return nil }
        return UUID(uuidString: uuidString)
    }

    func promoteSavedPeripheralIfNeeded(_ peripheral: CBPeripheral) {
        guard let savedID = storedPeripheralID(), savedID == peripheral.identifier else { return }
        guard let index = discoveredDevices.firstIndex(where: { $0.identifier == peripheral.identifier }) else { return }
        let item = discoveredDevices.remove(at: index)
        discoveredDevices.insert(item, at: 0)
        logger.info("📌 Prioritized previously connected device: \(peripheral.name ?? "Unknown")")
    }
}
