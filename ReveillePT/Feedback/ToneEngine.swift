import AVFoundation

/// Synthesizes the guidance sound: a soft pulsing tone whose pitch and pulse speed rise as the user nears the goal,
/// plus a bell "ding" at the goal and a lower chime when a rep is counted. No audio files needed.
final class ToneEngine {
    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44_100
    private let state = State()
    private var source: AVAudioSourceNode?
    private var started = false

    /// Shared with the audio render thread. Plain stores of Doubles/Bools; occasional tearing is inaudible.
    private final class State {
        var active = false
        var muted = false
        var progress: Double = 0
        var phase: Double = 0
        var pulsePhase: Double = 0
        var bellFrequency: Double = 1318.5
        var bellFramesLeft = 0
        var bellTotal = 1
        var bellPhase: Double = 0
    }

    var muted: Bool {
        get { state.muted }
        set { state.muted = newValue }
    }

    init() {
        let sr = sampleRate
        let state = self.state
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1) else { return }
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let twoPi = 2.0 * Double.pi
            for frame in 0..<Int(frameCount) {
                var sample = 0.0
                if state.active && !state.muted {
                    let p = max(0, min(1, state.progress))
                    let frequency = 330 + 550 * p          // rises toward the goal
                    let pulseRate = 1.5 + 9 * p            // pulses faster toward the goal
                    state.phase += twoPi * frequency / sr
                    if state.phase > twoPi { state.phase -= twoPi }
                    state.pulsePhase += twoPi * pulseRate / sr
                    if state.pulsePhase > twoPi { state.pulsePhase -= twoPi }
                    let envelope = 0.5 + 0.5 * sin(state.pulsePhase)
                    sample += sin(state.phase) * 0.10 * envelope * envelope
                }
                if state.bellFramesLeft > 0 {
                    if !state.muted {
                        let t = Double(state.bellTotal - state.bellFramesLeft) / sr
                        let amplitude = 0.32 * exp(-t * 5.5)
                        state.bellPhase += twoPi * state.bellFrequency / sr
                        if state.bellPhase > twoPi { state.bellPhase -= twoPi }
                        sample += amplitude * (sin(state.bellPhase) + 0.35 * sin(2 * state.bellPhase))
                    }
                    state.bellFramesLeft -= 1
                }
                let value = Float(max(-1, min(1, sample)))
                for buffer in buffers {
                    let samples = UnsafeMutableBufferPointer<Float>(buffer)
                    if frame < samples.count { samples[frame] = value }
                }
            }
            return noErr
        }
        source = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    func start() {
        guard !started else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            try engine.start()
            started = true
        } catch {
            started = false
        }
    }

    func stop() {
        state.active = false
        engine.stop()
        started = false
    }

    /// Update the guidance tone. `active` false silences it (e.g. at rest or while holding).
    func update(progress: Double, active: Bool) {
        state.progress = progress
        state.active = active
    }

    /// High bell: the goal was reached.
    func goalDing() { ring(frequency: 1318.5, seconds: 1.2) }

    /// Lower chime: a rep was counted.
    func repChime() { ring(frequency: 784, seconds: 0.6) }

    /// Rising double chime: the set is done.
    func setComplete() {
        ring(frequency: 1046.5, seconds: 1.4)
    }

    private func ring(frequency: Double, seconds: Double) {
        state.bellFrequency = frequency
        state.bellPhase = 0
        state.bellTotal = Int(sampleRate * seconds)
        state.bellFramesLeft = state.bellTotal
    }
}
