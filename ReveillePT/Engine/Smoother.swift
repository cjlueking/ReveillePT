import Foundation

/// Moving average over the last few values. Rejects single-frame spikes larger than `maxJump`.
struct Smoother {
    let window: Int
    let maxJump: Double
    private var values: [Double] = []

    init(window: Int = 5, maxJump: Double = 45) {
        self.window = max(1, window)
        self.maxJump = maxJump
    }

    var current: Double? { values.isEmpty ? nil : values.reduce(0, +) / Double(values.count) }

    mutating func add(_ value: Double) -> Double {
        if let avg = current, abs(value - avg) > maxJump, values.count >= window {
            // Likely a tracking glitch: nudge toward it instead of jumping.
            values.append(avg + (value > avg ? maxJump : -maxJump) / 3)
        } else {
            values.append(value)
        }
        if values.count > window { values.removeFirst(values.count - window) }
        return current ?? value
    }

    mutating func reset() { values.removeAll() }
}
