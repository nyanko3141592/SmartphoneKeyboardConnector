//
//  ContentView.swift
//  EasyKeyboard
//
//  Created by 高橋直希 on 2025/09/17.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @State private var inputText = ""
    @State private var previousText = ""
    @State private var showDeviceList = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var buttonKeyboardMode = false
    @State private var parsedLayout: ParsedKeyboardLayout?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection Status
                HStack {
                    Circle()
                        .fill(bleManager.isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)

                    Text(bleManager.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if bleManager.isConnected {
                        Button("Disconnect") {
                            bleManager.disconnect()
                        }
                        .font(.caption)
                    } else {
                        Button("Connect") {
                            showDeviceList = true
                        }
                        .font(.caption)
                    }
                }
                .padding(.horizontal)

                // Main Input Area (compact)
                VStack(spacing: buttonKeyboardMode ? 8 : 12) {
                    Text("EasyKeyboard")
                        .font(buttonKeyboardMode ? .subheadline : .title3)
                        .fontWeight(.semibold)

                    // One-line input and small actions
                    VStack(alignment: .leading, spacing: 6) {
                        if buttonKeyboardMode {
                            // ボタンキーボードは画面下部に表示するため、ここでは説明のみ
                            Text("ボタンキーボード有効（下部に表示）")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("入力")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                TextField("ここに入力", text: $inputText)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($isTextFieldFocused)
                                    .onSubmit {
                                        // Returnキーを送信
                                        bleManager.sendReturn()
                                        if bleManager.immediateClearEnabled {
                                            inputText = ""
                                            previousText = ""
                                        }
                                    }
                                    .onChange(of: inputText) { newValue in
                                        if bleManager.immediateSendEnabled {
                                            bleManager.sendDelta(old: previousText, new: newValue)

                                            // 即時送信時に入力欄をクリア（任意）
                                            if bleManager.immediateClearEnabled, !newValue.isEmpty {
                                                DispatchQueue.main.async {
                                                    self.inputText = ""
                                                    self.previousText = ""
                                                }
                                                return
                                            }
                                        }
                                        previousText = newValue
                                    }

                                if isTextFieldFocused {
                                    Button {
                                        isTextFieldFocused = false
                                    } label: {
                                        Image(systemName: "keyboard.chevron.compact.down")
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }

                                if !inputText.isEmpty {
                                    Button {
                                        inputText = ""
                                        previousText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle")
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }
                            }

                            // Compact action buttons
                            HStack(spacing: 8) {
                                Button(action: sendText) {
                                    Label("Send", systemImage: "paperplane.fill")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(!bleManager.isConnected || inputText.isEmpty)

                                Button(action: sendTestText) {
                                    Text("Test")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .disabled(!bleManager.isConnected)

                                Spacer()
                            }
                        }

                        // Mode toggles (compact)
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: $buttonKeyboardMode) {
                                Text("テキストフィールドなしモード（QWERTYボタン）")
                            }

                            if buttonKeyboardMode {
                                DisclosureGroup("オプション") {
                                    Toggle(isOn: $bleManager.immediateSendEnabled) {
                                        Text("Immediate Send (per char)")
                                    }
                                    .tint(.blue)

                                    if bleManager.immediateSendEnabled {
                                        Toggle(isOn: $bleManager.immediateClearEnabled) {
                                            Text("Immediate Clear (after send)")
                                        }
                                        .tint(.red)
                                    }

                                    Toggle(isOn: $bleManager.unicodeModeEnabled) {
                                        Text("Unicode Mode (U+XXXX)")
                                    }
                                    .tint(.purple)

                                    Text("IME変換中は即時送信をオフ推奨")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Toggle(isOn: $bleManager.immediateSendEnabled) {
                                    Text("Immediate Send (per char)")
                                }
                                .tint(.blue)

                                if bleManager.immediateSendEnabled {
                                    Toggle(isOn: $bleManager.immediateClearEnabled) {
                                        Text("Immediate Clear (after send)")
                                    }
                                    .tint(.red)
                                }

                                Toggle(isOn: $bleManager.unicodeModeEnabled) {
                                    Text("Unicode Mode (U+XXXX)")
                                }
                                .tint(.purple)

                                Text("IME変換中は即時送信をオフ推奨")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()

                // 画面下部のボタンキーボードは safeAreaInset によって表示
            }
            .padding(.bottom, 8) // Moved padding onto the outer VStack so it applies to a concrete View
            .navigationBarHidden(true)
        }
        // Keyboard toolbar with a close button
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    isTextFieldFocused = false
                } label: {
                    Label("キーボードを閉じる", systemImage: "keyboard.chevron.compact.down")
                }
            }
        }
        .sheet(isPresented: $showDeviceList) {
            DeviceListView(bleManager: bleManager, isPresented: $showDeviceList)
        }
        .safeAreaInset(edge: .bottom) {
            if buttonKeyboardMode, let layout = parsedLayout {
                VStack(spacing: 8) {
                    ForEach(0..<layout.rows.count, id: \.self) { r in
                        let row = layout.rows[r]
                        KeyboardRowView(row: row) { tapped in
                            handleLayoutKeyTap(label: tapped)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            // Request focus on text field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
            if parsedLayout == nil {
                parsedLayout = KeyboardLayoutLoader.loadFromBundle()
            }
        }
    }

    private func sendText() {
        guard !inputText.isEmpty else { return }
        if bleManager.unicodeModeEnabled {
            bleManager.sendUnicode(inputText)
        } else {
            bleManager.sendText(inputText)
        }

        // Clear text after sending
        inputText = ""

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    private func sendTestText() {
        // 簡単な英語テスト文字列
        let testTexts = ["hello", "test", "abc", "123", "Hello World"]
        let randomTest = testTexts.randomElement() ?? "test"

        print("Sending test text: \(randomTest)")
        bleManager.sendText(randomTest)

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    // MARK: - Button Keyboard helpers
    private func handleLayoutKeyTap(label: String) {
        let output = keyOutput(from: label)
        switch output {
        case "__BACKSPACE__": bleManager.sendBackspace(1)
        case "__ENTER__": bleManager.sendReturn()
        case "__TAB__": bleManager.sendText("\t")
        case "__NOOP__": break
        default:
            if bleManager.unicodeModeEnabled { bleManager.sendUnicode(output) }
            else { bleManager.sendText(output) }
        }
    }

    private func keyOutput(from label: String) -> String {
        // Special named keys
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "Backspace": return "__BACKSPACE__"
        case "Enter", "Return": return "__ENTER__"
        case "Tab": return "__TAB__"
        case "Caps Lock", "Shift", "Ctrl", "Win", "Alt", "Menu": return "__NOOP__"
        default: break
        }

        // Split legends like "~\n`" -> pick lower legend by default
        let parts = name.components(separatedBy: "\n")
        let chosen = parts.last ?? name
        if chosen.isEmpty { return " " } // space bar

        // Prefer lowercase for letters (no modifier support yet)
        if chosen.count == 1, let scalar = chosen.unicodeScalars.first, CharacterSet.letters.contains(scalar) {
            return chosen.lowercased()
        }
        return chosen
    }
}

// View that lays out a row of keys based on widths
struct KeyboardRowView: View {
    let row: [KeyModel]
    var tap: (String) -> Void

    private func totalUnits() -> Double { row.reduce(0) { $0 + $1.width } }

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 4
            let units = totalUnits()
            let available = geo.size.width - spacing * CGFloat(max(0, row.count - 1))
            let unitWidth = max(0, available / CGFloat(units))
            HStack(spacing: spacing) {
                ForEach(row) { key in
                    KeyButton(model: key, unitWidth: unitWidth, height: 48) {
                        tap(key.label)
                    }
                }
            }
        }
        .frame(height: 48)
    }
}

// Device List View for BLE device selection
struct DeviceListView: View {
    @ObservedObject var bleManager: BLEManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            VStack {
                if bleManager.discoveredDevices.isEmpty {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)

                        Text("Searching for devices...")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Make sure your Xiao BLE is powered on")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(bleManager.discoveredDevices, id: \.identifier) { device in
                        Button(action: {
                            bleManager.connect(to: device)
                            isPresented = false
                        }) {
                            HStack {
                                Image(systemName: "keyboard")
                                    .foregroundColor(.blue)

                                VStack(alignment: .leading) {
                                    Text(device.name ?? "Unknown Device")
                                        .font(.headline)
                                    Text(device.identifier.uuidString)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Device")
            .navigationBarItems(
                leading: Button("Cancel") {
                    bleManager.stopScanning()
                    isPresented = false
                },
                trailing: Button(bleManager.isScanning ? "Stop" : "Scan") {
                    if bleManager.isScanning {
                        bleManager.stopScanning()
                    } else {
                        bleManager.startScanning()
                    }
                }
            )
        }
        .onAppear {
            bleManager.startScanning()
        }
        .onDisappear {
            bleManager.stopScanning()
        }
    }
}

#Preview {
    ContentView()
}
