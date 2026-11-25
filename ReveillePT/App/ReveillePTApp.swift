import SwiftUI

@main
struct ReveillePTApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Developer home for steps 1-5. The designed home screen replaces this in step 10.
struct ContentView: View {
    private let library = ExerciseLibrary.bundled()

    var body: some View {
        NavigationStack {
            List {
                Section("Step 2") {
                    NavigationLink {
                        TrackingTestView()
                    } label: {
                        Label("Tracking test", systemImage: "figure.stand")
                    }
                }
                Section {
                    ForEach(library.exercises) { exercise in
                        NavigationLink {
                            ExerciseRunView(exercise: exercise, targetReps: reps(for: exercise))
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name).font(.headline)
                                Text(detail(exercise)).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Steps 3-4: exercises")
                } footer: {
                    Text("Start with Side shoulder raise. Neck exercises are tuned in step 6.")
                }
                Section("Step 5") {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Label("Recordings and replay", systemImage: "clock.arrow.circlepath")
                    }
                }
                Section {
                    Text("Stop if you feel sharp pain, tingling or numbness. Not medical advice; follow your physical therapist.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("ReveillePT")
        }
    }

    private func reps(for exercise: Exercise) -> Int {
        library.program.items.first { $0.exercise == exercise.id }?.reps ?? 10
    }

    private func detail(_ e: Exercise) -> String {
        let goal = e.isTimedHold ? "hold \(Int(e.holdSec)) s" : "goal \(Int(e.goalAngle))\(e.unitSymbol)"
        return "\(reps(for: e)) reps · \(goal) · \(e.view) view"
    }
}
