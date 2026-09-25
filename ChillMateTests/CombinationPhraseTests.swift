import Foundation
import Testing
import ChillMateCore
@testable import ChillMate

/// Reading a typed sentence into a risk-checker selection.
///
/// The sharp edge here is over-matching. `Substance.matches` is a contains-check
/// built for a search field, and MDMA's alias list includes "e" and "md" — run
/// over the words of a sentence, a contains-check finds MDMA in "went", "home"
/// and "made". A selection nobody typed, handed to a safety tool, is worse than
/// no selection at all.
@Suite("Combination phrase")
struct CombinationPhraseTests {

    private func read(_ phrase: String) -> Set<Substance> {
        Set(CombinationPhrase.read(phrase).substances)
    }

    @Test("A plain sentence reads into the substances it names")
    func readsASentence() {
        #expect(read("a couple of beers and a bit of ket") == [.alcohol, .ketamine])
    }

    @Test("Street names are read as well as proper ones")
    func readsStreetNames() {
        #expect(read("some xtc") == [.mdma])
        #expect(read("had a few drinks") == [.alcohol])
    }

    /// The regression this type exists to prevent.
    @Test("Common words are not read as substances", arguments: [
        "we went home early",
        "I made it back fine",
        "she came over and we talked",
        "the evening ended well",
    ])
    func ordinaryWordsMatchNothing(phrase: String) {
        let found = read(phrase)
        #expect(found.isEmpty, "\(phrase.debugDescription) read as \(found.map(\.rawValue))")
    }

    @Test("A plural reads the same as the singular")
    func pluralsAreRead() {
        #expect(read("beers") == read("beer"))
        #expect(read("a few drinks") == [.alcohol])
    }

    /// The floor on plural-stripping, spelled out. MDMA's aliases include "e",
    /// and "es" is one of the most common words in Spanish — without the length
    /// floor every Spanish sentence would name MDMA.
    @Test("Short words are never stripped to reach a short alias", arguments: [
        "es", "as", "is", "os", "us",
    ])
    func shortWordsAreNotStripped(word: String) {
        #expect(CombinationPhrase.singularized(word) == word)
        #expect(read(word).isEmpty, "\(word) read as \(read(word).map(\.rawValue))")
    }

    @Test("An empty or wordless phrase reads as nothing", arguments: ["", "   ", "!!!", "..."])
    func emptyPhraseReadsAsNothing(phrase: String) {
        #expect(read(phrase).isEmpty)
    }

    /// Unknown and Other are not things a person names, and matching them would
    /// put a selection on screen that nobody typed.
    @Test("Unknown and Other are never read from a phrase")
    func nonSelectableAreNeverRead() {
        for phrase in ["something unknown", "other stuff", "an unknown other thing"] {
            let found = read(phrase)
            #expect(!found.contains(.unknown), "\(phrase) read Unknown")
            #expect(!found.contains(.other), "\(phrase) read Other")
        }
    }

    @Test("Case and accents do not change the reading")
    func foldingApplies() {
        #expect(read("KET") == read("ket"))
        #expect(read("Ketamine") == read("ketamine"))
    }

    @Test("A hyphenated name survives tokenising")
    func hyphenatedNamesSurvive() {
        #expect(read("took some 3-mmc").contains(.threeMMC))
    }

    @Test("A phrase naming several things reads all of them")
    func readsSeveral() {
        let found = read("beers, then ket, then some xtc")
        #expect(found == [.alcohol, .ketamine, .mdma], "read \(found.map(\.rawValue))")
    }

    /// The ordering must come from the app's own list, not from the sentence, or
    /// the same combination shows up differently depending on how it was typed.
    @Test("The reading order does not depend on the typing order")
    func orderingIsStable() {
        let one = CombinationPhrase.read("ket and beers").substances
        let two = CombinationPhrase.read("beers and ket").substances
        #expect(one == two, "\(one.map(\.rawValue)) vs \(two.map(\.rawValue))")
    }

    /// What the phrase reader produces has to be exactly what tapping produces,
    /// or the sentence path and the grid path disagree about the same night.
    @Test("A phrase reading is rated identically to the same taps")
    func phraseAndTapsAgree() throws {
        let phrase = read("beers and ket")
        let tapped: Set<Substance> = [.alcohol, .ketamine]
        #expect(phrase == tapped)

        let fromPhrase = SubstanceInteractionChecker.warnings(for: phrase).map(\.id)
        let fromTaps = SubstanceInteractionChecker.warnings(for: tapped).map(\.id)
        #expect(fromPhrase == fromTaps)
    }
}
