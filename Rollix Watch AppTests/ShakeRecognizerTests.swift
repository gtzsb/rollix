//
//  ShakeRecognizerTests.swift
//  Rollix Watch AppTests
//

import Testing
@testable import Rollix_Watch_App

struct ShakeRecognizerTests {

    @Test func ignoresSmallMovements() {
        var recognizer = ShakeRecognizer()
        let first = recognizer.process(x: 0.3, y: 0.5, z: 0.2, timestamp: 0)
        let second = recognizer.process(x: 1.0, y: 1.0, z: 0, timestamp: 0.1)
        #expect(!first)
        #expect(!second)
    }

    @Test func detectsStrongShake() {
        var recognizer = ShakeRecognizer()
        let detected = recognizer.process(x: 2.5, y: 0, z: 0, timestamp: 0)
        #expect(detected)
    }

    @Test func combinesAxes() {
        var recognizer = ShakeRecognizer()
        // sqrt(1.5² + 1.5²) ≈ 2.12 g, above the 2 g threshold.
        let detected = recognizer.process(x: 1.5, y: -1.5, z: 0, timestamp: 0)
        #expect(detected)
    }

    @Test func respectsCooldown() {
        var recognizer = ShakeRecognizer()
        let first = recognizer.process(x: 3, y: 0, z: 0, timestamp: 10)
        let tooSoon = recognizer.process(x: 3, y: 0, z: 0, timestamp: 10.5)
        let afterCooldown = recognizer.process(x: 3, y: 0, z: 0, timestamp: 11.1)
        #expect(first)
        #expect(!tooSoon)
        #expect(afterCooldown)
    }
}
