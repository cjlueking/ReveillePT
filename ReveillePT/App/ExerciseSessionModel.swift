import Foundation

/// Runs one set of one exercise: frames in -> measured value -> smoothing -> rep counter -> sound, haptics, recording.
final class ExerciseSessionModel: ObservableObject {
    let exercise: Exercise
    let targetReps: Int

    @Published private(set) var value: Double?
    @Published private(set) var progress: Double = 0
    @Published private(set) var holdElapsed: Double = 0
    @Published private(set) var reps = 0
    @Published private(set) var best: Double = 0
    @Published private(set) var phase: RepCounter.Phase = .waitingForRest
    @Published private(set) var calibration: Double = 1
    @Published private(set) var message = "Tap Start when you're in view."
    @Published private(set) var isRunning = false
    @Published private(set) var savedTrace: SessionTrace?
    @Published var muted = false { didSet { tone.muted = muted } }

    /// Seconds of rest between timed holds.
    static let timedRestSeconds = 3.0

    private var measurer: Measurer
    private var smoother = Smoother()
    private var counter: RepCounter
    private var recorder = TraceRecorder()
    private let tone = ToneEngine()
    private var timedRestUntil: Double?

    init(exercise: Exercise, targetReps: Int) {
        self.exercise = exercise
        self.targetReps = targetReps
        self.measurer = Measurer(exercise: exercise)
        self.counter = RepCounter(config: ExerciseSessionModel.config(exercise, targetReps))
    }

    static func config(_ e: Exercise, _ reps: Int) -> RepCounter.Config {
        if e.isTimedHold {
            return RepCounter.Config(startValue: 0, goalValue: 1, holdSec: e.holdSec, targetReps: reps)
        }
        return RepCounter.Config(startValue: e.startAngle, goalValue: e.goalAngle, holdSec: e.holdSec, targetReps: reps)
    }

    var highlightedJoints: Set<JointName> {
        let m = exercise.measure
        switch m.kind {
        case .jointAngle:
            var set = Set([m.a, m.b, m.c].compactMap { $0 })
            if exercise.side == "both" { set.formUnion(set.map(\.mirrored)) }
            return set
        case .neckLateral, .neckRotation, .neckSagittal:
            return [.nose, .neck, .leftEar, .rightEar, .leftEye, .rightEye]
        case .shrugRatio:
            return [.leftShoulder, .rightShoulder, .leftEar, .rightEar, .neck]
        case .timedHold:
            return []
        }
    }

    func start() {
        measurer = Measurer(exercise: exercise)
        smoother.reset()
        counter = RepCounter(config: ExerciseSessionModel.config(exercise, targetReps))
        recorder = TraceRecorder()
        timedRestUntil = nil
        savedTrace = nil
        reps = 0
        best = 0
        progress = 0
        holdElapsed = 0
        phase = counter.phase
        calibration = measurer.calibrationProgress
        tone.muted = muted
        tone.start()
        isRunning = true
        message = measurer.isCalibrated ? "Start at rest." : "Hold still for a moment…"
    }

    /// Stops the set. Saves a recording if at least one rep was done.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        tone.update(progress: 0, active: false)
        tone.stop()
        save()
    }

    func handle(_ frame: BodyFrame) {
        guard isRunning else { return }
        recorder.add(frame)

        let measured: Double?
        if exercise.isTimedHold {
            measured = timedValue(frame)
        } else {
            measured = measurer.measure(frame)
        }
        calibration = measurer.calibrationProgress

        guard let raw = measured else {
            tone.update(progress: 0, active: false)
            message = measurer.isCalibrated ? "Step into view so your \(viewHint) is visible." : "Hold still for a moment…"
            return
        }
        let smoothed = exercise.isTimedHold ? raw : smoother.add(raw)
        value = smoothed

        let events = counter.update(value: smoothed, time: frame.time)
        phase = counter.phase
        reps = counter.reps
        best = counter.setBest
        holdElapsed = counter.holdElapsed(at: frame.time)
        progress = exercise.isTimedHold
            ? min(1, holdElapsed / max(exercise.holdSec, 0.1))
            : max(0, min(1, counter.progress(for: smoothed)))

        let toneOn = !exercise.isTimedHold && (phase == .rising || (phase == .ready && progress > 0.05))
        tone.update(progress: progress, active: toneOn)

        for event in events {
            switch event {
            case .reachedGoal:
                tone.goalDing()
                Haptics.goal()
            case .holdBroken:
                Haptics.warning()
            case .holdComplete:
                if exercise.isTimedHold { timedRestUntil = frame.time + ExerciseSessionModel.timedRestSeconds }
            case .repCompleted:
                recorder.closeRep(best: counter.repBests.last ?? 0)
                tone.repChime()
                Haptics.rep()
            case .setCompleted:
                tone.setComplete()
                finish()
            }
        }
        message = text(for: phase, time: frame.time)
    }

    // MARK: - Private

    /// Timed holds have no angle: "at goal" while visible and not resting, "at rest" during the rest gap.
    private func timedValue(_ frame: BodyFrame) -> Double? {
        guard Measurer.rawValue(exercise.measure, side: exercise.side, frame: frame) != nil else { return nil }
        if timedRestUntil == nil { timedRestUntil = frame.time + ExerciseSessionModel.timedRestSeconds }
        return frame.time < (timedRestUntil ?? 0) ? 0 : 1
    }

    private func finish() {
        isRunning = false
        tone.update(progress: 0, active: false)
        save()
        message = "Set complete: \(reps) of \(targetReps)."
        // Let the final chime ring out before stopping audio.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self, !self.isRunning else { return }
            self.tone.stop()
        }
    }

    private func save() {
        let trace = recorder.finish(exercise: exercise)
        guard !trace.reps.isEmpty else { return }
        if (try? TraceStore.save(trace)) != nil { savedTrace = trace }
    }

    private var viewHint: String {
        switch exercise.measure.kind {
        case .jointAngle: return "arms and hips are"
        case .shrugRatio: return "head and shoulders are"
        default: return "head and shoulders are"
        }
    }

    private func text(for phase: RepCounter.Phase, time: Double) -> String {
        switch phase {
        case .waitingForRest:
            return exercise.isTimedHold ? "Get ready…" : "Start at rest."
        case .ready:
            return exercise.isTimedHold ? "Rest…" : "Go: \(exercise.cue)"
        case .rising:
            return "Keep going…"
        case .holding:
            let left = max(0, exercise.holdSec - holdElapsed)
            return "Hold… \(Int(left.rounded(.up))) s"
        case .held:
            return exercise.isTimedHold ? "Relax." : "Good. Now relax back down."
        case .complete:
            return "Set complete: \(reps) of \(targetReps)."
        }
    }
}
