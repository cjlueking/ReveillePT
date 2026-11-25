import Foundation

enum MeasureKind: String, Codable {
    case jointAngle, neckLateral, neckSagittal, neckRotation, shrugRatio, timedHold
}

struct MeasureSpec: Codable, Equatable {
    var kind: MeasureKind
    var a: JointName?
    var b: JointName?
    var c: JointName?
    var direction: String?
}

struct Exercise: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var area: String
    var view: String          // "front" or "side": where the camera should be
    var side: String          // "left", "right", "both", "none"
    var measure: MeasureSpec
    var startAngle: Double
    var goalAngle: Double
    var normalRange: Double
    var holdSec: Double
    var unit: String          // "deg", "pct", "sec"
    var cue: String

    var isTimedHold: Bool { measure.kind == .timedHold }
    var unitSymbol: String { unit == "deg" ? "°" : unit == "pct" ? "%" : "s" }
}

struct ProgramItem: Codable, Equatable {
    var exercise: String
    var reps: Int
}

struct Program: Codable, Equatable {
    var name: String
    var items: [ProgramItem]
}

struct ExerciseLibrary: Codable {
    var version: Int
    var exercises: [Exercise]
    var program: Program

    func exercise(_ id: String) -> Exercise? { exercises.first { $0.id == id } }

    static func load(from data: Data) throws -> ExerciseLibrary {
        try JSONDecoder().decode(ExerciseLibrary.self, from: data)
    }

    /// Loads `exercises.json` from the app bundle.
    static func bundled(_ bundle: Bundle = .main) -> ExerciseLibrary {
        guard let url = bundle.url(forResource: "exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let lib = try? load(from: data) else {
            return ExerciseLibrary(version: 0, exercises: [], program: Program(name: "Empty", items: []))
        }
        return lib
    }
}
