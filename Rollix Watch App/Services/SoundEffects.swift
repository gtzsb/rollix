//
//  SoundEffects.swift
//  Rollix Watch App
//

import AVFoundation
import os

/// Synthesizes and plays the rolling sound and the jingles for critical successes and failures.
@MainActor
final class SoundEffects {
    /// How long the rolling sound lasts, in seconds. The roll animation matches it.
    nonisolated static let rollingDuration = 1.1
    /// The watch speaker doesn't reproduce much above 10 kHz, and half the CD rate
    /// halves the time it takes to render the effects.
    nonisolated static let sampleRate = 22_050.0

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Rollix", category: "SoundEffects")

    nonisolated enum Effect: CaseIterable {
        /// A die tumbling on a wooden table. Different on every roll.
        case rolling
        /// A short brass fanfare ending on a major chord.
        case criticalSuccess
        /// A "sad trombone" (wah wah wah wahhh).
        case criticalFailure
    }

    private nonisolated struct Note {
        /// Several frequencies make a chord.
        let frequencies: [Double]
        let duration: Double
        /// Held notes get a vibrato.
        var isHeld = false
    }

    private nonisolated struct Melody {
        let notes: [Note]
        /// Whether each note opens then closes, like a trombone with a plunger mute.
        let isMuted: Bool
        /// Whether the pitch of held notes sags at the end.
        let droops: Bool

        /// Quick rising arpeggio, then a held C major chord.
        static let fanfare = Melody(
            notes: [
                Note(frequencies: [196.00], duration: 0.13), // G3
                Note(frequencies: [261.63], duration: 0.13), // C4
                Note(frequencies: [329.63], duration: 0.13), // E4
                Note(frequencies: [392.00], duration: 0.26), // G4
                Note(frequencies: [329.63], duration: 0.13), // E4
                Note(frequencies: [261.63, 329.63, 392.00, 523.25], duration: 1.0, isHeld: true), // C major
            ],
            isMuted: false,
            droops: false
        )

        /// Three short descending notes, then a long one that wobbles and droops.
        static let sadTrombone = Melody(
            notes: [
                Note(frequencies: [293.66], duration: 0.42), // D4
                Note(frequencies: [277.18], duration: 0.42), // C#4
                Note(frequencies: [261.63], duration: 0.42), // C4
                Note(frequencies: [246.94], duration: 1.40, isHeld: true), // B3
            ],
            isMuted: true,
            droops: true
        )
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: SoundEffects.sampleRate, channels: 1)
    /// Configures the audio session once, even when several effects ask at the same time.
    private var sessionActivation: Task<Void, Error>?
    /// Identifies the buffer playing last, so the engine only pauses once that one ends.
    private var playback = 0
    /// The samples of each effect, rendered ahead of time. The rolling sound is
    /// replaced after each use so every roll sounds different.
    private var renders: [Effect: Task<[Float], Never>] = [:]

    /// Plays the effect once it is rendered.
    /// - Parameter deadline: When to give up, for an effect that would be out of sync
    ///   with the screen if it started any later.
    func play(_ effect: Effect, startingBy deadline: ContinuousClock.Instant? = nil) async {
        do {
            try await activateSession()
            guard let buffer = await buffer(for: effect) else { return }
            // A new roll may have stopped the sound while it was being prepared.
            if Task.isCancelled { return }
            if let deadline, ContinuousClock.now > deadline { return }
            try start(buffer)
        } catch {
            Self.logger.error("Unable to play sound effect: \(String(describing: error), privacy: .public)")
        }
    }

    /// Synchronous on purpose: from an async context, `scheduleBuffer` would pick
    /// the overload that waits for playback to finish.
    private func start(_ buffer: AVAudioPCMBuffer) throws {
        try startEngine()
        player.stop()
        playback += 1
        let current = playback
        // Also called when the player is stopped. Called on an audio thread.
        player.scheduleBuffer(buffer, at: nil, completionCallbackType: .dataPlayedBack) { @Sendable [weak self] _ in
            Task { @MainActor in self?.pauseEngine(after: current) }
        }
        try player.playAudio()
    }

    func stop() {
        player.stop()
    }

    /// A running engine keeps the audio hardware busy and drains the battery even
    /// when silent, so it pauses between effects. Pausing keeps its resources, so
    /// it starts again quickly.
    private func pauseEngine(after finished: Int) {
        // A newer effect may have started meanwhile.
        guard finished == playback, engine.isRunning else { return }
        engine.pause()
    }

    /// Activates the audio session, sets up the engine and renders every effect ahead
    /// of time: on the watch that takes seconds, which would otherwise delay the first
    /// roll or critical result.
    func prepare() async {
        for effect in Effect.allCases {
            _ = renderTask(for: effect)
        }
        do {
            try await activateSession()
            try attachPlayer()
            engine.prepare()
        } catch {
            Self.logger.error("Unable to prepare audio: \(String(describing: error), privacy: .public)")
        }
    }

    private func attachPlayer() throws {
        guard let format, !engine.attachedNodes.contains(player) else { return }
        engine.attach(player)
        try engine.connectNode(player, to: engine.mainMixerNode, format: format)
    }

    private func startEngine() throws {
        try attachPlayer()
        if !engine.isRunning { try engine.start() }
    }

    /// Configures and activates the audio session once; tries again next time if it failed.
    private func activateSession() async throws {
        if let sessionActivation { return try await sessionActivation.value }
        let activation = Task { try await Self.configureSession() }
        sessionActivation = activation
        do {
            try await activation.value
        } catch {
            sessionActivation = nil
            throw error
        }
    }

    /// Runs off the main thread: audio session calls can block and hang the UI.
    @concurrent
    private nonisolated static func configureSession() async throws {
        // Ambient: short game sound that respects silent mode and mixes with other audio.
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient)
        try await session.activate()
    }

    private func buffer(for effect: Effect) async -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let pending = renderTask(for: effect)
        if effect == .rolling {
            // Prepare the next roll while this one plays, so it starts without delay.
            renders[.rolling] = nil
            _ = renderTask(for: .rolling)
        }
        let samples = await pending.value

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        _ = UnsafeMutableBufferPointer(start: channel, count: samples.count).update(fromContentsOf: samples)
        return buffer
    }

    /// The samples of the effect, rendered once off the main thread at low priority
    /// so the UI stays smooth. Awaiting the task raises its priority when needed.
    private func renderTask(for effect: Effect) -> Task<[Float], Never> {
        if let task = renders[effect] { return task }
        let task = Task.detached(priority: .utility) { Self.render(effect, sampleRate: Self.sampleRate) }
        renders[effect] = task
        return task
    }

    /// Renders the effect as mono samples, peaking at about 0.4 to 0.6 depending on the
    /// effect, well below clipping.
    nonisolated static func render(_ effect: Effect, sampleRate: Double) -> [Float] {
        switch effect {
        case .rolling:
            var generator = SystemRandomNumberGenerator()
            return renderRoll(sampleRate: sampleRate, using: &generator)
        case .criticalSuccess:
            return renderMelody(.fanfare, sampleRate: sampleRate)
        case .criticalFailure:
            return renderMelody(.sadTrombone, sampleRate: sampleRate)
        }
    }

    private nonisolated static func renderMelody(_ melody: Melody, sampleRate: Double) -> [Float] {
        var samples: [Float] = []
        samples.reserveCapacity(melody.notes.reduce(0) { $0 + Int($1.duration * sampleRate) })

        for note in melody.notes {
            var phases = [Double](repeating: 0, count: note.frequencies.count)
            let count = Int(note.duration * sampleRate)
            // Muted notes swell slowly; open brass attacks crisply.
            let attackTime = melody.isMuted ? 0.04 : 0.015

            for index in 0..<count {
                let time = Double(index) / sampleRate
                let progress = time / note.duration

                // Soft attack and release so each note is clearly articulated.
                let amplitude = min(time / attackTime, 1) * min((note.duration - time) / 0.08, 1)

                // Muted: the tone opens up then closes ("wah"). Open: bright, mellowing as it rings.
                let brightness = melody.isMuted
                    ? 0.2 + 0.65 * sin(.pi * progress)
                    : 0.8 - 0.3 * progress

                var pitch = 1.0
                if note.isHeld {
                    // Vibrato that grows in.
                    let depth = 0.015 * min(time / 0.3, 1)
                    pitch *= 1 + depth * sin(2 * .pi * 5.5 * time)
                    if melody.droops {
                        pitch *= 1 - 0.04 * progress * progress
                    }
                }

                var value = 0.0
                for (voice, frequency) in note.frequencies.enumerated() {
                    phases[voice] += 2 * .pi * frequency * pitch / sampleRate
                    if phases[voice] > 2 * .pi { phases[voice] -= 2 * .pi }
                    value += brass(phase: phases[voice], brightness: brightness)
                }
                // Square root keeps chords about as loud as single notes.
                value /= Double(note.frequencies.count).squareRoot()

                samples.append(Float(0.5 * amplitude * value))
            }
        }
        return samples
    }

    /// Renders a die tumbling on a wooden table for `rollingDuration`, as mono samples in
    /// `-0.45...0.45`: a few irregular bounces, then a quick rattle as it settles, over a soft rumble.
    nonisolated static func renderRoll<G: RandomNumberGenerator>(
        sampleRate: Double,
        using generator: inout G
    ) -> [Float] {
        var samples = [Double](repeating: 0, count: Int(rollingDuration * sampleRate))

        // When the die hits the table, and how hard.
        var hits: [(time: Double, strength: Double)] = []
        var time = 0.0
        var strength = 1.0
        while time < 0.9 {
            hits.append((time, strength))
            time += Double.random(in: 0.06...0.11, using: &generator)
            strength *= Double.random(in: 0.85...0.93, using: &generator)
        }
        for _ in 0..<3 {
            hits.append((time, strength))
            time += Double.random(in: 0.025...0.045, using: &generator)
            strength *= 0.6
        }

        let hitLength = Int(0.04 * sampleRate)

        for hit in hits {
            let start = Int(hit.time * sampleRate)
            // Each face and corner hits the table a bit differently.
            let pitch = Double.random(in: 0.85...1.15, using: &generator)
            // Wood is dull and heavily damped: low Q resonances that die out in a few
            // milliseconds, instead of the long, pure tones that sound like metal.
            var table = Resonator(frequency: 200 * pitch, q: 2.5, sampleRate: sampleRate)
            var die = Resonator(frequency: 900 * pitch, q: 4, sampleRate: sampleRate)
            var softened = 0.0

            for index in 0..<hitLength where start + index < samples.count {
                let t = Double(index) / sampleRate
                // The impact: a burst of noise lasting about a millisecond, with its
                // harshest highs smoothed out.
                let noise = Double.random(in: -1...1, using: &generator) * exp(-t / 0.001)
                softened += 0.5 * (noise - softened)

                let knock = 1.2 * table.process(softened) + 0.8 * die.process(softened) + 0.15 * softened
                samples[start + index] += hit.strength * knock
            }
        }

        // Bring the knocks to full scale so the rumble's level below is relative to them.
        let knockPeak = Self.peak(of: samples)
        if knockPeak > 0 {
            for index in samples.indices { samples[index] /= knockPeak }
        }

        // Rumble of the die rolling between hits: noise low-passed twice so it stays
        // a dull rumble rather than a hiss, fading out as the die stops.
        var smoothed = 0.0
        var rumble = 0.0
        for index in samples.indices {
            smoothed += 0.04 * (Double.random(in: -1...1, using: &generator) - smoothed)
            rumble += 0.04 * (smoothed - rumble)
            let fade = 1 - Double(index) / Double(samples.count)
            samples[index] += 1.5 * rumble * fade
        }

        let peak = Self.peak(of: samples)
        let gain = peak > 0 ? 0.45 / peak : 0
        return samples.map { Float($0 * gain) }
    }

    /// The largest absolute value, without building an intermediate array.
    private nonisolated static func peak(of samples: [Double]) -> Double {
        samples.reduce(0) { max($0, abs($1)) }
    }

    /// A band-pass filter that rings at `frequency` when excited. The higher `q`,
    /// the narrower the band and the longer it rings.
    private nonisolated struct Resonator {
        private let b0: Double
        private let a1: Double
        private let a2: Double
        private var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

        init(frequency: Double, q: Double, sampleRate: Double) {
            // Band-pass biquad with 0 dB peak gain (Audio EQ Cookbook).
            let omega = 2 * .pi * frequency / sampleRate
            let alpha = sin(omega) / (2 * q)
            let a0 = 1 + alpha
            b0 = alpha / a0
            a1 = -2 * cos(omega) / a0
            a2 = (1 - alpha) / a0
        }

        mutating func process(_ x: Double) -> Double {
            let y = b0 * x - b0 * x2 - a1 * y1 - a2 * y2
            x2 = x1
            x1 = x
            y2 = y1
            y1 = y
            return y
        }
    }

    /// Brass-like timbre: harmonics whose strength follows the brightness, normalized to `-1...1`.
    private nonisolated static func brass(phase: Double, brightness: Double) -> Double {
        var value = 0.0
        var total = 0.0
        var weight = 1.0
        for harmonic in 1...8 {
            value += weight * sin(Double(harmonic) * phase)
            total += weight
            weight *= brightness
        }
        return value / total
    }
}
