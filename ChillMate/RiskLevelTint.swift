import SwiftUI
import ChillMateCore

/// What a severity looks like. The severity itself is in `ChillMateCore`.
extension RiskLevel {

    var tint: Color {
        switch self {
        case .lower:
            Color.chillMint
        case .caution:
            .orange
        case .high:
            .red
        }
    }

    /// A distinct shape per level, so severity survives being looked at rather
    /// than read.
    ///
    /// The word was already there and is what VoiceOver reads, so this is not the
    /// colour-blindness fix — that was done when the badge stopped being a bare
    /// coloured capsule. This is for the glance: three shapes that differ in
    /// outline tell you which row is the bad one before you have read any of them,
    /// which is the way this screen actually gets used.
    var symbol: String {
        switch self {
        case .lower:
            "checkmark.circle.fill"
        case .caution:
            "exclamationmark.triangle.fill"
        case .high:
            "exclamationmark.octagon.fill"
        }
    }
}
