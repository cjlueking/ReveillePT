import SwiftUI

/// Steps 3-4: live exercise with skeleton, angle, vertical goal bar, hold timer, rep counter and sound.
struct ExerciseRunView: View {
    let exercise: Exercise
    let targetReps: Int

    @StateObject private var camera = CameraController()
    @StateObject private var detector = PoseDetector()
    @StateObject private var model: ExerciseSessionModel

    init(exercise: Exercise, targetReps: Int) {
        self.exercise = exercise
        self.targetReps = targetReps
        _model = StateObject(wrappedValue: ExerciseSessionModel(exercise: exercise, targetReps: targetReps))
    }

    var body: some View {
        ZStack {
            CameraPreview(layer: camera.previewLayer).ignoresSafeArea()
            SkeletonOverlay(frame: detector.latestFrame, aspect: detector.imageAspect,
                            highlighted: model.highlightedJoints, progress: model.progress)
                .ignoresSafeArea()

            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    Spacer()
                    messageCard
                    controls
                }
                .padding()
                GoalBar(progress: model.progress, reachedGoal: model.phase == .holding || model.phase == .held,
                        label: goalLabel)
                    .frame(width: 64)
                    .padding(.vertical, 40)
                    .padding(.trailing, 16)
            }
            CameraStatusOverlay(status: camera.status)
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            camera.onSampleBuffer = { [weak detector] buffer in detector?.process(buffer) }
            detector.onFrame = { [weak model] frame in model?.handle(frame) }
            camera.start()
        }
        .onDisappear {
            model.stop()
            camera.stop()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            chip("\(model.reps) / \(targetReps) reps", color: .black.opacity(0.55))
            if let value = model.value, !exercise.isTimedHold {
                chip("\(Int(value.rounded()))\(exercise.unitSymbol)", color: model.progress >= 1 ? .green : .black.opacity(0.55))
                    .accessibilityLabel("Current \(Int(value)) \(exercise.unit == "deg" ? "degrees" : "percent")")
            }
            if model.best > 0 && !exercise.isTimedHold {
                chip("best \(Int(model.best.rounded()))\(exercise.unitSymbol)", color: .black.opacity(0.4))
            }
            chip("\(Int(detector.framesPerSecond)) fps", color: .black.opacity(0.35))
        }
    }

    private var messageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.calibration < 1 && model.isRunning {
                ProgressView(value: model.calibration) { Text("Measuring your neutral position") }
            }
            if model.phase == .holding {
                HoldRing(elapsed: model.holdElapsed, total: exercise.holdSec)
            }
            Text(model.message)
                .font(.title3.weight(.semibold))
            Text("Camera: \(exercise.view) view. Stop if you feel sharp pain, tingling or numbness.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let trace = model.savedTrace {
                Text("Saved \(trace.reps.count) reps for replay.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding(16)
        .frame(maxWidth: 460, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                model.isRunning ? model.stop() : model.start()
            } label: {
                Label(model.isRunning ? "Stop" : "Start", systemImage: model.isRunning ? "stop.fill" : "play.fill")
                    .font(.headline)
                    .frame(minWidth: 120, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.18, green: 0.44, blue: 0.42))

            Button {
                model.muted.toggle()
            } label: {
                Image(systemName: model.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .frame(width: 50, height: 50)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(model.muted ? "Turn sound on" : "Mute sound")

            Button {
                camera.switchCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .frame(width: 50, height: 50)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Switch camera")
        }
    }

    private var goalLabel: String {
        exercise.isTimedHold ? "\(Int(exercise.holdSec)) s" : "\(Int(exercise.goalAngle))\(exercise.unitSymbol)"
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.headline.monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(color, in: Capsule())
    }
}

/// Vertical bar that fills from the bottom toward the goal line at the top.
struct GoalBar: View {
    let progress: Double
    let reachedGoal: Bool
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 4)
                .background(Color.black.opacity(0.5), in: Capsule())
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.25))
                    RoundedRectangle(cornerRadius: 14)
                        .fill(reachedGoal || progress >= 1 ? Color.green : Color(red: 0.88, green: 0.66, blue: 0.31))
                        .frame(height: geo.size.height * CGFloat(max(0, min(1, progress))))
                        .animation(.easeOut(duration: 0.12), value: progress)
                    RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.8), lineWidth: 2)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Goal progress \(Int(progress * 100)) percent")
    }
}

/// Countdown ring while holding at the goal.
struct HoldRing: View {
    let elapsed: Double
    let total: Double

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(total > 0 ? min(1, elapsed / total) : 1))
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(max(0, total - elapsed).rounded(.up)))")
                    .font(.headline.monospacedDigit())
            }
            .frame(width: 48, height: 48)
            Text("Holding").font(.headline)
        }
    }
}
