//
//  Die.swift
//  Rollix Watch App
//

import Foundation

/// The polyhedral dice commonly used in tabletop role-playing games.
nonisolated enum Die: Int, CaseIterable, Identifiable {
    case d4 = 4
    case d6 = 6
    case d8 = 8
    case d10 = 10
    case d12 = 12
    case d20 = 20
    case d100 = 100

    var id: Int { rawValue }

    var sides: Int { rawValue }

    var name: String { "d\(sides)" }

    /// The die with the next larger number of faces, or `nil` for the largest one.
    var next: Die? { neighbor(by: 1) }

    /// The die with the next smaller number of faces, or `nil` for the smallest one.
    var previous: Die? { neighbor(by: -1) }

    private func neighbor(by offset: Int) -> Die? {
        guard let index = Die.allCases.firstIndex(of: self) else { return nil }
        let target = index + offset
        return Die.allCases.indices.contains(target) ? Die.allCases[target] : nil
    }

    /// Rolls the die and returns a value in `1...sides`.
    func roll() -> Int {
        Int.random(in: 1...sides)
    }

    /// Whether the value is the highest face (a "natural" critical success).
    func isCriticalSuccess(_ value: Int) -> Bool {
        value == sides
    }

    /// Whether the value is the lowest face (a critical failure).
    func isCriticalFailure(_ value: Int) -> Bool {
        value == 1
    }
}
