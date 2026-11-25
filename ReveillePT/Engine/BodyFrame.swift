import Foundation

/// Body joints tracked by Apple Vision (2D body pose). Names are anatomical: `rightShoulder` is the person's right.
enum JointName: String, Codable, CaseIterable, CodingKeyRepresentable {
    case nose, leftEye, rightEye, leftEar, rightEar, neck
    case leftShoulder, rightShoulder, leftElbow, rightElbow, leftWrist, rightWrist
    case leftHip, rightHip, root, leftKnee, rightKnee, leftAnkle, rightAnkle

    /// The same joint on the other side of the body.
    var mirrored: JointName {
        switch self {
        case .leftEye: return .rightEye
        case .rightEye: return .leftEye
        case .leftEar: return .rightEar
        case .rightEar: return .leftEar
        case .leftShoulder: return .rightShoulder
        case .rightShoulder: return .leftShoulder
        case .leftElbow: return .rightElbow
        case .rightElbow: return .leftElbow
        case .leftWrist: return .rightWrist
        case .rightWrist: return .leftWrist
        case .leftHip: return .rightHip
        case .rightHip: return .leftHip
        case .leftKnee: return .rightKnee
        case .rightKnee: return .leftKnee
        case .leftAnkle: return .rightAnkle
        case .rightAnkle: return .leftAnkle
        case .nose, .neck, .root: return self
        }
    }
}

/// One joint position. `x` and `y` are normalized 0...1 in the upright image, origin top-left, y pointing down.
struct JointPoint: Codable, Equatable {
    var x: Double
    var y: Double
    var confidence: Double
}

/// A 2D point in "square" units: x is scaled by the image aspect ratio so angles are not distorted.
struct Vec2: Equatable {
    var x: Double
    var y: Double

    static func - (l: Vec2, r: Vec2) -> Vec2 { Vec2(x: l.x - r.x, y: l.y - r.y) }
    static func + (l: Vec2, r: Vec2) -> Vec2 { Vec2(x: l.x + r.x, y: l.y + r.y) }
    static func * (l: Vec2, s: Double) -> Vec2 { Vec2(x: l.x * s, y: l.y * s) }
    var length: Double { (x * x + y * y).squareRoot() }
    func dot(_ o: Vec2) -> Double { x * o.x + y * o.y }
}

/// Everything Vision saw in one camera frame. Contains no image data.
struct BodyFrame: Codable, Equatable {
    /// Seconds since the session started.
    var time: Double
    /// Image width / height, used to undo the normalized-coordinate stretch.
    var aspect: Double
    var joints: [JointName: JointPoint]

    static let minConfidence = 0.3

    func joint(_ name: JointName, minConfidence: Double = BodyFrame.minConfidence) -> JointPoint? {
        guard let p = joints[name], p.confidence >= minConfidence else { return nil }
        return p
    }

    /// Joint position in undistorted units (x scaled by aspect), or nil if missing or low confidence.
    func vec(_ name: JointName, minConfidence: Double = BodyFrame.minConfidence) -> Vec2? {
        guard let p = joint(name, minConfidence: minConfidence) else { return nil }
        return Vec2(x: p.x * aspect, y: p.y)
    }
}
