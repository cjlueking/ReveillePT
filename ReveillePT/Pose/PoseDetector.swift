import AVFoundation
import QuartzCore
import Vision

/// Runs Apple Vision body-pose detection on camera frames and publishes `BodyFrame`s on the main thread.
/// No image data leaves this class: only joint coordinates and confidences.
final class PoseDetector: ObservableObject {
    @Published private(set) var latestFrame: BodyFrame?
    @Published private(set) var framesPerSecond: Double = 0
    @Published private(set) var imageAspect: Double = 16.0 / 9.0

    /// Called on the main thread for every detected frame.
    var onFrame: ((BodyFrame) -> Void)?

    private let request = VNDetectHumanBodyPoseRequest()
    private let startTime = CACurrentMediaTime()
    private var frameTimes: [CFTimeInterval] = []
    private var busy = false
    private let lock = NSLock()

    private static let mapping: [(VNHumanBodyPoseObservation.JointName, JointName)] = [
        (.nose, .nose), (.leftEye, .leftEye), (.rightEye, .rightEye), (.leftEar, .leftEar), (.rightEar, .rightEar),
        (.neck, .neck), (.leftShoulder, .leftShoulder), (.rightShoulder, .rightShoulder),
        (.leftElbow, .leftElbow), (.rightElbow, .rightElbow), (.leftWrist, .leftWrist), (.rightWrist, .rightWrist),
        (.leftHip, .leftHip), (.rightHip, .rightHip), (.root, .root),
        (.leftKnee, .leftKnee), (.rightKnee, .rightKnee), (.leftAnkle, .leftAnkle), (.rightAnkle, .rightAnkle)
    ]

    /// Call from the camera's video queue.
    func process(_ sampleBuffer: CMSampleBuffer) {
        lock.lock()
        if busy { lock.unlock(); return }
        busy = true
        lock.unlock()
        defer { lock.lock(); busy = false; lock.unlock() }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let width = Double(CVPixelBufferGetWidth(pixelBuffer))
        let height = Double(CVPixelBufferGetHeight(pixelBuffer))
        let aspect = height > 0 ? width / height : 1

        // Frames arrive already rotated upright by the camera connection.
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        var joints: [JointName: JointPoint] = [:]
        do {
            try handler.perform([request])
            if let observation = request.results?.first {
                let points = try observation.recognizedPoints(.all)
                for (visionName, name) in PoseDetector.mapping {
                    guard let p = points[visionName], p.confidence > 0 else { continue }
                    // Vision origin is bottom-left; ours is top-left.
                    joints[name] = JointPoint(x: Double(p.location.x), y: Double(1 - p.location.y), confidence: Double(p.confidence))
                }
            }
        } catch {
            return
        }

        let now = CACurrentMediaTime()
        let frame = BodyFrame(time: now - startTime, aspect: aspect, joints: joints)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.frameTimes.append(now)
            self.frameTimes.removeAll { now - $0 > 1 }
            self.framesPerSecond = Double(self.frameTimes.count)
            self.imageAspect = aspect
            self.latestFrame = frame
            self.onFrame?(frame)
        }
    }
}
