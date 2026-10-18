//
//  DiceRollerTests.swift
//  Rollix Watch AppTests
//

import Testing
import WatchKit
@testable import Rollix_Watch_App

/// Records what the roller plays instead of playing it.
@MainActor
final class RecordingFeedback: RollFeedback {
    private(set) var sounds: [SoundEffects.Effect] = []
    private(set) var haptics: [WKHapticType] = []
    private(set) var stopCount = 0

    func prepare() async {}

    func play(_ effect: SoundEffects.Effect, startingBy deadline: ContinuousClock.Instant?) async {
        sounds.append(effect)
    }

    func stopSounds() {
        stopCount += 1
    }

    func playHaptic(_ type: WKHapticType) {
        haptics.append(type)
    }
}

@MainActor
struct DiceRollerTests {
    let feedback = RecordingFeedback()

    /// A roller whose die always lands on `value`, spinning for a few milliseconds.
    func makeRoller(landingOn value: Int, confettiDuration: Double = 60) -> DiceRoller {
        DiceRoller(feedback: feedback, rollDuration: 0.02, confettiDuration: confettiDuration) { _ in value }
    }

    @Test func startsOnD6WithoutResult() {
        let roller = makeRoller(landingOn: 3)
        #expect(roller.die == .d6)
        #expect(roller.result == nil)
        #expect(roller.displayedValue == nil)
    }

    @Test func rollLandsOnTheValue() async {
        let roller = makeRoller(landingOn: 3)
        await roller.roll().value
        #expect(roller.result == 3)
        #expect(roller.displayedValue == 3)
        #expect(!roller.isRolling)
        #expect(roller.turns == 2)
        #expect(roller.confettiBurst == nil)
        // A click for each new face, then the landing.
        #expect(feedback.haptics == Array(repeating: .click, count: 11) + [.stop])
        #expect(feedback.sounds == [.rolling])
    }

    @Test func criticalSuccessShowsConfettiAndPlaysFanfare() async {
        let roller = makeRoller(landingOn: 6)
        await roller.roll().value
        #expect(roller.confettiBurst != nil)
        #expect(feedback.sounds == [.rolling, .criticalSuccess])
        #expect(!feedback.haptics.contains(.stop))
    }

    @Test func criticalFailurePlaysSadTrombone() async {
        let roller = makeRoller(landingOn: 1)
        await roller.roll().value
        #expect(roller.confettiBurst == nil)
        #expect(feedback.sounds == [.rolling, .criticalFailure])
    }

    @Test func confettiGoesAwayAfterItsDuration() async throws {
        let roller = makeRoller(landingOn: 6, confettiDuration: 0.05)
        await roller.roll().value
        #expect(roller.confettiBurst != nil)
        try await Task.sleep(for: .milliseconds(300))
        #expect(roller.confettiBurst == nil)
    }

    @Test func turningConfettiOffHidesIt() async {
        let roller = makeRoller(landingOn: 6)
        await roller.roll().value
        roller.settings.confettiEnabled = false
        #expect(roller.confettiBurst == nil)
    }

    @Test func reduceMotionHidesConfetti() async {
        let roller = makeRoller(landingOn: 6)
        await roller.roll().value
        roller.settings.reduceMotion = true
        #expect(roller.confettiBurst == nil)
    }

    @Test func staysQuietWithSoundsAndConfettiOff() async {
        let roller = makeRoller(landingOn: 6)
        roller.settings = DiceRoller.Settings(soundAndHapticsEnabled: false, confettiEnabled: false)
        await roller.roll().value
        #expect(roller.result == 6)
        #expect(roller.confettiBurst == nil)
        #expect(feedback.sounds.isEmpty)
        #expect(feedback.haptics.isEmpty)
    }

    @Test func reduceMotionKeepsTheDieStill() async {
        let roller = makeRoller(landingOn: 6)
        roller.settings.reduceMotion = true
        await roller.roll().value
        #expect(roller.result == 6)
        #expect(roller.turns == 0)
        #expect(roller.confettiBurst == nil)
    }

    @Test func rollIsIgnoredWhileTheDieSpins() async {
        var rolls = 0
        let roller = DiceRoller(feedback: feedback, rollDuration: 0.02) { _ in
            rolls += 1
            return 3
        }
        let first = roller.roll()
        let second = roller.roll()
        #expect(second == first)
        await first.value
        #expect(rolls == 1)
        #expect(roller.turns == 2)
        #expect(feedback.haptics.filter { $0 == .stop }.count == 1)
    }

    @Test func dieCanBeRolledAgainOnceLanded() async {
        let roller = makeRoller(landingOn: 3)
        await roller.roll().value
        await roller.roll().value
        #expect(roller.turns == 4)
        #expect(feedback.haptics.filter { $0 == .stop }.count == 2)
    }

    @Test func changingDieForgetsTheResult() async {
        let roller = makeRoller(landingOn: 3)
        await roller.roll().value
        roller.select(.d8)
        #expect(roller.die == .d8)
        #expect(roller.result == nil)
        #expect(roller.displayedValue == nil)
        #expect(feedback.haptics.last == .click)
    }

    @Test func changingDieWhileRollingStopsTheRoll() async {
        // Long enough that the die can't land before the change.
        let roller = DiceRoller(feedback: feedback, rollDuration: 60) { _ in 6 }
        let roll = roller.roll()
        // Wait for the roll to show its first face.
        while roller.displayedValue == nil { await Task.yield() }
        roller.select(.d8)
        await roll.value
        #expect(!roller.isRolling)
        #expect(roller.result == nil)
        #expect(roller.displayedValue == nil)
        #expect(roller.confettiBurst == nil)
        #expect(!feedback.haptics.contains(.stop))
        #expect(!feedback.sounds.contains(.criticalSuccess))
    }

    @Test func changingDieRightAfterRollingCancelsTheWholeRoll() async {
        let roller = makeRoller(landingOn: 3)
        // Before the roll sequence has had a chance to start.
        let roll = roller.roll()
        roller.select(.d8)
        await roll.value
        #expect(roller.displayedValue == nil)
        #expect(roller.turns == 0)
        #expect(feedback.sounds.isEmpty)
        // Only the tick of the die change.
        #expect(feedback.haptics == [.click])
    }

    @Test func turningSoundsOffWhileRollingSilencesTheRoll() async {
        // The first new face comes about 20 ms in, leaving time to turn sounds off.
        let roller = DiceRoller(feedback: feedback, rollDuration: 0.5) { _ in 3 }
        let roll = roller.roll()
        while roller.displayedValue == nil { await Task.yield() }
        let stopsBefore = feedback.stopCount
        roller.settings.soundAndHapticsEnabled = false
        #expect(feedback.stopCount == stopsBefore + 1)
        await roll.value
        #expect(roller.result == 3)
        #expect(feedback.haptics.isEmpty)
    }

    @Test func selectionStopsAtTheEnds() {
        let roller = makeRoller(landingOn: 1)
        roller.select(.d4)
        roller.select(roller.die.previous)
        #expect(roller.die == .d4)
        // Only the move to the d4 ticked.
        #expect(feedback.haptics == [.click])
    }

    @Test func crownBetweenDetentsPicksTheNearestDie() {
        let roller = makeRoller(landingOn: 1)
        roller.crownValue = 2.4
        #expect(roller.die == .d8)
        roller.crownValue = 99
        #expect(roller.die == .d100)
    }
}
