import SwiftUI

/// Step 5: saved sets, each replayable rep by rep as a skeleton.
struct HistoryView: View {
    @State private var files: [URL] = []

    var body: some View {
        List {
            if files.isEmpty {
                Text("No recordings yet. Finish at least one rep of an exercise and it appears here.")
                    .foregroundStyle(.secondary)
            }
            ForEach(files, id: \.self) { url in
                if let trace = try? TraceStore.load(url) {
                    NavigationLink {
                        ReplayView(trace: trace, fileURL: url)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trace.exerciseName).font(.headline)
                            Text("\(trace.date.formatted(date: .abbreviated, time: .shortened)) · \(trace.reps.count) reps · best \(Int((trace.reps.map(\.best).max() ?? 0).rounded()))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { offsets in
                for i in offsets { TraceStore.delete(files[i]) }
                files = TraceStore.list()
            }
        }
        .navigationTitle("Recordings")
        .onAppear { files = TraceStore.list() }
    }
}

/// Plays back the saved joint positions of one rep over the goal, with a per-rep chart.
struct ReplayView: View {
    let trace: SessionTrace
    let fileURL: URL

    @State private var repIndex = 0
    @State private var startedAt = Date()
    @State private var playing = true

    private var rep: RepTrace? { trace.reps.indices.contains(repIndex) ? trace.reps[repIndex] : nil }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 24).fill(Color(red: 0.12, green: 0.2, blue: 0.22))
                TimelineView(.periodic(from: startedAt, by: 0.05)) { context in
                    SkeletonOverlay(frame: frame(at: context.date), aspect: rep?.frames.first?.aspect ?? 16.0 / 9.0,
                                    highlighted: [])
                }
                .padding(12)
            }
            .frame(minHeight: 320)
            .accessibilityLabel("Skeleton replay of rep \(repIndex + 1)")

            HStack {
                Button {
                    repIndex = max(0, repIndex - 1); restart()
                } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .disabled(repIndex == 0)
                Spacer()
                VStack(spacing: 2) {
                    Text("Rep \(repIndex + 1) of \(trace.reps.count)").font(.headline)
                    if let rep {
                        Text("Best \(Int(rep.best.rounded())) of goal \(Int(trace.goalValue.rounded()))")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    repIndex = min(trace.reps.count - 1, repIndex + 1); restart()
                } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .disabled(repIndex >= trace.reps.count - 1)
            }

            RepBars(bests: trace.reps.map(\.best), goal: trace.goalValue, selected: repIndex) { i in
                repIndex = i; restart()
            }
            .frame(height: 120)

            HStack {
                Button(playing ? "Pause" : "Play") { playing.toggle(); if playing { restart() } }
                    .buttonStyle(.bordered)
                Spacer()
                ShareLink(item: fileURL) { Label("Export for tests", systemImage: "square.and.arrow.up") }
            }
        }
        .padding()
        .navigationTitle(trace.exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func restart() { startedAt = Date(); playing = true }

    /// Frame to show at `date`, looping the rep.
    private func frame(at date: Date) -> BodyFrame? {
        guard let rep, let first = rep.frames.first else { return nil }
        guard playing else { return first }
        let duration = max(rep.duration, 0.1)
        let t = date.timeIntervalSince(startedAt).truncatingRemainder(dividingBy: duration + 0.8)
        let target = first.time + min(t, duration)
        return rep.frames.last(where: { $0.time <= target }) ?? first
    }
}

/// One bar per rep (best value) with a dashed goal line.
struct RepBars: View {
    let bests: [Double]
    let goal: Double
    let selected: Int
    let onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let top = max(goal * 1.15, bests.max() ?? 0, 1)
            ZStack(alignment: .bottomLeading) {
                Path { p in
                    let y = geo.size.height * CGFloat(1 - goal / top)
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(bests.enumerated()), id: \.offset) { i, value in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(i == selected ? Color(red: 0.18, green: 0.44, blue: 0.42) : Color(red: 0.66, green: 0.8, blue: 0.78))
                            .frame(height: max(4, geo.size.height * CGFloat(value / top)))
                            .onTapGesture { onSelect(i) }
                            .accessibilityLabel("Rep \(i + 1): \(Int(value.rounded()))")
                    }
                }
            }
        }
    }
}
