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
    @State private var showDeviceList = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var parsedLayout: ParsedKeyboardLayout?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
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
            VStack(spacing: 12) {
                mainContent
                    .padding(.top, 35) // topBarの下に適切なマージンを追加
                if selectedMode != .keyboard {
                    Spacer()
                }
            }
            .padding(.bottom, 8)
            .navigationBarHidden(true)
        }
        .safeAreaInset(edge: .top) {
            topBar
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(.ultraThinMaterial, ignoresSafeAreaEdges: .top)
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
        VStack(spacing: selectedMode == .keyboard ? 4 : 12) {
            modeSpecificContent
                .padding(.horizontal)
        }
        .frame(minHeight: selectedMode == .keyboard ? 30 : 100)
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
                    .submitLabel(.send)
                    .onSubmit {
                        commitText()
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
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
            HStack(spacing: 8) {
                Button(action: commitText) {
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
    }

    private var keyboardSection: some View {
        VStack(spacing: 10) {
            Text("キーボードモード")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var mouseSection: some View {
        VStack(spacing: 0) {
            // 上部の余白と設定エリア
            VStack(spacing: 8) {
                HStack {
                    Text("カーソル速度")
                        .font(.caption)
                    Slider(value: $trackpadSensitivity, in: 0.4...2.5, step: 0.1)
                    Text(String(format: "%.1fx", trackpadSensitivity))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 35)
                }

                Toggle(isOn: $tapToClickEnabled) {
                    Text("タップで左クリック")
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Spacer()

            // 下部に集中した操作エリア
            VStack(spacing: 12) {
                // トラックパッド
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
                .frame(maxHeight: 300)
                .padding(.horizontal)

                // クリックボタン
                HStack(spacing: 16) {
                    Button {
                        bleManager.sendMouseClick(.left)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "cursorarrow.click")
                                .font(.title2)
                            Text("左クリック")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!bleManager.isConnected)

                    Button {
                        bleManager.sendMouseClick(.right)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "cursorarrow.rays")
                                .font(.title2)
                            Text("右クリック")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!bleManager.isConnected)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
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
        let isMobile = horizontalSizeClass == .compact
        VStack(spacing: isMobile ? 3 : 8) {
            // 縦型（compact）の場合のみトラックパッドを表示
            if isMobile {
                CompactTrackpadView(
                    sensitivity: trackpadSensitivity,
                    onMove: { dx, dy in
                        bleManager.sendMouseMove(dx: dx, dy: dy)
                    },
                    onLeftClick: {
                        bleManager.sendMouseClick(.left)
                    },
                    onMiddleClick: {
                        bleManager.sendMouseClick(.middle)
                    },
                    onRightClick: {
                        bleManager.sendMouseClick(.right)
                    }
                )
                .padding(.bottom, 4)
            }

            // キーボード行
            ForEach(0..<layout.rows.count, id: \.self) { index in
                let row = layout.rows[index]
                KeyboardRowView(row: row, isMobile: isMobile) { tapped in
                    handleLayoutKeyTap(label: tapped)
                }
            }
        }
        .padding(.horizontal, isMobile ? 6 : 16)
        .padding(.vertical, isMobile ? 8 : 8)
        .background(.ultraThinMaterial)
    }

    private func handleOnAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if selectedMode == .text {
                isTextFieldFocused = true
            }
        }
        if parsedLayout == nil {
            let isMobile = horizontalSizeClass == .compact
            parsedLayout = KeyboardLayoutLoader.loadFromBundle(isMobile: isMobile)
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

    private func commitText() {
        let text = inputText
        guard !text.isEmpty else { return }

        bleManager.sendUnicode(text)

        inputText = ""

        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    private func sendTestText() {
        let testTexts = ["hello", "test", "abc", "123", "Hello World"]
        let randomTest = testTexts.randomElement() ?? "test"

        print("Sending test text: \(randomTest)")
        bleManager.sendUnicode(randomTest)

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
            bleManager.sendUnicode(output)
        }
    }

    private func keyOutput(from label: String) -> String {
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "Backspace": return "__BACKSPACE__"
        case "Enter", "Return": return "__ENTER__"
        case "Tab": return "__TAB__"
        case "Caps Lock", "Caps", "Shift", "Ctrl", "Win", "Cmd", "Alt", "Menu", "Esc": return "__NOOP__"
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemGray6))
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTracking ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isTracking ? 2 : 1)

            if !isTracking {
                VStack(spacing: 8) {
                    Image(systemName: "hand.point.up.left")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("トラックパッド")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isTracking)
        .contentShape(RoundedRectangle(cornerRadius: 12))
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

struct CompactTrackpadView: View {
    let sensitivity: Double
    let onMove: (Int, Int) -> Void
    let onLeftClick: () -> Void
    let onMiddleClick: () -> Void
    let onRightClick: () -> Void

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

    var body: some View {
        VStack(spacing: 6) {
            // トラックパッドエリア
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.systemGray6))
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isTracking ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isTracking ? 2 : 1)
            }
            .frame(minHeight: 100)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .gesture(dragGesture)

            // クリックボタン
            HStack(spacing: 6) {
                Button {
                    onLeftClick()
                } label: {
                    Text("左")
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)

                Button {
                    onMiddleClick()
                } label: {
                    Text("中")
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)

                Button {
                    onRightClick()
                } label: {
                    Text("右")
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
        }
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
    var isMobile: Bool = false
    var tap: (String) -> Void

    private func totalUnits() -> Double { row.reduce(0) { $0 + $1.width } }

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = isMobile ? 3 : 4
            let units = totalUnits()
            let available = geo.size.width - spacing * CGFloat(max(0, row.count - 1))
            let unitWidth = max(0, available / CGFloat(units))
            let keyHeight: CGFloat = isMobile ? 46 : 48
            HStack(spacing: spacing) {
                ForEach(row) { key in
                    KeyButton(model: key, unitWidth: unitWidth, height: keyHeight, isMobile: isMobile) {
                        tap(key.label)
                    }
                }
            }
        }
        .frame(height: isMobile ? 46 : 48)
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
