//
//  DiceRoller.swift
//  Rollix Watch App
//

import SwiftUI
import WatchKit

/// What goes with a roll besides the picture: sound effects and haptics.
/// Abstracted so the roll sequence can be tested without a speaker.
protocol RollFeedback: AnyObject {
    /// Gets the sounds ready, so the first roll doesn't wait for them.
    func prepare() async
    func play(_ effect: SoundEffects.Effect, startingBy deadline: ContinuousClock.Instant?) async
    func stopSounds()
    func playHaptic(_ type: WKHapticType)
}

/// The watch's speaker and Taptic Engine.
final class DeviceFeedback: RollFeedback {
    private let soundEffects = SoundEffects()

    func prepare() async {
        await soundEffects.prepare()
    }

    func play(_ effect: SoundEffects.Effect, startingBy deadline: ContinuousClock.Instant?) async {
        await soundEffects.play(effect, startingBy: deadline)
    }

    func stopSounds() {
        soundEffects.stop()
    }

    func playHaptic(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}

/// The selected die and the roll sequence: faces changing while the die spins, the
/// result, and the sounds, haptics and confetti that go with it.
@Observable
final class DiceRoller {
    /// The settings that change how a roll plays out.
    nonisolated struct Settings: Equatable {
        /// watchOS pairs every haptic with an audible tone (`.stop` is a "ding ding"),
        /// so haptics follow the sound option.
        var soundAndHapticsEnabled = Setting.soundAndHapticsEnabled.defaultValue
        var confettiEnabled = Setting.confettiEnabled.defaultValue
        /// The die stays still, only its faces change, and there is no confetti.
        /// Follows the system setting, so it isn't a `Setting`.
        var reduceMotion = false
    }

    /// Position of the Digital Crown, mapped to an index in `Die.allCases`.
    var crownValue = Double(Die.allCases.firstIndex(of: .d6) ?? 0) {
        didSet {
            // Changing die invalidates the previous result.
            if Self.die(at: oldValue) != die { reset() }
        }
    }

    var settings = Settings() {
        didSet {
            if !settings.soundAndHapticsEnabled { feedback.stopSounds() }
            if !settings.confettiEnabled || settings.reduceMotion { hideConfetti() }
        }
    }

    /// The value the die landed on; `nil` before the first roll and while rolling.
    private(set) var result: Int?
    /// The value on the die's front face, changing while it rolls; `nil` before the first roll.
    private(set) var displayedValue: Int?
    private(set) var isRolling = false
    /// Total turns of the die, only ever increasing so it never spins backwards.
    private(set) var turns: Double = 0
    /// Identifies the current confetti burst; `nil` when none is showing.
    private(set) var confettiBurst: UUID?

    @ObservationIgnored private var rollTask: Task<Void, Never>?
    @ObservationIgnored private var confettiTask: Task<Void, Never>?

    private let feedback: any RollFeedback
    private let rollDuration: Double
    private let confettiDuration: Double
    private let rollValue: (Die) -> Int

    /// - Parameters:
    ///   - rollDuration: How long the die spins, in seconds. Matches the rolling sound.
    ///   - confettiDuration: How long confetti stays on screen, in seconds.
    ///   - rollValue: Picks the value a die lands on.
    init(
        feedback: any RollFeedback = DeviceFeedback(),
        rollDuration: Double = SoundEffects.rollingDuration,
        confettiDuration: Double = ConfettiView.duration,
        rollValue: @escaping (Die) -> Int = { $0.roll() }
    ) {
        self.feedback = feedback
        self.rollDuration = rollDuration
        self.confettiDuration = confettiDuration
        self.rollValue = rollValue
    }

    var die: Die { Self.die(at: crownValue) }

    private static func die(at crownValue: Double) -> Die {
        let index = Int(crownValue.rounded())
        return Die.allCases[min(max(index, 0), Die.allCases.count - 1)]
    }

    /// Switches to `newDie` by moving the crown position, so the Digital Crown keeps
    /// going from there. Does nothing past the first or last die.
    func select(_ newDie: Die?) {
        guard let newDie, let index = Die.allCases.firstIndex(of: newDie) else { return }
        crownValue = Double(index)
        // The crown has its own detents; other ways of changing die need a tick too.
        playHaptic(.click)
    }

    func prepareFeedback() async {
        await feedback.prepare()
    }

    /// Rolls the selected die. Ignored while the die is spinning, like a real die
    /// that can't be thrown again before it lands; a roll whose die has landed but
    /// whose sounds are still playing is cut short.
    /// - Returns: The roll sequence, done once the die has landed and its sounds are played.
    @discardableResult
    func roll() -> Task<Void, Never> {
        if isRolling, let rollTask { return rollTask }
        rollTask?.cancel()
        feedback.stopSounds()
        hideConfetti()
        // Set before the sequence starts, so a second tap in the meantime is ignored.
        withAnimation(.snappy(duration: 0.2)) {
            isRolling = true
            result = nil
        }
        let die = die
        let finalValue = rollValue(die)
        let task = Task { await rollSequence(die: die, finalValue: finalValue) }
        rollTask = task
        return task
    }

    private func rollSequence(die: Die, finalValue: Int) async {
        // The die may have changed before the sequence got to start.
        if Task.isCancelled { return }

        // Two turns matching the length of the rolling sound, slowing down like
        // a die losing momentum (quadratic ease-out).
        let start = ContinuousClock.now
        if !settings.reduceMotion {
            withAnimation(.timingCurve(0.5, 1, 0.89, 1, duration: rollDuration)) { turns += 2 }
        }

        // Faces change instantly, without a transition, like a real die tumbling.
        var face = die.roll()
        displayedValue = face
        // Not awaited before the faces: on the first rolls the sound may still be
        // rendering. It is skipped if it can't start in time to match the spin.
        async let rollingSound: Void = playSound(.rolling, startingBy: start + .milliseconds(150))

        // A new face every sixth of a turn, so faces change quickly while the die
        // spins fast and slow down with it. The last one is the result, shown
        // while the die finishes its spin.
        let steps = 12
        for step in 1..<steps {
            // When the spin reaches this step: the inverse of the ease-out curve.
            let progress = 1 - (1 - Double(step) / Double(steps)).squareRoot()
            try? await Task.sleep(until: start + .seconds(rollDuration * progress))
            if Task.isCancelled { return }
            if step == steps - 1 {
                face = finalValue
            } else {
                // Never show the same face twice in a row, or it looks stuck.
                let next = Int.random(in: 1..<die.sides)
                face = next >= face ? next + 1 : next
            }
            displayedValue = face
            playHaptic(.click)
        }

        try? await Task.sleep(until: start + .seconds(rollDuration))
        if Task.isCancelled { return }

        // The die lands with a little bounce, or settles without one with Reduce Motion.
        withAnimation(settings.reduceMotion ? .easeOut(duration: 0.2) : .bouncy(duration: 0.4, extraBounce: 0.15)) {
            result = finalValue
            isRolling = false
        }

        if die.isCriticalSuccess(finalValue) {
            if settings.confettiEnabled, !settings.reduceMotion { showConfetti() }
            await playSound(.criticalSuccess)
        } else if die.isCriticalFailure(finalValue) {
            await playSound(.criticalFailure)
        } else {
            playHaptic(.stop)
        }
        await rollingSound
    }

    /// Stops the roll in progress and forgets the result.
    private func reset() {
        rollTask?.cancel()
        feedback.stopSounds()
        hideConfetti()
        isRolling = false
        result = nil
        displayedValue = nil
    }

    private func showConfetti() {
        confettiBurst = UUID()
        confettiTask = Task {
            try? await Task.sleep(for: .seconds(confettiDuration))
            if !Task.isCancelled { confettiBurst = nil }
        }
    }

    private func hideConfetti() {
        confettiTask?.cancel()
        confettiBurst = nil
    }

    private func playSound(_ effect: SoundEffects.Effect, startingBy deadline: ContinuousClock.Instant? = nil) async {
        guard settings.soundAndHapticsEnabled else { return }
        await feedback.play(effect, startingBy: deadline)
    }

    private func playHaptic(_ type: WKHapticType) {
        guard settings.soundAndHapticsEnabled else { return }
        feedback.playHaptic(type)
    }
}
