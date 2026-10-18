# Rollix

See README.md for what the app does, the project layout and how to run the tests.

## Conventions

- Put new files in the matching folder of `Rollix Watch App/` (`Models`, `Views`,
  `Services`, `Resources`). Groups are synchronized with the file system: no project
  file edits needed. Add the file to the README's "Project layout" table.
- Every user-facing string needs a French translation in `Localizable.xcstrings`.
- Declare new settings as a `Setting` in `SettingsView.swift` and read them with
  `@AppStorage(.name)`, so the default value lives in one place.
- New animations and effects must respect Reduce Motion, and new controls need
  sensible VoiceOver labels.
- Keep roll logic in `DiceRoller` (testable without UI) and cover it with Swift
  Testing; UI tests force English through launch arguments.
- When a change affects what the README describes (features, requirements, project
  layout, tests), update it in the same commit.
