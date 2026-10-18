//
//  ShakeDetector.swift
//  Rollix Watch App
//

import CoreMotion
import Foundation

/// Decides whether a stream of acceleration samples contains a shake.
///
/// Kept free of Core Motion so the detection logic can be unit tested.
nonisolated struct ShakeRecognizer {
    /// Minimum user acceleration (gravity removed), in g, that counts as a shake.
    var threshold: Double = 2.0
    /// Minimum delay between two shakes, so one gesture doesn't roll several times.
    var cooldown: TimeInterval = 1.0

    private var lastShake: TimeInterval?

    /// Feeds one sample and returns `true` if it completes a shake.
    mutating func process(x: Double, y: Double, z: Double, timestamp: TimeInterval) -> Bool {
        let magnitude = (x * x + y * y + z * z).squareRoot()
        guard magnitude >= threshold else { return false }
        if let lastShake, timestamp - lastShake < cooldown { return false }
        lastShake = timestamp
        return true
    }
}

/// Listens to the watch's motion sensors and reports wrist shakes.
@MainActor
final class ShakeDetector {
    private let motionManager = CMMotionManager()
    private var recognizer = ShakeRecognizer()

    func start(onShake: @escaping @MainActor () -> Void) {
        guard motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0
        // Updates are delivered on the main queue, which is fine at 50 Hz
        // and lets us touch main-actor state directly.
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                let acceleration = motion.userAcceleration
                if self.recognizer.process(
                    x: acceleration.x,
                    y: acceleration.y,
                    z: acceleration.z,
                    timestamp: motion.timestamp
                ) {
                    onShake()
                }
            }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}
