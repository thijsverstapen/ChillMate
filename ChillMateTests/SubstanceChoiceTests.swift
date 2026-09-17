import Foundation
import Testing
import ChillMateCore
@testable import ChillMate

/// The two lists of substances that now exist, and the rule that they are one
/// list.
///
/// `Substance` lives in `ChillMateCore`. `SubstanceChoice` is its mirror in the
/// app, and it exists only because App Intents refuses an `AppEnum` from an
/// imported module — the metadata processor reads the cases out of the app
/// target's own source and fails with "enums implemented in an imported
/// framework or library are not supported".
///
/// A mirror is a thing that falls out of step. Adding a substance to the domain
/// and forgetting the mirror would drop it out of Siri and the Shortcuts gallery
/// silently, with nothing failing anywhere.
@Suite("Substance choice")
struct SubstanceChoiceTests {

    @Test("Every substance can be named by a Shortcut")
    func everySubstanceHasAChoice() {
        let choices = Set(SubstanceChoice.allCases.map(\.rawValue))
        for substance in Substance.allCases {
            #expect(choices.contains(substance.rawValue), "no Shortcuts case for \(substance.rawValue)")
        }
    }

    @Test("Every choice names a real substance")
    func everyChoiceResolves() {
        for choice in SubstanceChoice.allCases {
            #expect(
                Substance(rawValue: choice.rawValue) != nil,
                "\(choice.rawValue) does not name a substance"
            )
            #expect(choice.substance.rawValue == choice.rawValue)
        }
    }

    /// The mapping falls back to `.other` rather than trapping, and nothing
    /// should ever need that fallback.
    @Test("Nothing falls through to the fallback")
    func nothingUsesTheFallback() {
        for choice in SubstanceChoice.allCases where choice != .other {
            #expect(choice.substance != .other, "\(choice.rawValue) fell through to .other")
        }
    }

    /// Siri reads these out and the Shortcuts gallery shows them, so a case with
    /// no display representation is a case that appears blank in a picker.
    @Test("Every choice has something to display")
    func everyChoiceIsDisplayable() {
        for choice in SubstanceChoice.allCases {
            #expect(
                SubstanceChoice.caseDisplayRepresentations[choice] != nil,
                "\(choice.rawValue) has no display representation"
            )
        }
    }
}
