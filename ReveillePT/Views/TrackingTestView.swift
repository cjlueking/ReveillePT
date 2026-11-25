import SwiftUI

/// Step 2 test screen: live camera, skeleton, frame rate and how many joints are seen.
struct TrackingTestView: View {
    @StateObject private var camera = CameraController()
    @StateObject private var detector = PoseDetector()

    var body: some View {
        ZStack {
            CameraPreview(layer: camera.previewLayer).ignoresSafeArea()
            SkeletonOverlay(frame: detector.latestFrame, aspect: detector.imageAspect).ignoresSafeArea()
            VStack {
                HStack(spacing: 12) {
                    statChip("\(Int(detector.framesPerSecond)) fps", good: detector.framesPerSecond >= 20)
                    statChip("\(visibleJoints) of 19 joints", good: visibleJoints >= 13)
                    Spacer()
                    Button {
                        camera.switchCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.title2)
                            .frame(width: 48, height: 48)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Switch camera")
                }
                .padding()
                Spacer()
                Text("Stand 6 to 8 feet back. Pass: the skeleton follows you smoothly, front and side, at 20 fps or more.")
                    .font(.callout)
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .padding()
            }
            CameraStatusOverlay(status: camera.status)
        }
        .navigationTitle("Tracking test")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            camera.onSampleBuffer = { [weak detector] buffer in detector?.process(buffer) }
            camera.start()
        }
        .onDisappear { camera.stop() }
    }

    private var visibleJoints: Int {
        detector.latestFrame?.joints.values.filter { $0.confidence >= BodyFrame.minConfidence }.count ?? 0
    }

    private func statChip(_ text: String, good: Bool) -> some View {
        Text(text)
            .font(.headline.monospacedDigit())
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(good ? Color.green.opacity(0.85) : Color.orange.opacity(0.85), in: Capsule())
            .foregroundStyle(.white)
    }
}

struct CameraStatusOverlay: View {
    let status: CameraController.Status

    var body: some View {
        switch status {
        case .denied:
            message("Camera access is off. Turn it on in Settings > ReveillePT > Camera.")
        case .failed(let reason):
            message(reason)
        case .idle, .running:
            EmptyView()
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .multilineTextAlignment(.center)
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(32)
    }
}
