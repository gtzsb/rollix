//
//  DieTests.swift
//  Rollix Watch AppTests
//

import Testing
@testable import Rollix_Watch_App

struct DieTests {

    @Test(arguments: Die.allCases)
    func rollStaysWithinFaces(die: Die) {
        for _ in 0..<1_000 {
            #expect((1...die.sides).contains(die.roll()))
        }
    }

    @Test(arguments: [Die.d4, .d6, .d8])
    func rollEventuallyHitsEveryFace(die: Die) {
        var seen = Set<Int>()
        for _ in 0..<10_000 where seen.count < die.sides {
            seen.insert(die.roll())
        }
        #expect(seen == Set(1...die.sides))
    }

    @Test func detectsCriticalResults() {
        #expect(Die.d20.isCriticalSuccess(20))
        #expect(!Die.d20.isCriticalSuccess(19))
        #expect(Die.d20.isCriticalFailure(1))
        #expect(!Die.d20.isCriticalFailure(2))
    }

    @Test func namesUseDiceNotation() {
        #expect(Die.d6.name == "d6")
        #expect(Die.d100.name == "d100")
    }

    @Test func neighborsFollowFaceCount() {
        #expect(Die.d6.next == .d8)
        #expect(Die.d6.previous == .d4)
        #expect(Die.d20.next == .d100)
    }

    @Test func neighborsStopAtEnds() {
        #expect(Die.d4.previous == nil)
        #expect(Die.d100.next == nil)
    }
}
