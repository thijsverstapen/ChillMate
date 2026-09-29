import SwiftUI
import ChillMateCore

/// How substances and interaction severities look, kept apart from what they are.
///
/// `Substance.swift` and `SubstanceInteractions.swift` are the app's domain: what
/// a substance is, how two of them combine, what the published sources say. Both
/// imported SwiftUI, for one colour each and for two views that happened to be
/// written at the bottom of the same file. That import is what stops the domain
/// from being ordinary Swift that anything can compile and anything can test.
///
/// Nothing here decides anything. Every value is a rendering of a decision made
/// somewhere else, which is the point of the split: a severity is a severity
/// whether or not there is a screen.

extension Substance {

    var tint: Color {
        switch self {
        case .cannabis:
            Color.chillMint
        case .alcohol:
            .orange
        case .mdma:
            Color.chillMint
        case .threeMMC:
            .red
        case .ketamine:
            Color.chillPrimary
        case .ghb:
            Color.chillSecondaryBlue
        case .gbl:
            Color.chillMint
        case .cocaine:
            Color.chillSecondaryBlue
        case .poppers:
            Color.chillMint
        case .kamagra:
            Color.chillSecondaryBlue
        case .viagra:
            .indigo
        case .psychedelics:
            .indigo
        case .benzodiazepines:
            .purple
        case .methamphetamine:
            .pink
        case .unknown:
            .gray
        case .other:
            .teal
        }
    }
}

extension SubstanceInteraction.Level {

    var color: Color {
            switch self {
            case .caution: .yellow
            case .serious: .orange
            case .critical: .red
            }
        }
}

