//
//  SettingsView.swift
//  Rollix Watch App
//

import SwiftUI

/// A user setting stored in UserDefaults: its key and the value used until the user
/// changes it. Declared once so every view reading a setting agrees on its default.
nonisolated struct Setting<Value> {
    let key: String
    let defaultValue: Value
}

nonisolated extension Setting<Bool> {
    /// A single option because watchOS pairs every haptic with an audible tone:
    /// haptics can't be played silently.
    static var soundAndHapticsEnabled: Self { Setting(key: "soundAndHapticsEnabled", defaultValue: true) }
    static var confettiEnabled: Self { Setting(key: "confettiEnabled", defaultValue: true) }
    static var shakeToRollEnabled: Self { Setting(key: "shakeToRollEnabled", defaultValue: true) }
}

nonisolated extension Setting<DieAppearance> {
    static var dieAppearance: Self { Setting(key: "dieAppearance", defaultValue: .minimal) }
}

extension AppStorage {
    init(_ setting: Setting<Value>) where Value == Bool {
        self.init(wrappedValue: setting.defaultValue, setting.key)
    }

    init(_ setting: Setting<Value>) where Value: RawRepresentable, Value.RawValue == String {
        self.init(wrappedValue: setting.defaultValue, setting.key)
    }
}

struct SettingsView: View {
    @AppStorage(.soundAndHapticsEnabled) private var soundAndHapticsEnabled: Bool
    @AppStorage(.confettiEnabled) private var confettiEnabled: Bool
    @AppStorage(.shakeToRollEnabled) private var shakeToRollEnabled: Bool
    @AppStorage(.dieAppearance) private var dieAppearance: DieAppearance

    var body: some View {
        List {
            Picker("Dice Style", selection: $dieAppearance) {
                ForEach(DieAppearance.allCases) { appearance in
                    Text(appearance.name)
                }
            }
            Toggle("Sounds & Haptics", isOn: $soundAndHapticsEnabled)
            Toggle("Confetti", isOn: $confettiEnabled)
            Toggle("Shake to Roll", isOn: $shakeToRollEnabled)
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
}
