//
//  DieView.swift
//  Rollix Watch App
//

import SwiftUI

/// How dice are drawn, chosen in the settings.
nonisolated enum DieAppearance: String, CaseIterable, Identifiable {
    /// A flat silhouette with a large value.
    case minimal
    /// Shaded facets giving the die some volume.
    case shaded

    var id: Self { self }

    var name: LocalizedStringResource {
        switch self {
        case .minimal: "Minimal"
        case .shaded: "Shaded"
        }
    }
}

/// A stylized, face-on drawing of a die, shaped after its polyhedron,
/// with the rolled value on its front face.
struct DieView: View {
    let die: Die
    /// The value shown on the front face; `nil` before the first roll,
    /// in which case the face shows the name of the die.
    let value: Int?
    let color: Color
    var appearance: DieAppearance = .minimal

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let geometry = DieGeometry(die: die, appearance: appearance)

            ZStack {
                ZStack {
                    // Fills the anti-aliasing seams between facets.
                    PolygonShape(points: geometry.outline)
                        .fill(color)

                    if appearance == .shaded {
                        ForEach(geometry.facets.indices, id: \.self) { index in
                            let facet = geometry.facets[index]
                            PolygonShape(points: facet.points)
                                .fill(shade(facet, in: geometry).gradient)
                        }

                        // Faint highlight along the edges between facets.
                        ForEach(geometry.facets.indices, id: \.self) { index in
                            PolygonShape(points: geometry.facets[index].points)
                                .stroke(.white.opacity(0.15), style: StrokeStyle(lineWidth: max(0.5, side * 0.006), lineJoin: .round))
                        }
                    }
                }
                // Softens the silhouette corners.
                .clipShape(RoundedPolygonShape(points: geometry.outline, cornerRadius: geometry.cornerRadius))

                Text(value.map { "\($0)" } ?? die.name)
                    .font(.system(size: side * geometry.fontScale, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                    .frame(width: side * geometry.labelWidth)
                    .position(x: side * geometry.labelCenter.x, y: side * geometry.labelCenter.y)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// The die color lightened or darkened depending on how much the facet faces the light.
    private func shade(_ facet: DieGeometry.Facet, in geometry: DieGeometry) -> Color {
        let lighting = geometry.lighting(of: facet)
        return lighting >= 0
            ? color.mix(with: .white, by: 0.35 * lighting)
            : color.mix(with: .black, by: 0.45 * -lighting)
    }
}

extension Die {
    /// Each die has its own color; green and red are kept for critical results.
    var color: Color {
        switch self {
        case .d4: .orange
        case .d6: .blue
        case .d8: .purple
        case .d10: .teal
        case .d12: .pink
        case .d20: .indigo
        case .d100: .brown
        }
    }
}

/// The geometry of a die drawing, in unit coordinates (0...1 on both axes).
private struct DieGeometry {
    struct Facet {
        var points: [CGPoint]
        var isFront = false
    }

    /// The silhouette of the die, clockwise.
    var outline: [CGPoint] = []
    /// The front face followed by the visible side facets.
    var facets: [Facet] = []
    /// Radius of the silhouette corners, relative to the die size.
    var cornerRadius: CGFloat = 0.04
    // Where the value sits and how big it is. Each die sets them to fit its front
    // face; the minimal appearance, which has no front face, replaces them.
    var labelCenter = CGPoint(x: 0.5, y: 0.5)
    var labelWidth: CGFloat = 0.4
    var fontScale: CGFloat = 0.3

    init(die: Die, appearance: DieAppearance) {
        switch die {
        case .d4:
            // Tetrahedron: a triangle with a smaller front face, centered on its centroid.
            let centroid = CGPoint(x: 0.5, y: 0.574)
            let outer = Self.polygon(sides: 3, radius: 0.554, center: centroid)
            let inner = Self.polygon(sides: 3, radius: 0.36, center: centroid)
            outline = outer
            facets = [Facet(points: inner, isFront: true)] + Self.bevels(outer: outer, inner: inner)
            labelCenter = CGPoint(x: 0.5, y: 0.6)
            labelWidth = 0.3
            fontScale = 0.22
        case .d6:
            // Cube: a square with a beveled front face.
            let outer = [CGPoint(x: 0.06, y: 0.06), CGPoint(x: 0.94, y: 0.06), CGPoint(x: 0.94, y: 0.94), CGPoint(x: 0.06, y: 0.94)]
            let inner = [CGPoint(x: 0.2, y: 0.2), CGPoint(x: 0.8, y: 0.2), CGPoint(x: 0.8, y: 0.8), CGPoint(x: 0.2, y: 0.8)]
            outline = outer
            facets = [Facet(points: inner, isFront: true)] + Self.bevels(outer: outer, inner: inner)
            cornerRadius = 0.16
            labelWidth = 0.5
            fontScale = 0.36
        case .d8:
            // Octahedron: a hexagon whose front face touches every other corner.
            let outer = Self.polygon(sides: 6, radius: 0.48)
            outline = outer
            facets = [Facet(points: [outer[0], outer[2], outer[4]], isFront: true)]
                + stride(from: 0, to: 6, by: 2).map { Facet(points: [outer[$0], outer[$0 + 1], outer[($0 + 2) % 6]]) }
            labelCenter = CGPoint(x: 0.5, y: 0.56)
            labelWidth = 0.34
            fontScale = 0.26
        case .d10, .d100:
            // Pentagonal trapezohedron: a kite with a kite-shaped front face.
            let top = CGPoint(x: 0.5, y: 0.03)
            let right = CGPoint(x: 0.97, y: 0.56), bottom = CGPoint(x: 0.5, y: 0.97), left = CGPoint(x: 0.03, y: 0.56)
            let innerRight = CGPoint(x: 0.77, y: 0.55), innerBottom = CGPoint(x: 0.5, y: 0.76), innerLeft = CGPoint(x: 0.23, y: 0.55)
            outline = [top, right, bottom, left]
            facets = [
                Facet(points: [top, innerRight, innerBottom, innerLeft], isFront: true),
                Facet(points: [top, right, innerRight]),
                Facet(points: [right, bottom, innerBottom, innerRight]),
                Facet(points: [bottom, left, innerLeft, innerBottom]),
                Facet(points: [left, top, innerLeft]),
            ]
            labelCenter = CGPoint(x: 0.5, y: 0.52)
            labelWidth = die == .d100 ? 0.4 : 0.34
            fontScale = 0.24
        case .d12:
            // Dodecahedron: a decagon around a pentagonal front face.
            let outer = Self.polygon(sides: 10, radius: 0.49)
            let inner = Self.polygon(sides: 5, radius: 0.3)
            outline = outer
            facets = [Facet(points: inner, isFront: true)] + (0..<5).map { index in
                Facet(points: [inner[index], outer[index * 2], outer[index * 2 + 1], outer[(index * 2 + 2) % 10], inner[(index + 1) % 5]])
            }
            labelWidth = 0.38
            fontScale = 0.28
        case .d20:
            // Icosahedron: a hexagon around a triangular front face, with three
            // triangles between each pair of face corners.
            let outer = Self.polygon(sides: 6, radius: 0.48)
            let inner = Self.polygon(sides: 3, radius: 0.36)
            outline = outer
            facets = [Facet(points: inner, isFront: true)] + (0..<3).flatMap { index in
                let corner = inner[index], next = inner[(index + 1) % 3]
                let facing = outer[index * 2], between = outer[index * 2 + 1], nextFacing = outer[(index * 2 + 2) % 6]
                return [
                    Facet(points: [corner, facing, between]),
                    Facet(points: [corner, between, next]),
                    Facet(points: [next, between, nextFacing]),
                ]
            }
            labelCenter = CGPoint(x: 0.5, y: 0.54)
            labelWidth = 0.32
            fontScale = 0.24
        }

        if appearance == .minimal {
            // Overrides the label placement set above for the front face:
            // without facets the value can use the whole silhouette;
            // the d4 label sits a little low so it clears the narrow tip.
            let center = Self.centroid(of: outline)
            labelCenter = CGPoint(x: center.x, y: center.y + (die == .d4 ? 0.03 : 0))
            labelWidth = die == .d4 ? 0.42 : 0.56
            fontScale = die == .d4 ? 0.3 : 0.4
        }
    }

    /// How much a facet faces a light coming from the top left, in -1...1.
    /// The facet's slant is estimated from its position relative to the front face.
    func lighting(of facet: Facet) -> Double {
        if facet.isFront { return 0.1 }
        let center = Self.centroid(of: facets[0].points)
        let facetCenter = Self.centroid(of: facet.points)
        let direction = CGVector(dx: facetCenter.x - center.x, dy: facetCenter.y - center.y)
        let length = hypot(direction.dx, direction.dy)
        guard length > 0 else { return 0 }
        let light = CGVector(dx: -0.447, dy: -0.894)
        return (direction.dx * light.dx + direction.dy * light.dy) / length
    }

    /// A regular polygon with its first corner pointing up, clockwise.
    static func polygon(sides: Int, radius: CGFloat, center: CGPoint = CGPoint(x: 0.5, y: 0.5)) -> [CGPoint] {
        (0..<sides).map { index in
            let angle = -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(sides)
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
    }

    /// The quads joining each side of an inner polygon to the matching side of the outer one.
    static func bevels(outer: [CGPoint], inner: [CGPoint]) -> [Facet] {
        outer.indices.map { index in
            let next = (index + 1) % outer.count
            return Facet(points: [outer[index], outer[next], inner[next], inner[index]])
        }
    }

    static func centroid(of points: [CGPoint]) -> CGPoint {
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }
}

/// Maps a unit point into the largest square centered in `rect`.
private nonisolated func scaled(_ point: CGPoint, in rect: CGRect) -> CGPoint {
    let side = min(rect.width, rect.height)
    return CGPoint(x: rect.midX + (point.x - 0.5) * side, y: rect.midY + (point.y - 0.5) * side)
}

private nonisolated struct PolygonShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addLines(points.map { scaled($0, in: rect) })
        path.closeSubpath()
        return path
    }
}

/// A polygon with rounded corners.
private nonisolated struct RoundedPolygonShape: Shape {
    let points: [CGPoint]
    /// Relative to the die size.
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let corners = points.map { scaled($0, in: rect) }
        guard let first = corners.first, let last = corners.last else { return Path() }
        let radius = cornerRadius * min(rect.width, rect.height)
        var path = Path()
        // Start mid-side so every corner, including the first, gets its arc.
        path.move(to: CGPoint(x: (last.x + first.x) / 2, y: (last.y + first.y) / 2))
        for index in corners.indices {
            path.addArc(tangent1End: corners[index], tangent2End: corners[(index + 1) % corners.count], radius: radius)
        }
        path.closeSubpath()
        return path
    }
}

#Preview("Minimal") {
    DieGallery(appearance: .minimal)
}

#Preview("Shaded") {
    DieGallery(appearance: .shaded)
}

/// Every die side by side, for the previews.
private struct DieGallery: View {
    let appearance: DieAppearance

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(), GridItem()]) {
                ForEach(Die.allCases) { die in
                    DieView(die: die, value: nil, color: die.color, appearance: appearance)
                    DieView(die: die, value: die.sides, color: die.color, appearance: appearance)
                }
            }
            .padding()
        }
    }
}
