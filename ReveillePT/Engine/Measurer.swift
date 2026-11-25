import Foundation

/// Turns a `BodyFrame` into the one number an exercise cares about (degrees or percent).
/// Neck and shrug measures are relative to the user's own neutral posture, captured during a short "hold still" baseline.
struct Measurer {
    let exercise: Exercise
    /// Frames collected while the user holds still at the start.
    static let baselineFrameCount = 15

    private(set) var baseline: Double?
    private var baselineSamples: [Double] = []

    init(exercise: Exercise) {
        self.exercise = exercise
        if !Measurer.needsBaseline(exercise.measure.kind) { baseline = 0 }
    }

    static func needsBaseline(_ kind: MeasureKind) -> Bool {
        switch kind {
        case .neckLateral, .neckSagittal, .neckRotation, .shrugRatio: return true
        case .jointAngle, .timedHold: return false
        }
    }

    var isCalibrated: Bool { baseline != nil }
    var calibrationProgress: Double {
        baseline != nil ? 1 : Double(baselineSamples.count) / Double(Measurer.baselineFrameCount)
    }

    /// Returns the measured value for this frame, or nil if the needed joints are not visible
    /// or the baseline is still being collected.
    mutating func measure(_ frame: BodyFrame) -> Double? {
        guard let raw = Measurer.rawValue(exercise.measure, side: exercise.side, frame: frame) else { return nil }
        guard let base = baseline else {
            baselineSamples.append(raw)
            if baselineSamples.count >= Measurer.baselineFrameCount {
                baseline = Geometry.median(baselineSamples)
            }
            return nil
        }
        switch exercise.measure.kind {
        case .shrugRatio:
            // Raw is ear-to-shoulder gap; shrugging makes it smaller.
            return max(0, base - raw)
        case .neckLateral, .neckSagittal, .neckRotation:
            return max(0, raw - base)
        case .jointAngle, .timedHold:
            return raw
        }
    }

    // MARK: - Raw measures

    static func rawValue(_ spec: MeasureSpec, side: String, frame: BodyFrame) -> Double? {
        switch spec.kind {
        case .jointAngle: return jointAngle(spec, side: side, frame: frame)
        case .neckLateral: return neckLateral(frame)
        case .neckSagittal: return neckSagittal(frame)
        case .neckRotation: return neckRotation(frame)
        case .shrugRatio: return shrugGap(frame)
        case .timedHold: return frame.vec(.neck) != nil || frame.vec(.nose) != nil ? 0 : nil
        }
    }

    /// Angle at joint b. For "both" sides the lower side counts, so both arms must reach the goal.
    static func jointAngle(_ spec: MeasureSpec, side: String, frame: BodyFrame) -> Double? {
        guard let a = spec.a, let b = spec.b, let c = spec.c else { return nil }
        func one(_ a: JointName, _ b: JointName, _ c: JointName) -> Double? {
            guard let pa = frame.vec(a), let pb = frame.vec(b), let pc = frame.vec(c) else { return nil }
            return Geometry.angle(pa, vertex: pb, pc)
        }
        let first = one(a, b, c)
        guard side == "both" else { return first }
        let second = one(a.mirrored, b.mirrored, c.mirrored)
        switch (first, second) {
        case let (x?, y?): return min(x, y)
        case let (x?, nil): return x
        case let (nil, y?): return y
        default: return nil
        }
    }

    /// Head tilt toward a shoulder, front view: angle between neck->nose and the line perpendicular to the shoulders.
    static func neckLateral(_ f: BodyFrame) -> Double? {
        guard let l = f.vec(.leftShoulder), let r = f.vec(.rightShoulder) else { return nil }
        let neck = f.vec(.neck) ?? Geometry.midpoint(l, r)
        guard let head = f.vec(.nose) ?? earMidpoint(f) else { return nil }
        let shoulders = r - l
        var up = Vec2(x: -shoulders.y, y: shoulders.x)
        let h = head - neck
        if up.dot(h) < 0 { up = up * -1 }
        return Geometry.angleBetween(h, up)
    }

    /// Forward or back bend, side view: tilt of the shoulder->ear line from vertical.
    static func neckSagittal(_ f: BodyFrame) -> Double? {
        let pairs: [(JointName, JointName)] = [(.rightEar, .rightShoulder), (.leftEar, .leftShoulder)]
        let visible = pairs.compactMap { pair -> (Vec2, Vec2, Double)? in
            guard let ear = f.vec(pair.0), let sh = f.vec(pair.1),
                  let ce = f.joints[pair.0]?.confidence, let cs = f.joints[pair.1]?.confidence else { return nil }
            return (ear, sh, ce + cs)
        }
        guard let best = visible.max(by: { $0.2 < $1.2 }) else { return nil }
        let upward = Vec2(x: 0, y: -1)
        return Geometry.angleBetween(best.0 - best.1, upward)
    }

    /// Head turn, front view (estimate): nose offset from the ear midpoint, as a fraction of half the head width.
    static func neckRotation(_ f: BodyFrame) -> Double? {
        guard let nose = f.vec(.nose) else { return nil }
        let centre: Vec2
        let halfWidth: Double
        if let le = f.vec(.leftEar), let re = f.vec(.rightEar), abs(re.x - le.x) > 1e-4 {
            centre = Geometry.midpoint(le, re)
            halfWidth = abs(re.x - le.x) / 2
        } else if let ls = f.vec(.leftShoulder), let rs = f.vec(.rightShoulder) {
            centre = Geometry.midpoint(ls, rs)
            halfWidth = abs(rs.x - ls.x) * 0.22   // head is roughly 45% of shoulder width
        } else {
            return nil
        }
        guard halfWidth > 1e-4 else { return nil }
        let ratio = max(-1, min(1, (nose.x - centre.x) / halfWidth))
        return abs(asin(ratio) * 180 / .pi)
    }

    /// Average vertical ear-to-shoulder gap as % of shoulder width (smaller when shrugging).
    static func shrugGap(_ f: BodyFrame) -> Double? {
        guard let ls = f.vec(.leftShoulder), let rs = f.vec(.rightShoulder) else { return nil }
        let width = (rs - ls).length
        guard width > 1e-4 else { return nil }
        var gaps: [Double] = []
        if let le = f.vec(.leftEar) { gaps.append(ls.y - le.y) }
        if let re = f.vec(.rightEar) { gaps.append(rs.y - re.y) }
        guard !gaps.isEmpty else { return nil }
        return gaps.reduce(0, +) / Double(gaps.count) / width * 100
    }

    private static func earMidpoint(_ f: BodyFrame) -> Vec2? {
        guard let l = f.vec(.leftEar), let r = f.vec(.rightEar) else { return nil }
        return Geometry.midpoint(l, r)
    }
}
