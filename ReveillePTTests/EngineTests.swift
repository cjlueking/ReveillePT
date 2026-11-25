import XCTest
@testable import ReveillePT

final class GeometryTests: XCTestCase {
    func testRightAngle() {
        let a = Vec2(x: 1, y: 0), b = Vec2(x: 0, y: 0), c = Vec2(x: 0, y: 1)
        XCTAssertEqual(Geometry.angle(a, vertex: b, c) ?? 0, 90, accuracy: 0.001)
    }

    func testZeroLengthReturnsNil() {
        XCTAssertNil(Geometry.angleBetween(Vec2(x: 0, y: 0), Vec2(x: 1, y: 0)))
    }

    func testMedian() {
        XCTAssertEqual(Geometry.median([3, 1, 2]), 2)
        XCTAssertEqual(Geometry.median([4, 1, 2, 3]), 2.5)
    }
}

final class LibraryTests: XCTestCase {
    func testBundledExercisesLoad() {
        let lib = ExerciseLibrary.bundled(Bundle(for: ExerciseSessionModel.self))
        XCTAssertEqual(lib.exercises.count, 15)
        XCTAssertEqual(lib.program.items.count, 19)
        for item in lib.program.items {
            XCTAssertNotNil(lib.exercise(item.exercise), "missing \(item.exercise)")
        }
        XCTAssertEqual(lib.exercise("side_shoulder_raise")?.goalAngle, 130)
    }
}

final class MeasurerTests: XCTestCase {
    private var sideRaise: Exercise {
        ExerciseLibrary.bundled(Bundle(for: ExerciseSessionModel.self)).exercise("side_shoulder_raise")!
    }

    func testSideRaiseAngleIsAspectCorrected() {
        var m = Measurer(exercise: sideRaise)
        for angle in [0.0, 45, 90, 130, 170] {
            let frame = TestFrames.sideRaise(abduction: angle, time: 0)
            XCTAssertEqual(m.measure(frame) ?? -1, angle, accuracy: 1.0, "angle \(angle)")
        }
    }

    func testMissingWristIsIgnored() {
        var frame = TestFrames.sideRaise(abduction: 90, time: 0)
        frame.joints[.rightWrist]?.confidence = 0.1
        frame.joints[.leftWrist]?.confidence = 0.1
        var m = Measurer(exercise: sideRaise)
        XCTAssertNil(m.measure(frame))
    }

    func testBothSidesUsesLowerArm() {
        var frame = TestFrames.sideRaise(abduction: 120, time: 0)
        let low = TestFrames.sideRaise(abduction: 60, time: 0)
        frame.joints[.leftWrist] = low.joints[.leftWrist]
        var m = Measurer(exercise: sideRaise)
        XCTAssertEqual(m.measure(frame) ?? -1, 60, accuracy: 1.0)
    }

    func testNeckLateralUsesBaseline() {
        let lib = ExerciseLibrary.bundled(Bundle(for: ExerciseSessionModel.self))
        var m = Measurer(exercise: lib.exercise("neck_side_bend_right")!)
        for i in 0..<Measurer.baselineFrameCount {
            XCTAssertNil(m.measure(TestFrames.headTilt(3, time: Double(i))))
        }
        XCTAssertTrue(m.isCalibrated)
        XCTAssertEqual(m.measure(TestFrames.headTilt(33, time: 20)) ?? -1, 30, accuracy: 1.5)
    }
}

final class RepCounterTests: XCTestCase {
    private func run(_ values: [Double], dt: Double = 1.0 / 30, config: RepCounter.Config) -> RepCounter {
        var counter = RepCounter(config: config)
        var smoother = Smoother()
        for (i, v) in values.enumerated() {
            counter.update(value: smoother.add(v), time: Double(i) * dt)
        }
        return counter
    }

    private let config = RepCounter.Config(startValue: 20, goalValue: 130, holdSec: 2, targetReps: 10)

    func testTenCleanRepsCountTen() {
        var counter = RepCounter(config: config)
        var smoother = Smoother()
        var m = Measurer(exercise: ExerciseLibrary.bundled(Bundle(for: ExerciseSessionModel.self)).exercise("side_shoulder_raise")!)
        var completed: [Int] = []
        for frame in TestFrames.repSequence(reps: 10) {
            guard let v = m.measure(frame) else { continue }
            for event in counter.update(value: smoother.add(v), time: frame.time) {
                if case .repCompleted(let n) = event { completed.append(n) }
            }
        }
        XCTAssertEqual(counter.reps, 10)
        XCTAssertEqual(completed, Array(1...10))
        XCTAssertEqual(counter.phase, .complete)
    }

    func testJitterDoesNotDoubleCount() {
        var counter = RepCounter(config: RepCounter.Config(startValue: 20, goalValue: 130, holdSec: 2, targetReps: 99))
        var smoother = Smoother()
        var m = Measurer(exercise: ExerciseLibrary.bundled(Bundle(for: ExerciseSessionModel.self)).exercise("side_shoulder_raise")!)
        for frame in TestFrames.repSequence(reps: 6, jitter: 6) {
            guard let v = m.measure(frame) else { continue }
            counter.update(value: smoother.add(v), time: frame.time)
        }
        XCTAssertEqual(counter.reps, 6)
    }

    func testPartialRepDoesNotCount() {
        // Rise to 100 (below the 130 goal) and come back down.
        let values = Array(repeating: 20.0, count: 30) + (0..<45).map { 20 + 80 * Double($0) / 45 }
            + Array(repeating: 100.0, count: 90) + (0..<45).map { 100 - 80 * Double($0) / 45 } + Array(repeating: 20.0, count: 30)
        let counter = run(values, config: config)
        XCTAssertEqual(counter.reps, 0)
    }

    func testShortHoldDoesNotCount() {
        // Reach the goal but drop after 1 s of a 2 s hold.
        let values = Array(repeating: 20.0, count: 30) + Array(repeating: 135.0, count: 30) + Array(repeating: 20.0, count: 60)
        let counter = run(values, config: config)
        XCTAssertEqual(counter.reps, 0)
    }

    func testStartingWithArmsUpWaitsForRest() {
        let values = Array(repeating: 135.0, count: 120) + Array(repeating: 20.0, count: 60)
        let counter = run(values, config: config)
        XCTAssertEqual(counter.reps, 0)
        XCTAssertEqual(counter.phase, .ready)
    }

    func testGoalEventFiresOncePerRep() {
        var counter = RepCounter(config: config)
        var goals = 0
        let values = Array(repeating: 20.0, count: 10) + Array(repeating: 131.0, count: 90) + Array(repeating: 20.0, count: 10)
        for (i, v) in values.enumerated() {
            goals += counter.update(value: v, time: Double(i) / 30).filter { $0 == .reachedGoal }.count
        }
        XCTAssertEqual(goals, 1)
        XCTAssertEqual(counter.reps, 1)
    }
}

final class RecordingTests: XCTestCase {
    func testRecorderSplitsReps() {
        let exercise = ExerciseLibrary.bundled(Bundle(for: ExerciseSessionModel.self)).exercise("side_shoulder_raise")!
        var recorder = TraceRecorder(minInterval: 0.1)
        var counter = RepCounter(config: RepCounter.Config(startValue: 20, goalValue: 130, holdSec: 2, targetReps: 3))
        var smoother = Smoother()
        var m = Measurer(exercise: exercise)
        for frame in TestFrames.repSequence(reps: 3) {
            recorder.add(frame)
            guard let v = m.measure(frame) else { continue }
            for event in counter.update(value: smoother.add(v), time: frame.time) {
                if case .repCompleted = event { recorder.closeRep(best: counter.repBests.last ?? 0) }
            }
        }
        let trace = recorder.finish(exercise: exercise)
        XCTAssertEqual(trace.reps.count, 3)
        for rep in trace.reps {
            XCTAssertGreaterThan(rep.best, 130)
            XCTAssertFalse(rep.frames.isEmpty)
            // About 10 frames per second are kept.
            let rate = Double(rep.frames.count) / max(rep.duration, 0.1)
            XCTAssertLessThan(rate, 11.5)
        }
    }

    func testTraceRoundTripsThroughJSON() throws {
        let exercise = ExerciseLibrary.bundled(Bundle(for: ExerciseSessionModel.self)).exercise("side_shoulder_raise")!
        var recorder = TraceRecorder()
        for frame in TestFrames.repSequence(reps: 1) { recorder.add(frame) }
        recorder.closeRep(best: 140)
        let trace = recorder.finish(exercise: exercise, date: Date(timeIntervalSince1970: 1_800_000_000))
        let data = try TraceStore.encoder.encode(trace)
        let back = try TraceStore.decoder.decode(SessionTrace.self, from: data)
        XCTAssertEqual(back, trace)
    }

    /// Replays a saved recording file through the engine. Real recordings exported from the app
    /// (Recordings > Export for tests) can be dropped into ReveillePTTests/Fixtures and get the same check.
    func testFixtureRecordingsReplay() throws {
        let bundle = Bundle(for: RecordingTests.self)
        let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let fixtures = urls.filter { $0.lastPathComponent.hasPrefix("fixture_") }
        XCTAssertFalse(fixtures.isEmpty, "no fixture recordings bundled")
        let lib = ExerciseLibrary.bundled(Bundle(for: ExerciseSessionModel.self))
        for url in fixtures {
            let trace = try TraceStore.load(url)
            guard let exercise = lib.exercise(trace.exerciseId) else { continue }
            var m = Measurer(exercise: exercise)
            var smoother = Smoother()
            var counter = RepCounter(config: RepCounter.Config(startValue: exercise.startAngle, goalValue: exercise.goalAngle,
                                                               holdSec: exercise.holdSec, targetReps: 999))
            for frame in trace.allFrames {
                guard let v = m.measure(frame) else { continue }
                counter.update(value: smoother.add(v), time: frame.time)
            }
            XCTAssertEqual(counter.reps, trace.reps.count, url.lastPathComponent)
        }
    }
}
