//
//  ConfettiView.swift
//  Rollix Watch App
//

import SwiftUI

/// Confetti raining down over the whole view, swaying as it falls.
/// Recreate the view (e.g. with `.id`) to start a new burst.
struct ConfettiView: View {
    /// How long the burst lasts, in seconds.
    static let duration = 2.8

    private struct Piece {
        /// Horizontal start position, as a fraction of the width.
        let x: Double
        /// When the piece starts falling, so the pieces don't all arrive at once.
        let delay: Double
        let fallSpeed: Double
        let swayAmplitude: Double
        let swaySpeed: Double
        let swayPhase: Double
        let color: Color
        let size: CGSize
        let spinSpeed: Double
        let flipSpeed: Double
    }

    private static let colors: [Color] = [.red, .orange, .yellow, .green, .mint, .blue, .purple, .pink]

    @State private var start = Date.now
    @State private var pieces: [Piece] = (0..<100).map { _ in
        Piece(
            x: .random(in: 0...1),
            delay: .random(in: 0...1.3),
            fallSpeed: .random(in: 140...230),
            swayAmplitude: .random(in: 4...14),
            swaySpeed: .random(in: 3...7),
            swayPhase: .random(in: 0...(2 * .pi)),
            color: ConfettiView.colors.randomElement() ?? .yellow,
            size: CGSize(width: .random(in: 3...5), height: .random(in: 6...9)),
            spinSpeed: .random(in: -8...8),
            flipSpeed: .random(in: 4...12)
        )
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSince(start)
                guard time < Self.duration else { return }
                // Fade out over the last part of the burst.
                context.opacity = min(1, (Self.duration - time) / 0.5)

                for piece in pieces {
                    let fallTime = time - piece.delay
                    guard fallTime > 0 else { continue }

                    // Start just above the top edge and drift side to side on the way down.
                    let x = piece.x * size.width
                        + piece.swayAmplitude * sin(piece.swaySpeed * fallTime + piece.swayPhase)
                    let y = -10 + piece.fallSpeed * fallTime
                    guard y < size.height + 10 else { continue }

                    var pieceContext = context
                    pieceContext.translateBy(x: x, y: y)
                    pieceContext.rotate(by: .radians(piece.spinSpeed * fallTime))
                    // Squashing one axis makes the piece look like it flips in 3D.
                    pieceContext.scaleBy(x: cos(piece.flipSpeed * fallTime), y: 1)
                    let rect = CGRect(
                        x: -piece.size.width / 2,
                        y: -piece.size.height / 2,
                        width: piece.size.width,
                        height: piece.size.height
                    )
                    pieceContext.fill(Path(rect), with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A practically invisible one-point canvas. The first canvas on screen makes SwiftUI
/// set up its drawing engine on the main thread, which freezes the watch for a moment:
/// showing this one at launch keeps that pause away from the first confetti burst.
struct CanvasWarmUp: View {
    var body: some View {
        Canvas { context, _ in
            context.fill(Path(CGRect(x: 0, y: 0, width: 1, height: 1)), with: .color(.white))
        }
        .frame(width: 1, height: 1)
        // Fully transparent views may be skipped, so it stays barely visible.
        .opacity(0.01)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    ConfettiView()
}
