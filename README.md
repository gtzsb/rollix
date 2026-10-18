# Rollix

A dice roller for Apple Watch, made for tabletop role-playing games. Rollix is a
learning playground: a small but complete app built to explore what watchOS offers,
from SwiftUI and the Digital Crown to motion sensors, haptics, sound synthesis,
accessibility and localization.

The name plays on three words: *roll*, as in rolling a die; *role*, as in
role-playing games; and Rolex, a nod to the watch it runs on.

## Features

- The seven classic polyhedral dice: d4, d6, d8, d10, d12, d20 and d100.
- Change die with the Digital Crown or by swiping up and down.
- Roll by tapping the die, double tapping (thumb and index finger) or shaking the wrist.
- Critical results stand out: green with confetti and a fanfare for the highest face,
  red with a sad trombone for a 1.
- Sounds are synthesized on the watch; every roll sounds a bit different.
- Settings: minimal or shaded dice, sounds and haptics, confetti, shake to roll.
- VoiceOver, Reduce Motion and French localization.
- The die dims on the Always On display when the wrist is down.

## Requirements

- Xcode 27 or later
- watchOS 27 or later (watch-only app)

## Project layout

Sources live in `Rollix Watch App/`, grouped by kind:

| File | Role |
| --- | --- |
| `App/RollixApp.swift` | App entry point |
| `Models/Die.swift` | The dice and their rules (rolls, critical results) |
| `Models/DiceRoller.swift` | Die selection and roll sequence, with its sounds, haptics and confetti |
| `Views/ContentView.swift` | Main screen: die display, gestures, motion sensors |
| `Views/DieView.swift` | Drawing of each die, minimal or shaded |
| `Views/ConfettiView.swift` | Confetti burst on critical successes |
| `Views/SettingsView.swift` | Settings screen and their stored defaults |
| `Services/SoundEffects.swift` | Synthesis and playback of the sound effects |
| `Services/ShakeDetector.swift` | Shake detection from the motion sensors |
| `Resources/` | Asset catalog, app icon and string catalogs |

## Tests

Run the `Rollix Watch App` scheme's tests in Xcode (⌘U), on a watchOS simulator.
Unit tests use Swift Testing; UI tests use XCUIAutomation.
