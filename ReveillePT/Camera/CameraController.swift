import AVFoundation
import UIKit

/// Owns the capture session. Frames are rotated upright (and mirrored for the front camera, matching the preview)
/// before they reach the pose detector, so joint coordinates line up with what the user sees.
final class CameraController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum Status: Equatable { case idle, running, denied, failed(String) }

    @Published private(set) var status: Status = .idle
    @Published private(set) var usingFrontCamera = true

    let session: AVCaptureSession
    let previewLayer: AVCaptureVideoPreviewLayer

    /// Called on the video queue for every frame.
    var onSampleBuffer: ((CMSampleBuffer) -> Void)?

    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "reveillept.camera.session")
    private let videoQueue = DispatchQueue(label: "reveillept.camera.video", qos: .userInteractive)
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservations: [NSKeyValueObservation] = []
    private var currentInput: AVCaptureDeviceInput?

    override init() {
        let captureSession = AVCaptureSession()
        session = captureSession
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        super.init()
        previewLayer.videoGravity = .resizeAspect
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configureAndRun() } else { self?.status = .denied }
                }
            }
        default:
            status = .denied
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
        status = .idle
    }

    func switchCamera() {
        usingFrontCamera.toggle()
        configureAndRun()
    }

    private func configureAndRun() {
        let front = usingFrontCamera
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.configure(front: front)
                if !self.session.isRunning { self.session.startRunning() }
                DispatchQueue.main.async {
                    self.attachRotationCoordinator()
                    self.status = .running
                }
            } catch {
                DispatchQueue.main.async { self.status = .failed(error.localizedDescription) }
            }
        }
    }

    private func configure(front: Bool) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .hd1280x720

        if let current = currentInput { session.removeInput(current) }
        let position: AVCaptureDevice.Position = front ? .front : .back
        let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInUltraWideCamera, .builtInWideAngleCamera]
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: position)
        // Prefer the wide-angle lens on the back (ultra-wide distorts angles); front usually has only one.
        let device = discovery.devices.first { $0.deviceType == .builtInWideAngleCamera } ?? discovery.devices.first
        guard let device else { throw CameraError.noCamera }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.cannotAdd }
        session.addInput(input)
        currentInput = input

        if !session.outputs.contains(videoOutput) {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            guard session.canAddOutput(videoOutput) else { throw CameraError.cannotAdd }
            session.addOutput(videoOutput)
        }
        if let connection = videoOutput.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = front
        }
    }

    /// Keeps frames and preview upright as the device rotates (iOS 17 rotation coordinator).
    private func attachRotationCoordinator() {
        guard let device = currentInput?.device else { return }
        rotationObservations.removeAll()
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        applyRotation(coordinator)
        rotationObservations.append(coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak self] c, _ in
            DispatchQueue.main.async { self?.applyRotation(c) }
        })
        rotationObservations.append(coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] c, _ in
            DispatchQueue.main.async { self?.applyRotation(c) }
        })
    }

    private func applyRotation(_ c: AVCaptureDevice.RotationCoordinator) {
        let captureAngle = c.videoRotationAngleForHorizonLevelCapture
        let previewAngle = c.videoRotationAngleForHorizonLevelPreview
        sessionQueue.async { [weak self] in
            guard let self, let conn = self.videoOutput.connection(with: .video),
                  conn.isVideoRotationAngleSupported(captureAngle) else { return }
            conn.videoRotationAngle = captureAngle
        }
        if let pc = previewLayer.connection, pc.isVideoRotationAngleSupported(previewAngle) {
            pc.videoRotationAngle = previewAngle
        }
    }

    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        onSampleBuffer?(sampleBuffer)
    }

    enum CameraError: LocalizedError {
        case noCamera, cannotAdd
        var errorDescription: String? {
            switch self {
            case .noCamera: return "No camera found on this device."
            case .cannotAdd: return "The camera could not be started."
            }
        }
    }
}
