//
//  RollixUITests.swift
//  Rollix Watch AppUITests
//

import XCTest

final class RollixUITests: XCTestCase {

    private var app: XCUIApplication!

    @MainActor
    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // The assertions read English labels.
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        // Known settings whatever was saved on the simulator, and silent runs.
        // Arguments override the stored values without changing them.
        app.launchArguments += [
            "-soundAndHapticsEnabled", "NO",
            "-confettiEnabled", "NO",
            "-shakeToRollEnabled", "NO",
            "-dieAppearance", "minimal",
        ]
        app.launch()
    }

    @MainActor
    func testTappingTheDieRollsIt() throws {
        let die = app.buttons["die"]
        XCTAssertTrue(die.waitForExistence(timeout: 5))
        XCTAssertEqual(die.label, "d6")

        die.tap()

        // The value appears once the die has landed.
        let rolled = NSPredicate(format: "value MATCHES 'Rolled [1-6]'")
        expectation(for: rolled, evaluatedWith: die)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testSwipingChangesDie() throws {
        let die = app.buttons["die"]
        XCTAssertTrue(die.waitForExistence(timeout: 5))

        die.swipeUp()
        XCTAssertTrue(die.wait(for: \.label, toEqual: "d8", timeout: 5))

        die.swipeDown()
        XCTAssertTrue(die.wait(for: \.label, toEqual: "d6", timeout: 5))
        die.swipeDown()
        XCTAssertTrue(die.wait(for: \.label, toEqual: "d4", timeout: 5))
    }

    @MainActor
    func testSettingsOpenWithLaunchValues() throws {
        // SwiftUI exposes the toolbar button twice, nested.
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Dice Style"].waitForExistence(timeout: 5))

        // The launch arguments did reach the settings.
        let shakeToRoll = app.switches["Shake to Roll"].firstMatch
        XCTAssertTrue(shakeToRoll.waitForExistence(timeout: 5))
        XCTAssertEqual(shakeToRoll.value as? String, "0")
    }
}
