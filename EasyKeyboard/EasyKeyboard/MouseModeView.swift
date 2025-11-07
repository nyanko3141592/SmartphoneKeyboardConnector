import SwiftUI

struct MouseModeView: View {
    @ObservedObject var flowManager: OpticalFlowManager
    @Binding var sensitivity: Double
    @Binding var exposureLevel: Double
    let onLeftClick: () -> Void
    let onMiddleClick: () -> Void
    let onRightClick: () -> Void
    let onScrollUp: () -> Void
    let onScrollDown: () -> Void
    @State private var isSensitivityExpanded = false
    @State private var isExposureExpanded = false

    var body: some View {
        VStack(spacing: 16) {
            header

            SectionHeader(title: "カメラ")
            cameraSection
            ExposureControl(exposure: $exposureLevel, isExpanded: $isExposureExpanded)

            SectionHeader(title: "デルタ")
            FlowReadoutView(reading: flowManager.latestReading)
            FlowSensitivityControl(sensitivity: $sensitivity, isExpanded: $isSensitivityExpanded)

            SectionHeader(title: "ボタン")
            clickControls
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(uiColor: .systemBackground).opacity(0.97))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label(flowManager.status.description, systemImage: statusIcon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.15))
                .clipShape(Capsule())

            Spacer()

            Button {
                flowManager.start()
            } label: {
                Label("開始", systemImage: "video.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.callout.bold())
            }
            .buttonStyle(.borderedProminent)

            Button {
                flowManager.stop()
            } label: {
                Label("停止", systemImage: "stop.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.callout)
            }
            .buttonStyle(.bordered)
        }
    }

    private var cameraSection: some View {
        CameraPreviewView(session: flowManager.captureSession)
            .overlay(alignment: .center) {
                FlowVectorOverlay(reading: flowManager.latestReading)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 8)
            .frame(maxWidth: .infinity)
            .frame(height: 340)
    }

    private var clickControls: some View {
        HStack(spacing: 12) {
            ClickButton(title: "左", systemImage: "cursorarrow.click", action: onLeftClick)
            MiddleScrollButton(
                onTap: onMiddleClick,
                onScrollUp: onScrollUp,
                onScrollDown: onScrollDown
            )
            ClickButton(title: "右", systemImage: "contextualmenu.and.cursorarrow", action: onRightClick)
        }
    }

    private var statusIcon: String {
        switch flowManager.status {
        case .idle: return "pause.circle"
        case .requestingPermission: return "lock.open"
        case .unauthorized: return "lock"
        case .running: return "waveform.path.ecg"
        case .error: return "exclamationmark.triangle"
        }
    }

    private var statusColor: Color {
        switch flowManager.status {
        case .running: return .green
        case .error: return .orange
        case .unauthorized: return .red
        case .requestingPermission: return .yellow
        case .idle: return .secondary
        }
    }
}


private struct FlowSensitivityControl: View {
    @Binding var sensitivity: Double
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Label("感度 (光学フロー)", systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(sensitivity, format: .number.precision(.fractionLength(2)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(), value: isExpanded)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Slider(value: $sensitivity, in: 0.01...1.0, step: 0.01)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ExposureControl: View {
    @Binding var exposure: Double
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Label("露出", systemImage: "sun.max")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(exposure, format: .number.precision(.fractionLength(2)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(), value: isExpanded)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Slider(value: $exposure, in: 0.0...1.0, step: 0.01)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ClickButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ScrollButton: View {
    enum Direction {
        case up, down

        var label: String {
            switch self {
            case .up: return "スクロール↑"
            case .down: return "スクロール↓"
            }
        }

        var iconName: String {
            switch self {
            case .up: return "chevron.up"
            case .down: return "chevron.down"
            }
        }
    }

    let direction: Direction
    let action: () -> Void
    @GestureState private var isDetectingLongPress = false
    @State private var repeatTimer: Timer?

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: direction.iconName)
                Text(direction.label)
            }
            .font(.caption2)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(longPressGesture)
        .onChange(of: isDetectingLongPress) { _, newValue in
            if newValue {
                startRepeating()
            } else {
                stopRepeating()
            }
        }
        .onDisappear { stopRepeating() }
    }

    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .updating($isDetectingLongPress) { currentValue, state, _ in
                state = currentValue
            }
            .onEnded { _ in
                stopRepeating()
            }
    }

    private func startRepeating() {
        action()
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
            action()
        }
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

private struct FlowVectorOverlay: View {
    let reading: OpticalFlowManager.FlowReading

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let dx = CGFloat(reading.dx) * 1.2
            let dy = CGFloat(reading.dy) * 1.2

            ZStack {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: geo.size.width * 0.6, height: geo.size.width * 0.6)

                CrosshairShape()
                    .stroke(Color.white.opacity(0.7), lineWidth: 1)

                Path { path in
                    path.move(to: center)
                    path.addLine(to: CGPoint(x: center.x + dx, y: center.y + dy))
                }
                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 3, lineCap: .round))

                Circle()
                    .fill(Color.cyan)
                    .frame(width: 14, height: 14)
                    .position(x: center.x + dx, y: center.y + dy)
                    .shadow(radius: 4)
            }
        }
    }
}

private struct CrosshairShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerX = rect.midX
        let centerY = rect.midY
        path.move(to: CGPoint(x: centerX, y: rect.minY))
        path.addLine(to: CGPoint(x: centerX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: centerY))
        path.addLine(to: CGPoint(x: rect.maxX, y: centerY))
        return path
    }
}

private struct FlowReadoutView: View {
    let reading: OpticalFlowManager.FlowReading

    var body: some View {
        HStack(spacing: 12) {
            FlowMetricCard(title: "ΔX", value: reading.dx, tint: .blue)
            FlowMetricCard(title: "ΔY", value: reading.dy, tint: .purple)
            FlowMetricCard(title: "|Δ|", value: reading.magnitude, tint: .green)
        }
    }
}

private struct FlowMetricCard: View {
    let title: String
    let value: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value, format: .number.precision(.fractionLength(2)))
                .font(.title3.monospacedDigit())
                .foregroundStyle(.primary)
            Text("px/frame")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(tint.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct MiddleScrollButton: View {
    let onTap: () -> Void
    let onScrollUp: () -> Void
    let onScrollDown: () -> Void

    @GestureState private var dragOffset: CGSize = .zero
    @State private var repeatTimer: Timer?
    @State private var repeatingDirection: ScrollDirection?

    var body: some View {
        let drag = DragGesture(minimumDistance: 0)
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onChanged { value in
                updateRepeating(for: value.translation)
            }
            .onEnded { value in
                handleDragEnd(value.translation)
            }

        return VStack(spacing: 6) {
            Image(systemName: indicatorIcon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("中 / スクロール")
                .font(.caption2)
            Circle()
                .fill(.thinMaterial)
                .frame(width: 68, height: 68)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "circle")
                        .font(.title3)
                )
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(drag)
        .simultaneousGesture(TapGesture().onEnded { onTap() })
        .onDisappear { stopRepeating() }
    }

    private var indicatorIcon: String {
        if dragOffset.height < -12 {
            return "arrow.up"
        } else if dragOffset.height > 12 {
            return "arrow.down"
        }
        return "arrow.up.and.down"
    }

    private func handleDragEnd(_ translation: CGSize) {
        updateRepeating(for: translation)
        stopRepeating()
        if abs(translation.height) <= 20 {
            onTap()
        }
    }

    private func updateRepeating(for translation: CGSize) {
        let newDirection: ScrollDirection?
        if translation.height < -20 {
            newDirection = .up
        } else if translation.height > 20 {
            newDirection = .down
        } else {
            newDirection = nil
        }

        guard newDirection != repeatingDirection else { return }

        stopRepeating()
        repeatingDirection = newDirection

        guard let direction = newDirection else { return }

        trigger(direction)
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
            trigger(direction)
        }
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
        repeatingDirection = nil
    }

    private func trigger(_ direction: ScrollDirection) {
        switch direction {
        case .up:
            onScrollUp()
        case .down:
            onScrollDown()
        }
    }

    private enum ScrollDirection {
        case up
        case down
    }
}
