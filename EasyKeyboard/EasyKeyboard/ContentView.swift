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
    @State private var parsedLayout: ParsedKeyboardLayout?
    @State private var selectedMode: InputMode = .text
    @State private var trackpadSensitivity: Double = 1.4
    @State private var tapToClickEnabled = true

    enum InputMode: String, CaseIterable, Identifiable {
        case text
        case keyboard
        case mouse

        var id: String { rawValue }

        var label: String {
            switch self {
            case .text: return "テキスト入力"
            case .keyboard: return "キーボード"
            case .mouse: return "マウス"
            }
        }

        var systemImage: String {
            switch self {
            case .text: return "character.cursor.ibeam"
            case .keyboard: return "keyboard"
            case .mouse: return "rectangle.and.hand.point.up.left"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                topBar
                mainContent
                Spacer()
            }
            .padding(.bottom, 8)
            .navigationBarHidden(true)
        }
        .toolbar { keyboardToolbar }
        .sheet(isPresented: $showDeviceList) {
            DeviceListView(bleManager: bleManager, isPresented: $showDeviceList)
        }
        .safeAreaInset(edge: .bottom) {
            if selectedMode == .keyboard, let layout = parsedLayout {
                keyboardInset(layout: layout)
            }
        }
        .onAppear { handleOnAppear() }
        .onChange(of: selectedMode) { newMode in
            handleModeChange(newMode)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Picker("モード", selection: $selectedMode) {
                ForEach(InputMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
            .pickerStyle(.menu)

            Spacer()

            connectionStatusMenu
        }
        .padding(.horizontal)
    }

    private var connectionStatusMenu: some View {
        Menu {
            if bleManager.isConnected {
                Button("Disconnect") {
                    bleManager.disconnect()
                }
                Button("デバイスを再選択") {
                    showDeviceList = true
                }
            } else {
                Button("デバイスをスキャン") {
                    showDeviceList = true
                }
            }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(bleManager.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(bleManager.isConnected ? "接続中" : "未接続")
                        .font(.footnote)
                        .fontWeight(.semibold)
                    Text(bleManager.statusMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 140, alignment: .leading)
                }

                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
    }

    private var mainContent: some View {
        VStack(spacing: selectedMode == .keyboard ? 8 : 12) {
            Text("EasyKeyboard")
                .font(selectedMode == .keyboard ? .subheadline : .title3)
                .fontWeight(.semibold)

            modeSpecificContent
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var modeSpecificContent: some View {
        switch selectedMode {
        case .text:
            textInputSection
        case .keyboard:
            keyboardSection
        case .mouse:
            mouseSection
        }
    }

    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("入力")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                TextField("ここに入力", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        bleManager.sendReturn()
                        if bleManager.immediateClearEnabled {
                            inputText = ""
                            previousText = ""
                        }
                    }
                    .onChange(of: inputText) { newValue in
                        handleTextFieldChange(newValue)
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

            sharedOptionSection
        }
    }

    private var keyboardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("画面下部のQWERTYキーボードから即時入力できます")
                .font(.subheadline)
                .foregroundColor(.secondary)

            sharedOptionSection
        }
    }

    private var sharedOptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
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

    private var mouseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("トラックパッドを使ってポインタを操作できます")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TrackpadSurface(
                sensitivity: trackpadSensitivity,
                tapToClick: tapToClickEnabled,
                onMove: { dx, dy in
                    bleManager.sendMouseMove(dx: dx, dy: dy)
                },
                onLeftTap: {
                    if tapToClickEnabled {
                        bleManager.sendMouseClick(.left)
                    }
                },
                onDoubleTap: {
                    bleManager.sendMouseDoubleClick(.left)
                },
                onRightTap: {
                    bleManager.sendMouseClick(.right)
                }
            )
            .frame(height: 240)

            HStack(spacing: 12) {
                Button {
                    bleManager.sendMouseClick(.left)
                } label: {
                    Label("左クリック", systemImage: "cursorarrow.click")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!bleManager.isConnected)

                Button {
                    bleManager.sendMouseClick(.right)
                } label: {
                    Label("右クリック", systemImage: "cursorarrow.rays")
                }
                .buttonStyle(.bordered)
                .disabled(!bleManager.isConnected)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("カーソル速度")
                    Slider(value: $trackpadSensitivity, in: 0.4...2.5, step: 0.1)
                }

                Toggle(isOn: $tapToClickEnabled) {
                    Text("タップで左クリック")
                }
            }
        }
    }

    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button {
                isTextFieldFocused = false
            } label: {
                Label("キーボードを閉じる", systemImage: "keyboard.chevron.compact.down")
            }
        }
    }

    @ViewBuilder
    private func keyboardInset(layout: ParsedKeyboardLayout) -> some View {
        VStack(spacing: 8) {
            ForEach(0..<layout.rows.count, id: \.self) { index in
                let row = layout.rows[index]
                KeyboardRowView(row: row) { tapped in
                    handleLayoutKeyTap(label: tapped)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func handleOnAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if selectedMode == .text {
                isTextFieldFocused = true
            }
        }
        if parsedLayout == nil {
            parsedLayout = KeyboardLayoutLoader.loadFromBundle()
        }
    }

    private func handleModeChange(_ mode: InputMode) {
        switch mode {
        case .text:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isTextFieldFocused = true
            }
        case .keyboard, .mouse:
            isTextFieldFocused = false
        }
    }

    private func handleTextFieldChange(_ newValue: String) {
        if bleManager.immediateSendEnabled {
            bleManager.sendDelta(old: previousText, new: newValue)

            if bleManager.immediateClearEnabled, !newValue.isEmpty {
                DispatchQueue.main.async {
                    inputText = ""
                    previousText = ""
                }
                return
            }
        }
        previousText = newValue
    }

    private func sendText() {
        guard !inputText.isEmpty else { return }
        if bleManager.unicodeModeEnabled {
            bleManager.sendUnicode(inputText)
        } else {
            bleManager.sendText(inputText)
        }

        inputText = ""
        previousText = ""

        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    private func sendTestText() {
        let testTexts = ["hello", "test", "abc", "123", "Hello World"]
        let randomTest = testTexts.randomElement() ?? "test"

        print("Sending test text: \(randomTest)")
        bleManager.sendText(randomTest)

        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    private func handleLayoutKeyTap(label: String) {
        let output = keyOutput(from: label)
        switch output {
        case "__BACKSPACE__": bleManager.sendBackspace(1)
        case "__ENTER__": bleManager.sendReturn()
        case "__TAB__": bleManager.sendText("\t")
        case "__NOOP__": break
        default:
            if bleManager.unicodeModeEnabled {
                bleManager.sendUnicode(output)
            } else {
                bleManager.sendText(output)
            }
        }
    }

    private func keyOutput(from label: String) -> String {
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "Backspace": return "__BACKSPACE__"
        case "Enter", "Return": return "__ENTER__"
        case "Tab": return "__TAB__"
        case "Caps Lock", "Shift", "Ctrl", "Win", "Alt", "Menu": return "__NOOP__"
        default: break
        }

        let parts = name.components(separatedBy: "\n")
        let chosen = parts.last ?? name
        if chosen.isEmpty { return " " }

        if chosen.count == 1, let scalar = chosen.unicodeScalars.first, CharacterSet.letters.contains(scalar) {
            return chosen.lowercased()
        }
        return chosen
    }
}

struct TrackpadSurface: View {
    let sensitivity: Double
    let tapToClick: Bool
    let onMove: (Int, Int) -> Void
    let onLeftTap: () -> Void
    let onDoubleTap: () -> Void
    let onRightTap: () -> Void

    @State private var previousTranslation: CGSize = .zero
    @State private var accumulator: CGSize = .zero
    @State private var isTracking = false

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isTracking = true
                let delta = CGSize(
                    width: value.translation.width - previousTranslation.width,
                    height: value.translation.height - previousTranslation.height
                )
                previousTranslation = value.translation
                accumulate(delta: delta)
            }
            .onEnded { _ in
                isTracking = false
                previousTranslation = .zero
                accumulator = .zero
            }
    }

    private var tapGestures: some Gesture {
        let doubleTap = TapGesture(count: 2).onEnded {
            onDoubleTap()
        }
        let singleTap = TapGesture(count: 1).onEnded {
            if tapToClick {
                onLeftTap()
            }
        }
        return doubleTap.exclusively(before: singleTap)
    }

    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.35).onEnded { _ in
            onRightTap()
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemGray5))
            RoundedRectangle(cornerRadius: 16)
                .stroke(isTracking ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1.5)
            VStack(spacing: 12) {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.secondary)
                Text("ドラッグで移動 / ダブルタップでダブルクリック / 長押しで右クリック")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isTracking)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .gesture(dragGesture)
        .highPriorityGesture(tapGestures)
        .simultaneousGesture(longPressGesture)
    }

    private func accumulate(delta: CGSize) {
        let scale = CGFloat(sensitivity)
        accumulator.width += delta.width * scale
        accumulator.height += delta.height * scale

        let stepX = Int(accumulator.width.rounded(.towardZero))
        let stepY = Int(accumulator.height.rounded(.towardZero))

        if stepX != 0 || stepY != 0 {
            onMove(stepX, stepY)
            accumulator.width -= CGFloat(stepX)
            accumulator.height -= CGFloat(stepY)
        }
    }
}

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
