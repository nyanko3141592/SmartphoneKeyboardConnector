import SwiftUI

struct MouseModeView: View {
    @ObservedObject var flowManager: OpticalFlowManager

    var body: some View {
        VStack(spacing: 16) {
            header

            CameraPreviewView(session: flowManager.captureSession)
                .overlay(alignment: .center) {
                    FlowVectorOverlay(reading: flowManager.latestReading)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 8)
                .frame(maxWidth: .infinity)
                .frame(height: 360)

            FlowReadoutView(reading: flowManager.latestReading)

            FlowHistoryView(readings: flowManager.recentReadings)
                .frame(height: 110)

            Text("※ 現段階では検出した変量のみを表示し、XIAOには送信しません")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
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

private struct FlowHistoryView: View {
    let readings: [OpticalFlowManager.FlowReading]

    var body: some View {
        GeometryReader { geo in
            let points = normalizedPoints(in: geo.size)
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                if points.count > 1 {
                    Path { path in
                        path.move(to: points.first ?? .zero)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                } else {
                    Text("履歴が足りません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard let maxMagnitude = readings.map({ $0.magnitude }).max(), maxMagnitude > 0 else {
            return []
        }
        let stepX = size.width / CGFloat(max(readings.count - 1, 1))
        return readings.enumerated().map { offset, reading in
            let x = CGFloat(offset) * stepX
            let normalizedY = CGFloat(reading.magnitude / maxMagnitude)
            let y = size.height - normalizedY * size.height
            return CGPoint(x: x, y: y)
        }
    }
}
