import Foundation
@testable import ReveillePT

/// Builds synthetic body frames for tests (no camera needed).
enum TestFrames {
    static let aspect = 16.0 / 9.0

    /// Person facing the camera with both arms raised to `abduction` degrees from the sides.
    static func sideRaise(abduction: Double, time: Double, aspect: Double = aspect, confidence: Double = 0.9) -> BodyFrame {
        var joints: [JointName: JointPoint] = [:]
        func put(_ name: JointName, _ x: Double, _ y: Double) {
            // x, y given in square units; store normalized.
            joints[name] = JointPoint(x: x / aspect, y: y, confidence: confidence)
        }
        let centre = 0.5 * aspect
        let shoulderY = 0.40, hipY = 0.78, half = 0.13, arm = 0.30
        let r = abduction * .pi / 180
        // Person's right side appears on the image's left in a mirrored front view; geometry is symmetric anyway.
        put(.rightShoulder, centre - half, shoulderY)
        put(.leftShoulder, centre + half, shoulderY)
        put(.rightHip, centre - half, hipY)
        put(.leftHip, centre + half, hipY)
        put(.rightWrist, centre - half - arm * sin(r), shoulderY + arm * cos(r))
        put(.leftWrist, centre + half + arm * sin(r), shoulderY + arm * cos(r))
        put(.rightElbow, centre - half - arm / 2 * sin(r), shoulderY + arm / 2 * cos(r))
        put(.leftElbow, centre + half + arm / 2 * sin(r), shoulderY + arm / 2 * cos(r))
        put(.neck, centre, shoulderY)
        put(.nose, centre, shoulderY - 0.14)
        put(.leftEar, centre + 0.035, shoulderY - 0.15)
        put(.rightEar, centre - 0.035, shoulderY - 0.15)
        return BodyFrame(time: time, aspect: aspect, joints: joints)
    }

    /// Person facing the camera with the head tilted sideways by `tilt` degrees.
    static func headTilt(_ tilt: Double, time: Double) -> BodyFrame {
        var frame = sideRaise(abduction: 10, time: time)
        let neckX = 0.5 * aspect, neckY = 0.40, len = 0.14
        let r = tilt * .pi / 180
        frame.joints[.nose] = JointPoint(x: (neckX + len * sin(r)) / aspect, y: neckY - len * cos(r), confidence: 0.9)
        return frame
    }

    /// A smooth set of reps: rest -> goal -> hold -> rest, sampled at `fps`.
    static func repSequence(reps: Int, rest: Double = 15, peak: Double = 140, hold: Double = 2.5,
                            fps: Double = 30, jitter: Double = 0) -> [BodyFrame] {
        var frames: [BodyFrame] = []
        var t = 0.0
        var seed: UInt64 = 42
        func noise() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return (Double(seed >> 11) / Double(1 << 53) - 0.5) * 2 * jitter
        }
        func add(_ angle: Double) {
            frames.append(sideRaise(abduction: angle + noise(), time: t))
            t += 1 / fps
        }
        for _ in 0..<Int(fps) { add(rest) }                       // 1 s at rest
        for _ in 0..<reps {
            let up = Int(1.5 * fps)
            for i in 0..<up { add(rest + (peak - rest) * Double(i) / Double(up)) }
            for _ in 0..<Int(hold * fps) { add(peak) }
            for i in 0..<up { add(peak - (peak - rest) * Double(i) / Double(up)) }
            for _ in 0..<Int(0.8 * fps) { add(rest) }
        }
        return frames
    }
}
