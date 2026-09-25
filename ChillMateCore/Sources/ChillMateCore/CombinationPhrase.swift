import Foundation

/// Reading a sentence into a set of substances the risk checker can rate.
///
/// The checker asks people to tap through a grid. That is precise and it is slow,
/// and the moment somebody most wants an answer is the moment they are least
/// able to tap through a grid. This reads "couple of beers and a bit of ket" into
/// the same selection the taps would have produced.
///
/// **The model never rates anything.** It is not even consulted first: the
/// deterministic reader below runs on the words, and whatever it finds is handed
/// to `SubstanceInteractionChecker` exactly as a tap would have been. A language
/// model is used only as a fallback for phrasing this cannot parse, and even then
/// its output is fed back through this same matcher, so it can only ever choose
/// among substances the app already knows. It cannot invent one, and it cannot
/// influence the severity of what it picks.
public enum CombinationPhrase {

    /// What a phrase was understood to mean.
    public struct Reading: Equatable, Sendable {
        /// Substances found, in the order the app lists them rather than the
        /// order they were typed, so the same sentence always reads the same way.
        public let substances: [Substance]

        public init(substances: [Substance]) {
            self.substances = substances
        }

        public var isEmpty: Bool { substances.isEmpty }
    }

    /// The substances the picker offers. `unknown` and `other` are not things a
    /// person names in a sentence, and matching them would produce a selection
    /// nobody typed.
    static var selectable: [Substance] {
        Substance.allCases.filter { $0 != .unknown && $0 != .other }
    }

    /// Reads a phrase into a selection.
    ///
    /// Matching is on whole words, not substrings. `Substance.matches` is a
    /// contains-check built for a search field, where typing "ke" should narrow
    /// towards ketamine; run over the words of a sentence it matches far too much,
    /// because one-letter and two-letter aliases are contained in half the words
    /// in any language.
    public static func read(_ phrase: String) -> Reading {
        let tokens = words(in: phrase)
        guard !tokens.isEmpty else { return Reading(substances: []) }

        // Word pairs too, so a two-word name survives tokenising.
        var candidates = Set(tokens)
        for (first, second) in zip(tokens, tokens.dropFirst()) {
            candidates.insert("\(first) \(second)")
        }

        let normalized = Set(candidates.map(singularized))
        let found = selectable.filter { substance in
            !Set(names(of: substance).map(singularized)).isDisjoint(with: normalized)
        }
        return Reading(substances: found)
    }

    /// Every spelling that means this substance, folded for comparison.
    ///
    /// Includes the localized display name, so a Dutch sentence naming the Dutch
    /// word is read in Dutch.
    static func names(of substance: Substance) -> Set<String> {
        var all = substance.aliases
        all.append(substance.rawValue)
        all.append(substance.localizedDisplayName)
        return Set(all.map(fold))
    }

    /// The words of a phrase, folded, with hyphens kept because some names have
    /// one and losing it turns 3-MMC into two tokens that mean nothing.
    static func words(in phrase: String) -> [String] {
        let separators = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "-"))
            .inverted
        return fold(phrase)
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
    }

    /// A trailing plural "s" removed, and only from words long enough to spare it.
    ///
    /// People type "beers" and the alias list says "beer". Applied to both sides
    /// it costs nothing and catches the common case.
    ///
    /// The length floor is the whole safety of this. MDMA's aliases include "e",
    /// and Spanish "es" is one of the most common words in the language — strip
    /// its "s" and every Spanish sentence names MDMA. Four characters keeps the
    /// short aliases out of reach of it.
    /// Public because the length floor is asserted directly: the test names the
    /// words it must refuse to strip, which is clearer than inferring it from a
    /// reading that happens to come back empty.
    public static func singularized(_ word: String) -> String {
        guard word.count >= 4, word.hasSuffix("s") else { return word }
        return String(word.dropLast())
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
