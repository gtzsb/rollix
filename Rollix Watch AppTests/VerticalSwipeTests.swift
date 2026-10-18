//
//  VerticalSwipeTests.swift
//  Rollix Watch AppTests
//

import CoreGraphics
import Testing
@testable import Rollix_Watch_App

struct VerticalSwipeTests {

    @Test func detectsUpAndDown() {
        #expect(VerticalSwipe(translation: CGSize(width: 0, height: -50)) == .up)
        #expect(VerticalSwipe(translation: CGSize(width: 5, height: 50)) == .down)
    }

    @Test func ignoresShortMovements() {
        #expect(VerticalSwipe(translation: CGSize(width: 0, height: -20)) == nil)
    }

    @Test func ignoresMostlyHorizontalMovements() {
        #expect(VerticalSwipe(translation: CGSize(width: 60, height: 40)) == nil)
    }
}
