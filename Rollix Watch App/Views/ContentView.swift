//
//  ContentView.swift
//  Rollix Watch App
//

import SwiftUI

struct ContentView: View {
    @State private var roller = DiceRoller()
    @State private var shakeDetector = ShakeDetector()
    @State private var isShowingSettings = false
    @AppStorage(.soundAndHapticsEnabled) private var soundAndHapticsEnabled: Bool
    @AppStorage(.confettiEnabled) private var confettiEnabled: Bool
    @AppStorage(.shakeToRollEnabled) private var shakeToRollEnabled: Bool
    @AppStorage(.dieAppearance) private var dieAppearance: DieAppearance
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// True on the Always On display, while the wrist is down.
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        NavigationStack {
            dieButton
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Settings", systemImage: "gearshape") {
                            isShowingSettings = true
                        }
                    }
                }
                .sheet(isPresented: $isShowingSettings) {
                    NavigationStack {
                        SettingsView()
                    }
                }
        }
        .task(id: soundAndHapticsEnabled) {
            // Only set up audio when sounds are on.
            if soundAndHapticsEnabled { await roller.prepareFeedback() }
        }
        .onChange(of: rollSettings, initial: true) { roller.settings = rollSettings }
        .onChange(of: scenePhase, initial: true) { updateShakeDetection() }
        .onChange(of: shakeToRollEnabled) { updateShakeDetection() }
        .onChange(of: isShowingSettings) { updateShakeDetection() }
    }

    private var rollSettings: DiceRoller.Settings {
        DiceRoller.Settings(
            soundAndHapticsEnabled: soundAndHapticsEnabled,
            confettiEnabled: confettiEnabled,
            reduceMotion: reduceMotion
        )
    }

    private var dieButton: some View {
        // Shows the name of the die until it is rolled.
        Button { roller.roll() } label: {
            DieView(die: roller.die, value: roller.displayedValue, color: dieColor, appearance: dieAppearance)
                .rotationEffect(.degrees(roller.turns * 360))
                .scaleEffect(roller.isRolling && !reduceMotion ? 0.9 : 1)
                // A new die is a new view: it doesn't carry on the spin of the previous one.
                .id(roller.die)
        }
        .buttonStyle(.plain)
        // Double tap (thumb + index finger) rolls the die too.
        .handGestureShortcut(.primaryAction)
        .accessibilityLabel(Text(verbatim: roller.die.name))
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Rolls the \(roller.die.name)")
        .accessibilityIdentifier("die")
        // VoiceOver users swipe up or down to change die.
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: roller.select(roller.die.next)
            case .decrement: roller.select(roller.die.previous)
            @unknown default: break
            }
        }
        // Height is what limits the die, so it only gets side margins.
        .padding(.horizontal)
        // Fill the screen so the confetti covers all of it, not just the content.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Next to the Digital Crown, hints that the die can be changed by
        // swiping or turning the crown, and shows where it sits in the list.
        .overlay(alignment: .trailing) {
            DiePositionIndicator(selected: roller.die)
        }
        // The whole screen accepts swipes, not just the die.
        .contentShape(.rect)
        // Swiping up or down changes die, like the Digital Crown. High priority so a
        // swipe doesn't also roll when the finger lifts; taps shorter than the
        // minimum distance still reach the button.
        .highPriorityGesture(
            DragGesture(minimumDistance: VerticalSwipe.minimumDistance)
                .onEnded { value in
                    switch VerticalSwipe(translation: value.translation) {
                    case .up: roller.select(roller.die.next)
                    case .down: roller.select(roller.die.previous)
                    case nil: break
                    }
                }
        )
        // Sets up canvas drawing at launch rather than on the first confetti burst.
        .background(alignment: .topLeading) {
            CanvasWarmUp()
        }
        .overlay {
            if let confettiBurst = roller.confettiBurst {
                ConfettiView()
                    .id(confettiBurst)
                    .ignoresSafeArea()
                    // Bright, fast confetti doesn't belong on the dimmed Always On
                    // display. Hidden rather than removed, so the burst carries on
                    // where it would be when the wrist comes back up.
                    .opacity(isLuminanceReduced ? 0 : 1)
            }
        }
        .focusable()
        // The crown's detent haptics stay on whatever the settings, like in system apps.
        .digitalCrownRotation(
            $roller.crownValue,
            from: 0,
            through: Double(Die.allCases.count - 1),
            by: 1,
            sensitivity: .low,
            isContinuous: false
        )
    }

    /// Only listens to the motion sensors while shaking can roll: the option is on,
    /// the app is on screen and the settings don't cover the die.
    private func updateShakeDetection() {
        if shakeToRollEnabled, scenePhase == .active, !isShowingSettings {
            shakeDetector.start { roller.roll() }
        } else {
            shakeDetector.stop()
        }
    }

    /// Darker on the Always On display, which asks for less light; the value stays
    /// white so it remains readable.
    private var dieColor: Color {
        isLuminanceReduced ? resultColor.mix(with: .black, by: 0.6) : resultColor
    }

    private var resultColor: Color {
        let die = roller.die
        guard let result = roller.result else { return die.color }
        if die.isCriticalSuccess(result) { return .green }
        if die.isCriticalFailure(result) { return .red }
        return die.color
    }

    private var accessibilityValue: Text {
        guard let result = roller.result else { return Text(verbatim: "") }
        return Text("Rolled \(result)")
    }
}

/// A swipe that is clearly vertical, used to change die.
nonisolated enum VerticalSwipe {
    case up
    case down

    /// Distance, in points, a finger must travel before it's a swipe rather than a tap.
    static let minimumDistance: CGFloat = 30

    /// Returns `nil` when the movement is too short or mostly horizontal.
    init?(translation: CGSize) {
        let vertical = abs(translation.height)
        guard vertical >= Self.minimumDistance, vertical > abs(translation.width) * 2 else { return nil }
        self = translation.height < 0 ? .up : .down
    }
}

/// A column of dots, one per die, like the indicator of vertical pages:
/// the first die at the top, the selected one highlighted in its color.
struct DiePositionIndicator: View {
    let selected: Die

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Die.allCases) { die in
                Circle()
                    .fill(die == selected ? AnyShapeStyle(die.color) : AnyShapeStyle(.secondary))
                    .frame(width: 5, height: 5)
            }
        }
        .animation(.snappy(duration: 0.2), value: selected)
        // VoiceOver already announces the die on the button.
        .accessibilityHidden(true)
        // Purely informative: swipes and taps go through to the die.
        .allowsHitTesting(false)
    }
}

#Preview {
    ContentView()
}
