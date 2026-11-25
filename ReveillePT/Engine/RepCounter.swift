import Foundation

/// Counts reps from a stream of smoothed values.
///
/// One rep: start near rest -> reach the goal -> hold for `holdSec` -> come back down near rest.
/// Hysteresis (separate thresholds for "at goal", "still holding" and "back at rest") prevents double counts.
struct RepCounter {
    struct Config: Equatable {
        var startValue: Double
        var goalValue: Double
        var holdSec: Double
        var targetReps: Int
        /// Progress at or above this keeps a hold going after the goal is reached.
        var holdTolerance: Double = 0.85
        /// Progress below this counts as "back at rest".
        var restThreshold: Double = 0.25
    }

    enum Phase: String, Equatable {
        case waitingForRest   // user must start from rest before the first rep can count
        case ready            // at rest, next rep can start
        case rising
        case holding
        case held             // hold done, waiting to return to rest
        case complete         // all reps done
    }

    enum Event: Equatable {
        case reachedGoal
        case holdBroken
        case holdComplete
        case repCompleted(Int)
        case setCompleted
    }

    let config: Config
    private(set) var phase: Phase = .waitingForRest
    private(set) var reps = 0
    private(set) var holdStart: Double?
    private(set) var lastProgress: Double = 0
    /// Highest value seen in the current rep and across the whole set.
    private(set) var repBest: Double = 0
    private(set) var setBest: Double = 0
    /// Best value of each completed rep.
    private(set) var repBests: [Double] = []

    init(config: Config) { self.config = config }

    func progress(for value: Double) -> Double {
        let span = config.goalValue - config.startValue
        guard abs(span) > 1e-9 else { return 0 }
        return (value - config.startValue) / span
    }

    /// Seconds held so far in the current hold.
    func holdElapsed(at time: Double) -> Double {
        guard phase == .holding, let start = holdStart else { return phase == .held ? config.holdSec : 0 }
        return max(0, time - start)
    }

    @discardableResult
    mutating func update(value: Double, time: Double) -> [Event] {
        guard phase != .complete else { return [] }
        let p = progress(for: value)
        lastProgress = p
        var events: [Event] = []
        if phase != .waitingForRest {
            repBest = max(repBest, value)
            setBest = max(setBest, value)
        }

        switch phase {
        case .waitingForRest:
            if p < config.restThreshold { phase = .ready }

        case .ready:
            if p >= 1 {
                events.append(.reachedGoal)
                events += startHold(time: time)
            } else if p >= config.restThreshold {
                phase = .rising
            }

        case .rising:
            if p >= 1 {
                events.append(.reachedGoal)
                events += startHold(time: time)
            } else if p < config.restThreshold {
                // Came back down without reaching the goal: not a rep.
                phase = .ready
                repBest = 0
            }

        case .holding:
            if p < config.holdTolerance {
                events.append(.holdBroken)
                holdStart = nil
                phase = p < config.restThreshold ? .ready : .rising
                if phase == .ready { repBest = 0 }
            } else if let start = holdStart, time - start >= config.holdSec {
                events.append(.holdComplete)
                phase = .held
            }

        case .held:
            if p < config.restThreshold {
                reps += 1
                repBests.append(repBest)
                repBest = 0
                holdStart = nil
                events.append(.repCompleted(reps))
                if reps >= config.targetReps {
                    phase = .complete
                    events.append(.setCompleted)
                } else {
                    phase = .ready
                }
            }

        case .complete:
            break
        }
        return events
    }

    private mutating func startHold(time: Double) -> [Event] {
        if config.holdSec <= 0 {
            phase = .held
            return [.holdComplete]
        }
        holdStart = time
        phase = .holding
        return []
    }
}
