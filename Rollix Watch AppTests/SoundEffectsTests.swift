//
//  SoundEffectsTests.swift
//  Rollix Watch AppTests
//

import Testing
@testable import Rollix_Watch_App

struct SoundEffectsTests {

    @Test func rollingSoundLastsAsLongAsTheRoll() {
        let sampleRate = SoundEffects.sampleRate
        var generator = SystemRandomNumberGenerator()
        let samples = SoundEffects.renderRoll(sampleRate: sampleRate, using: &generator)
        #expect(samples.count == Int(SoundEffects.rollingDuration * sampleRate))
        #expect(samples.allSatisfy { abs($0) <= 0.45 + 1e-6 })
        #expect(samples.contains { $0 != 0 })
    }

    @Test(arguments: [SoundEffects.Effect.criticalSuccess, .criticalFailure])
    func jinglesDoNotClip(effect: SoundEffects.Effect) {
        let samples = SoundEffects.render(effect, sampleRate: SoundEffects.sampleRate)
        #expect(!samples.isEmpty)
        #expect(samples.allSatisfy { abs($0) < 1 })
    }
}
