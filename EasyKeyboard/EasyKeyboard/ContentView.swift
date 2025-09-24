//
//  ContentView.swift
//  EasyKeyboard
//
//  Created by 高橋直希 on 2025/09/17.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @State private var inputText = ""
    @State private var showDeviceList = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var parsedLayout: ParsedKeyboardLayout?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var selectedMode: InputMode = .keyboard
    @State private var trackpadSensitivity: Double = 1.4
    @State private var tapToClickEnabled = true
    @State private var flickCommitHistory: FlickCommitHistory?
    @State private var isDebugModalPresented = false
    @State private var isSettingsPresented = false

    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    enum InputMode: String, CaseIterable, Identifiable {
        case text
        case keyboard
        case flick
        case mouse

        var id: String { rawValue }

        var label: String {
            switch self {
            case .text: return "テキスト入力"
            case .keyboard: return "キーボード"
            case .flick: return "フリック"
            case .mouse: return "マウス"
            }
        }

        var systemImage: String {
            switch self {
            case .text: return "character.cursor.ibeam"
            case .keyboard: return "keyboard"
            case .flick: return "square.grid.3x3.fill"
            case .mouse: return "rectangle.and.hand.point.up.left"
            }
        }
    }

    var body: some View {
        ZStack {
            // メインコンテンツ
            if selectedMode == .mouse {
                // マウスモードでは全画面トラックパッド
                mouseSection
                    .ignoresSafeArea(.all)
            } else {
                // 他のモードでは通常のScrollView
                ScrollView {
                    VStack(spacing: 12) {
                        mainContent
                            .padding(.top, 60) // 設定ボタンエリア分のスペース
                    }
                    .padding(.bottom, selectedMode == .keyboard || selectedMode == .flick ? 250 : 16)
                }
            }

            // 右上の設定ボタンとステータス（最小限のUI）
            VStack {
                HStack {
                    Spacer()

                    // 接続ステータスインジケーター（小さく控えめに）
                    if !bleManager.isConnected {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                            Text("未接続")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }

                    // 設定メニューボタン
                    Menu {
                        // モード切り替えセクション
                        Section("モード") {
                            ForEach(InputMode.allCases) { mode in
                                Button {
                                    selectedMode = mode
                                } label: {
                                    Label(mode.label, systemImage: mode.systemImage)
                                    if selectedMode == mode {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }

                        Divider()

                        // 接続セクション
                        Section("接続") {
                            if bleManager.isConnected {
                                Label(bleManager.statusMessage, systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Button("切断") {
                                    bleManager.disconnect()
                                }
                                Button("デバイス再選択") {
                                    showDeviceList = true
                                }
                            } else {
                                Button("デバイスをスキャン") {
                                    showDeviceList = true
                                }
                            }
                        }

                        Divider()

                        // デバッグセクション
                        Section("デバッグ") {
                            Toggle("デバッグモード", isOn: $bleManager.isDebugEnabled)
                            Button("ログを表示") {
                                isDebugModalPresented = true
                            }
                            .disabled(!bleManager.isDebugEnabled || bleManager.debugLogs.isEmpty)
                        }

                        Divider()

                        // 設定セクション
                        Section("設定") {
                            Button("詳細設定") {
                                isSettingsPresented = true
                            }
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                // 接続状態を示す小さなバッジ
                                Circle()
                                    .fill(bleManager.isConnected ? Color.green : Color.clear)
                                    .frame(width: 10, height: 10)
                                    .offset(x: 14, y: -14)
                            )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Spacer()
            }
        }
        .toolbar { keyboardToolbar }
        .sheet(isPresented: $showDeviceList) {
            DeviceListView(bleManager: bleManager, isPresented: $showDeviceList)
        }
        .sheet(isPresented: $isDebugModalPresented) {
            DebugLogView(bleManager: bleManager, isPresented: $isDebugModalPresented)
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(
                trackpadSensitivity: $trackpadSensitivity,
                tapToClickEnabled: $tapToClickEnabled,
                isPresented: $isSettingsPresented
            )
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                switch selectedMode {
                case .keyboard:
                    if let layout = parsedLayout {
                        keyboardInset(layout: layout)
                    } else {
                        EmptyView()
                    }
                case .flick:
                    flickKeyboardInset()
                default:
                    EmptyView()
                }
            }
        }
        .onAppear { handleOnAppear() }
        .onChange(of: selectedMode) { _, newMode in
            handleModeChange(newMode)
        }
        .onChange(of: bleManager.isConnected) { _, isConnected in
            if isConnected {
                ensureJapaneseImeForFlickIfPossible()
            }
        }
    }



    private var mainContent: some View {
        VStack(spacing: 12) {
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
        case .flick:
            flickSection
        case .mouse:
            mouseSection
        }
    }

    private var textInputSection: some View {
        VStack(spacing: 12) {
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
        EmptyView() // キーボードモードでは説明不要、画面を最大限活用
    }

    private var flickSection: some View {
        Group {
            if !bleManager.isConnected {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("デバイス未接続")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                EmptyView()
            }
        }
    }

    private var mouseSection: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 上部: 設定エリア（最小限）
                HStack {
                    // 接続状態インジケーター
                    HStack(spacing: 6) {
                        Circle()
                            .fill(bleManager.isConnected ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(bleManager.isConnected ? "接続済み" : "未接続")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .opacity(0.7)

                    Spacer()

                    // 設定ボタン（小さく）
                    Menu {
                        Section("モード") {
                            ForEach(InputMode.allCases) { mode in
                                Button {
                                    selectedMode = mode
                                } label: {
                                    Label(mode.label, systemImage: mode.systemImage)
                                    if selectedMode == mode {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        Divider()
                        Section("接続") {
                            if bleManager.isConnected {
                                Button("切断") { bleManager.disconnect() }
                                Button("デバイス再選択") { showDeviceList = true }
                            } else {
                                Button("デバイスをスキャン") { showDeviceList = true }
                            }
                        }
                        Divider()
                        Section("設定") {
                            Button("詳細設定") { isSettingsPresented = true }
                            if bleManager.isDebugEnabled {
                                Button("デバッグログ") { isDebugModalPresented = true }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 30, height: 30)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .opacity(0.8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(height: 44)

                // メイン: トラックパッドエリア
                ZStack {
                    // 背景とボーダー
                    Rectangle()
                        .fill(.clear)
                        .background(.thinMaterial)
                        .overlay(
                            Rectangle()
                                .stroke(.quaternary, lineWidth: 0.5)
                        )

                    HStack(spacing: 1) {
                        // トラックパッド本体
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // スクロールエリア（右端、より使いやすく）
                        ScrollStrip(
                            sensitivity: trackpadSensitivity,
                            onScroll: { delta in
                                bleManager.sendMouseScroll(dy: delta)
                            }
                        )
                        .frame(width: 60)
                        .frame(maxHeight: .infinity)
                        .background(.regularMaterial)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 下部: クリックボタンエリア
                VStack(spacing: 0) {
                    HStack(spacing: 1) {
                        Button {
                            bleManager.sendMouseClick(.left)
                        } label: {
                            Text("L")
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(.plain)
                        .background(.thinMaterial)
                        .disabled(!bleManager.isConnected)

                        Button {
                            bleManager.sendMouseClick(.middle)
                        } label: {
                            Text("M")
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(.plain)
                        .background(.thinMaterial)
                        .disabled(!bleManager.isConnected)

                        Button {
                            bleManager.sendMouseClick(.right)
                        } label: {
                            Text("R")
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(.plain)
                        .background(.thinMaterial)
                        .disabled(!bleManager.isConnected)
                    }
                    .frame(height: 70)
                    .overlay(
                        Rectangle()
                            .stroke(.quaternary, lineWidth: 0.5)
                    )

                    // 下部の余白
                    Spacer()
                        .frame(height: 16)
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
        let isMobile = horizontalSizeClass == .compact
        VStack(spacing: isMobile ? 3 : 8) {
            trackpadSection(isMobile: isMobile)

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

    @ViewBuilder
    private func flickKeyboardInset() -> some View {
        let isMobile = horizontalSizeClass == .compact
        VStack(spacing: isMobile ? 6 : 10) {
            trackpadSection(isMobile: isMobile)

            FlickKeyboardView(isCompact: isMobile) { entry, metadata in
                handleFlickCommit(entry, metadata: metadata)
            }
        }
        .padding(.horizontal, isMobile ? 6 : 16)
        .padding(.vertical, isMobile ? 8 : 10)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func trackpadSection(isMobile: Bool) -> some View {
        if isMobile {
            CompactTrackpadView(
                sensitivity: trackpadSensitivity,
                onMove: { dx, dy in
                    bleManager.sendMouseMove(dx: dx, dy: dy)
                },
                onScroll: { delta in
                    bleManager.sendMouseScroll(dy: delta)
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
        case .flick:
            isTextFieldFocused = false
            ensureJapaneseImeForFlickIfPossible()
        }

        flickCommitHistory = nil
    }

    private func ensureJapaneseImeForFlickIfPossible() {
        guard selectedMode == .flick else { return }
        guard bleManager.isConnected else { return }
        bleManager.sendJapaneseInputMode()
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
            bleManager.sendText(output)
        }
    }

    private func handleFlickCommit(_ entry: FlickEntry, metadata: FlickCommitMetadata?) {
        var performed = false

        switch entry.action {
        case .sendText(let value):
            bleManager.sendText(value)
            if let metadata {
                flickCommitHistory = FlickCommitHistory(model: metadata.model, direction: metadata.direction, entry: entry)
            } else {
                flickCommitHistory = nil
            }
            performed = true
        case .enter:
            bleManager.sendReturn()
            flickCommitHistory = nil
            performed = true
        case .backspace:
            bleManager.sendBackspace(1)
            flickCommitHistory = nil
            performed = true
        case .tab:
            bleManager.sendText("\t")
            flickCommitHistory = nil
            performed = true
        case .space:
            bleManager.sendText(" ")
            flickCommitHistory = nil
            performed = true
        case .transformSmall:
            performed = applySmallTransformation()
        case .applyDakuten:
            performed = applyDakutenTransformation()
        case .applyHandakuten:
            performed = applyHandakutenTransformation()
        case .cursorLeft:
            performed = bleManager.sendCursor(.left)
            flickCommitHistory = nil
        case .cursorRight:
            performed = bleManager.sendCursor(.right)
            flickCommitHistory = nil
        case .undo:
            performed = bleManager.sendUndo()
            flickCommitHistory = nil
        }

        if performed {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func applySmallTransformation() -> Bool {
        guard var history = flickCommitHistory else { return false }
        guard let replacement = history.model.smallEntry(for: history.direction) else { return false }
        guard case .sendText(let value) = replacement.action else { return false }

        sendReplacement(value)

        history.entry = replacement
        flickCommitHistory = history
        return true
    }

    private func applyDakutenTransformation() -> Bool {
        guard var history = flickCommitHistory else { return false }
        guard let replacement = history.model.dakutenEntry(for: history.direction) else { return false }
        guard case .sendText(let value) = replacement.action else { return false }

        sendReplacement(value)

        history.entry = replacement
        flickCommitHistory = history
        return true
    }

    private func applyHandakutenTransformation() -> Bool {
        guard var history = flickCommitHistory else { return false }
        guard let replacement = history.model.handakutenEntry(for: history.direction) else { return false }
        guard case .sendText(let value) = replacement.action else { return false }

        sendReplacement(value)

        history.entry = replacement
        flickCommitHistory = history
        return true
    }

    private func sendReplacement(_ romaji: String) {
        bleManager.sendBackspace(1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            bleManager.sendText(romaji)
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

private struct FlickCommitHistory {
    let model: FlickKeyModel
    let direction: FlickDirection
    var entry: FlickEntry
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

struct ScrollStrip: View {
    let sensitivity: Double
    let onScroll: (Int) -> Void

    @State private var previousTranslation: CGFloat = 0
    @State private var accumulator: CGFloat = 0
    @State private var isDragging = false

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                let delta = value.translation.height - previousTranslation
                previousTranslation = value.translation.height
                accumulate(delta: delta)
            }
            .onEnded { _ in
                isDragging = false
                previousTranslation = 0
                accumulator = 0
            }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.systemGray5))
            RoundedRectangle(cornerRadius: 10)
                .stroke(isDragging ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isDragging ? 2 : 1)

            if !isDragging {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.up")
                    Image(systemName: "arrow.down")
                }
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isDragging)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .gesture(dragGesture)
    }

    private func accumulate(delta: CGFloat) {
        let scale = CGFloat(sensitivity) * 0.7
        accumulator += delta * scale

        let step = Int(accumulator.rounded(.towardZero))
        if step != 0 {
            onScroll(step)
            accumulator -= CGFloat(step)
        }
    }
}

struct CompactTrackpadView: View {
    let sensitivity: Double
    let onMove: (Int, Int) -> Void
    let onScroll: (Int) -> Void
    let onLeftClick: () -> Void
    let onMiddleClick: () -> Void
    let onRightClick: () -> Void

    @State private var accumulator: CGSize = .zero
    @State private var isTracking = false

    var body: some View {
        VStack(spacing: 6) {
            // トラックパッドエリア + スクロールバー
            HStack(spacing: 6) {
                TrackpadSurfaceView(
                    isTracking: $isTracking,
                    onDelta: { delta in
                        accumulate(delta: delta)
                    },
                    onEnd: {
                        resetAccumulator()
                    },
                    onTap: { touches in
                        switch touches {
                        case 1:
                            onLeftClick()
                        case 2:
                            onRightClick()
                        case 3:
                            onMiddleClick()
                        default:
                            break
                        }
                    }
                )
                .frame(minHeight: 100)

                ScrollStrip(
                    sensitivity: sensitivity,
                    onScroll: onScroll
                )
                .frame(width: 32)
                .frame(maxWidth: nil, maxHeight: 100)
            }
            .frame(minHeight: 100)

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

    private func resetAccumulator() {
        accumulator = .zero
    }

}

private struct TrackpadSurfaceView: UIViewRepresentable {
    @Binding var isTracking: Bool
    var onDelta: (CGSize) -> Void
    var onEnd: () -> Void
    var onTap: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isTracking: $isTracking, onDelta: onDelta, onEnd: onEnd, onTap: onTap)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray6
        view.layer.cornerRadius = 8
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.gray.withAlphaComponent(0.3).cgColor

        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.maximumNumberOfTouches = 3
        panGesture.delegate = context.coordinator
        view.addGestureRecognizer(panGesture)

        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap))
        singleTap.numberOfTouchesRequired = 1
        singleTap.require(toFail: panGesture)
        view.addGestureRecognizer(singleTap)

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap))
        doubleTap.numberOfTouchesRequired = 2
        doubleTap.require(toFail: panGesture)
        view.addGestureRecognizer(doubleTap)

        let tripleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTripleTap))
        tripleTap.numberOfTouchesRequired = 3
        tripleTap.require(toFail: panGesture)
        view.addGestureRecognizer(tripleTap)

        context.coordinator.updateBorder(for: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.updateBorder(for: uiView)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        @Binding private var isTracking: Bool
        private var onDelta: (CGSize) -> Void
        private var onEnd: () -> Void
        private var onTap: (Int) -> Void
        private var previousTranslation: CGPoint = .zero

        init(isTracking: Binding<Bool>, onDelta: @escaping (CGSize) -> Void, onEnd: @escaping () -> Void, onTap: @escaping (Int) -> Void) {
            _isTracking = isTracking
            self.onDelta = onDelta
            self.onEnd = onEnd
            self.onTap = onTap
        }

        func updateBorder(for view: UIView) {
            view.layer.borderColor = (isTracking ? UIColor.systemBlue : UIColor.gray.withAlphaComponent(0.3)).cgColor
            view.layer.borderWidth = isTracking ? 2 : 1
        }

        @objc func handlePan(_ sender: UIPanGestureRecognizer) {
            switch sender.state {
            case .began:
                isTracking = true
                previousTranslation = sender.translation(in: sender.view)
                if let view = sender.view {
                    updateBorder(for: view)
                }
            case .changed:
                let translation = sender.translation(in: sender.view)
                let delta = CGSize(width: translation.x - previousTranslation.x,
                                   height: translation.y - previousTranslation.y)
                previousTranslation = translation
                onDelta(delta)
            case .ended, .cancelled, .failed:
                isTracking = false
                previousTranslation = .zero
                onEnd()
                if let view = sender.view {
                    updateBorder(for: view)
                }
            default:
                break
            }
        }

        @objc func handleSingleTap() {
            onTap(1)
        }

        @objc func handleDoubleTap() {
            onTap(2)
        }

        @objc func handleTripleTap() {
            onTap(3)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
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

struct SettingsView: View {
    @Binding var trackpadSensitivity: Double
    @Binding var tapToClickEnabled: Bool
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            Form {
                Section("マウス設定") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("カーソル速度", systemImage: "speedometer")
                            Spacer()
                            Text(String(format: "%.1fx", trackpadSensitivity))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $trackpadSensitivity, in: 0.4...2.5, step: 0.1)
                    }

                    Toggle("タップでクリック", isOn: $tapToClickEnabled)
                }
            }
            .navigationTitle("詳細設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct DebugLogView: View {
    @ObservedObject var bleManager: BLEManager
    @Binding var isPresented: Bool

    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var body: some View {
        NavigationView {
            VStack {
                if bleManager.debugLogs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("デバッグログが空です")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("デバッグモードを有効にして操作すると、ここにログが表示されます")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(bleManager.debugLogs) { entry in
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(Self.logDateFormatter.string(from: entry.timestamp))
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.secondary)
                                            Text("[\(entry.tag)]")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.blue)
                                                .fontWeight(.medium)
                                            Spacer()
                                        }
                                        Text(entry.message)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .id(entry.id)
                                    Divider()
                                        .opacity(0.3)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .onChange(of: bleManager.debugLogs.last?.id) { _, id in
                            guard let id else { return }
                            withAnimation {
                                proxy.scrollTo(id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .navigationTitle("デバッグログ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        bleManager.clearDebugLogs()
                    } label: {
                        Label("クリア", systemImage: "trash")
                    }
                    .disabled(bleManager.debugLogs.isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

