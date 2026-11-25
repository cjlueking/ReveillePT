import Foundation

/// Joint positions for one rep. No images: about 10 skeletons per second, a few KB per rep.
struct RepTrace: Codable, Identifiable, Equatable {
    var index: Int
    var best: Double
    var frames: [BodyFrame]
    var id: Int { index }
    var duration: Double { (frames.last?.time ?? 0) - (frames.first?.time ?? 0) }
}

/// Everything saved from one set of one exercise.
struct SessionTrace: Codable, Identifiable, Equatable {
    var id: UUID
    var exerciseId: String
    var exerciseName: String
    var date: Date
    var startValue: Double
    var goalValue: Double
    var unit: String
    var reps: [RepTrace]
    /// Frames after the last counted rep (an unfinished rep), kept so tests can use them.
    var trailing: [BodyFrame]

    var allFrames: [BodyFrame] { reps.flatMap(\.frames) + trailing }
}

/// Collects frames during a set and cuts them into reps as the rep counter reports them.
struct TraceRecorder {
    let minInterval: Double
    private(set) var completed: [RepTrace] = []
    private var current: [BodyFrame] = []
    private var lastTime: Double = -.infinity

    init(minInterval: Double = 0.1) { self.minInterval = minInterval }

    mutating func add(_ frame: BodyFrame) {
        guard frame.time - lastTime >= minInterval else { return }
        lastTime = frame.time
        current.append(frame)
    }

    mutating func closeRep(best: Double) {
        completed.append(RepTrace(index: completed.count + 1, best: best, frames: current))
        current = []
    }

    func finish(exercise: Exercise, date: Date = Date()) -> SessionTrace {
        SessionTrace(id: UUID(), exerciseId: exercise.id, exerciseName: exercise.name, date: date,
                     startValue: exercise.startAngle, goalValue: exercise.goalAngle, unit: exercise.unit,
                     reps: completed, trailing: current)
    }
}

/// Saves recordings as JSON in the app's Documents/recordings folder (visible in the Files app).
enum TraceStore {
    static var folder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @discardableResult
    static func save(_ trace: SessionTrace) throws -> URL {
        let stamp = ISO8601DateFormatter().string(from: trace.date).replacingOccurrences(of: ":", with: "-")
        let url = folder.appendingPathComponent("\(stamp)_\(trace.exerciseId).json")
        try encoder.encode(trace).write(to: url, options: .atomic)
        return url
    }

    static func list() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    static func load(_ url: URL) throws -> SessionTrace {
        try decoder.decode(SessionTrace.self, from: Data(contentsOf: url))
    }

    static func delete(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
