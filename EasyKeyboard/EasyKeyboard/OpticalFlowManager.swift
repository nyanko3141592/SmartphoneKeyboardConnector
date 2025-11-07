import Foundation
import AVFoundation
import Vision
import simd

/// Manages camera capture and optical flow estimation to detect device motion.
final class OpticalFlowManager: NSObject, ObservableObject {
    enum Status: Equatable {
        case idle
        case requestingPermission
        case unauthorized
        case running
        case error(String)

        var description: String {
            switch self {
            case .idle: return "待機中"
            case .requestingPermission: return "カメラ権限を確認中"
            case .unauthorized: return "カメラへのアクセスが許可されていません"
            case .running: return "計測中"
            case .error(let message): return "エラー: \(message)"
            }
        }
    }

    struct FlowReading: Identifiable {
        let id = UUID()
        let timestamp: Date
        let dx: Double
        let dy: Double
        let magnitude: Double

        static let zero = FlowReading(timestamp: .distantPast, dx: 0, dy: 0, magnitude: 0)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var latestReading: FlowReading = .zero
    @Published private(set) var recentReadings: [FlowReading] = []

    let captureSession = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "optical-flow-session")
    private let processingQueue = DispatchQueue(label: "optical-flow-processing", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private var isSessionConfigured = false
    private var sequenceHandler = VNSequenceRequestHandler()
    private var smoothedVector = SIMD2<Double>(repeating: 0)
    private var lastPublishTime = Date.distantPast
    private var isProcessingFrames = false
    private var previousPixelBuffer: CVPixelBuffer?
    private var activeDevice: AVCaptureDevice?
    private let publishInterval: TimeInterval = 0.05 // 20HzでUI更新
    private let smoothingFactor: Double = 0.25
    private let historyLimit = 30
    private let displayScale: Double = 120 // 値を見やすくするためのスケール
    private let preferredTorchLevel: Float = 0.8

    func start() {
        requestCameraAccessIfNeeded { [weak self] granted in
            guard let self else { return }
            DispatchQueue.main.async {
                self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
                guard granted else {
                    self.status = .unauthorized
                    return
                }
                self.status = .idle
            }

            self.sessionQueue.async {
                do {
                    if !self.isSessionConfigured {
                        try self.configureSession()
                        self.isSessionConfigured = true
                    }
                    guard !self.captureSession.isRunning else {
                        self.resetSequence()
                        self.updateCameraEnhancements(enabled: true)
                        DispatchQueue.main.async { self.status = .running }
                        return
                    }
                    self.resetSequence()
                    self.captureSession.startRunning()
                    self.updateCameraEnhancements(enabled: true)
                    self.processingQueue.async { self.isProcessingFrames = true }
                    DispatchQueue.main.async { self.status = .running }
                } catch {
                    self.handle(error: error)
                }
            }
        }
    }

    func stop() {
        sessionQueue.async {
            guard self.captureSession.isRunning else { return }
            self.updateCameraEnhancements(enabled: false)
            self.processingQueue.async { self.isProcessingFrames = false }
            self.captureSession.stopRunning()
            self.resetSequence()
            DispatchQueue.main.async {
                self.status = .idle
                self.latestReading = .zero
                self.recentReadings.removeAll()
            }
        }
    }

    private func configureSession() throws {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480

        let device = try selectBestCamera()
        activeDevice = device

        let input = try AVCaptureDeviceInput(device: device)
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        captureSession.commitConfiguration()
    }

    private func requestCameraAccessIfNeeded(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            DispatchQueue.main.async {
                self.status = .requestingPermission
            }
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        default:
            completion(false)
        }
    }

    private func resetSequence() {
        sequenceHandler = VNSequenceRequestHandler()
        smoothedVector = .zero
        lastPublishTime = .distantPast
        previousPixelBuffer = nil
    }

    private func makeOpticalFlowRequest(target pixelBuffer: CVPixelBuffer) -> VNGenerateOpticalFlowRequest {
        let request = VNGenerateOpticalFlowRequest(targetedCVPixelBuffer: pixelBuffer, options: [:])
        request.computationAccuracy = .high
        request.outputPixelFormat = kCVPixelFormatType_TwoComponent32Float
        return request
    }

    private func selectBestCamera() throws -> AVCaptureDevice {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInUltraWideCamera,
            .builtInTelephotoCamera,
            .builtInWideAngleCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .back)
        for type in types {
            if let device = discovery.devices.first(where: { $0.deviceType == type }) {
                return device
            }
        }
        if let fallback = AVCaptureDevice.default(for: .video) {
            return fallback
        }
        throw NSError(domain: "OpticalFlowManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "カメラデバイスが見つかりません"])
    }

    private func updateCameraEnhancements(enabled: Bool) {
        guard let device = activeDevice else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if enabled {
                if device.hasTorch, device.isTorchModeSupported(.on) {
                    let level = min(preferredTorchLevel, AVCaptureDevice.maxAvailableTorchLevel)
                    try? device.setTorchModeOn(level: level)
                }

                if device.isExposureModeSupported(.custom) {
                    let currentDuration = device.exposureDuration
                    let currentISO = device.iso
                    device.setExposureModeCustom(duration: currentDuration, iso: currentISO, completionHandler: nil)
                } else if device.isExposureModeSupported(.locked) {
                    device.exposureMode = .locked
                }

                device.isSubjectAreaChangeMonitoringEnabled = false
            } else {
                if device.hasTorch, device.isTorchModeSupported(.off) {
                    device.torchMode = .off
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                device.isSubjectAreaChangeMonitoringEnabled = true
            }
        } catch {
            handle(error: error)
        }
    }

    private func handle(error: Error) {
        DispatchQueue.main.async {
            self.status = .error(error.localizedDescription)
        }
    }

    private func publish(vector: SIMD2<Double>) {
        let now = Date()
        guard now.timeIntervalSince(lastPublishTime) >= publishInterval else { return }
        lastPublishTime = now

        let scaled = vector * displayScale
        let magnitude = sqrt(scaled.x * scaled.x + scaled.y * scaled.y)
        let reading = FlowReading(timestamp: now, dx: scaled.x, dy: scaled.y, magnitude: magnitude)

        DispatchQueue.main.async {
            self.latestReading = reading
            self.recentReadings.append(reading)
            if self.recentReadings.count > self.historyLimit {
                self.recentReadings.removeFirst(self.recentReadings.count - self.historyLimit)
            }
        }
    }
}

extension OpticalFlowManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isProcessingFrames else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        guard let previousBuffer = previousPixelBuffer else {
            previousPixelBuffer = pixelBuffer
            return
        }

        do {
            let request = makeOpticalFlowRequest(target: pixelBuffer)
            try sequenceHandler.perform([request], on: previousBuffer, orientation: .up)
            guard let observation = request.results?.first as? VNPixelBufferObservation,
                  let average = averageVector(from: observation.pixelBuffer) else {
                return
            }

            let inverted = SIMD2<Double>(Double(average.x), Double(-average.y))
            smoothedVector = smoothedVector * (1.0 - smoothingFactor) + inverted * smoothingFactor
            publish(vector: smoothedVector)
        } catch {
            handle(error: error)
        }

        previousPixelBuffer = pixelBuffer
    }
}

private extension OpticalFlowManager {
    func averageVector(from pixelBuffer: CVPixelBuffer) -> SIMD2<Float>? {
        guard CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) == kCVReturnSuccess else {
            return nil
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let stride = bytesPerRow / MemoryLayout<SIMD2<Float>>.stride
        let vectorPointer = baseAddress.assumingMemoryBound(to: SIMD2<Float>.self)

        var sum = SIMD2<Float>(repeating: 0)
        for y in 0..<height {
            let rowPointer = vectorPointer + y * stride
            for x in 0..<width {
                sum += rowPointer[x]
            }
        }

        let count = Float(width * height)
        guard count > 0 else { return SIMD2<Float>(repeating: 0) }
        return sum / count
    }
}
