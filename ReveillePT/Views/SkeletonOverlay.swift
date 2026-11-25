import SwiftUI

/// Draws the stick figure (lines and dots) for one `BodyFrame` over an aspect-fit image area.
struct SkeletonOverlay: View {
    let frame: BodyFrame?
    var aspect: Double
    /// Joints that the current exercise measures; drawn larger and tinted.
    var highlighted: Set<JointName> = []
    /// 0...1 progress toward the goal; turns the highlight green at the goal.
    var progress: Double = 0

    static let bones: [(JointName, JointName)] = [
        (.leftEar, .leftEye), (.leftEye, .nose), (.nose, .rightEye), (.rightEye, .rightEar),
        (.nose, .neck), (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip), (.leftHip, .rightHip),
        (.neck, .root), (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
    ]

    var body: some View {
        Canvas { context, size in
            guard let frame else { return }
            let rect = fittedRect(aspect: aspect, in: size)
            func point(_ name: JointName) -> CGPoint? {
                guard let j = frame.joint(name) else { return nil }
                return CGPoint(x: rect.minX + CGFloat(j.x) * rect.width, y: rect.minY + CGFloat(j.y) * rect.height)
            }
            let accent = progress >= 1 ? Color.green : Color(red: 0.88, green: 0.66, blue: 0.31)
            for (a, b) in SkeletonOverlay.bones {
                guard let pa = point(a), let pb = point(b) else { continue }
                var path = Path()
                path.move(to: pa)
                path.addLine(to: pb)
                let hot = highlighted.contains(a) && highlighted.contains(b)
                context.stroke(path, with: .color(hot ? accent : .white.opacity(0.85)),
                               style: StrokeStyle(lineWidth: hot ? 7 : 4, lineCap: .round))
            }
            for name in JointName.allCases {
                guard let p = point(name) else { continue }
                let hot = highlighted.contains(name)
                let r: CGFloat = hot ? 9 : 6
                let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                context.fill(dot, with: .color(hot ? accent : Color(red: 0.5, green: 0.88, blue: 0.69)))
            }
        }
        .allowsHitTesting(false)
    }
}
