import Foundation
import Testing
import ChillMateCore

/// Searching and reading the user's own journal text.
///
/// These assert behaviour, not wording, so they hold in whichever language the
/// run resolved — the tagger is given text in the language being asserted about
/// rather than relying on the app's locale.
@Suite("Journal language")
struct JournalLanguageTests {

    private func documents(_ pairs: [(String, String)]) -> [JournalLanguage.Document] {
        pairs.map { JournalLanguage.Document(id: $0.0, text: $0.1) }
    }

    // MARK: Terms

    /// The whole reason for lemmatising: an inflected word has to reduce to the
    /// same term as the word somebody types into a search box.
    ///
    /// Asserted in both worlds rather than skipped in one. `NLTagger`'s lemma
    /// model is an on-device asset and the Simulator has none, so asserting the
    /// lemma unconditionally fails everywhere it is absent — and skipping there
    /// would mean the assertion never runs in CI at all. Where the model exists
    /// the terms must merge; where it does not, the word must survive as written
    /// so search still finds the exact phrase.
    @Test("Inflections reduce to the same term where the platform can")
    func inflectionsShareATerm() {
        let singular = JournalLanguage.terms(in: "night")
        let plural = JournalLanguage.terms(in: "nights")
        #expect(!singular.isEmpty)
        #expect(!plural.isEmpty)

        if JournalLanguage.lemmatizationIsAvailable {
            #expect(!singular.isDisjoint(with: plural),
                    "\(singular) and \(plural) share nothing, so a search for one cannot find the other")
        } else {
            #expect(plural.contains("nights"),
                    "without lemmas the word has to survive as written, got \(plural)")
        }
    }

    /// Slang and misspellings have no lemma, and they are exactly what somebody
    /// searches their own journal for. The word itself has to survive.
    @Test("A word the tagger does not know is kept as written")
    func unknownWordsSurvive() {
        let found = JournalLanguage.terms(in: "zzyzx")
        #expect(found.contains("zzyzx"))
    }

    @Test("Case and accents do not change a term")
    func foldingIsApplied() {
        #expect(JournalLanguage.terms(in: "Café") == JournalLanguage.terms(in: "cafe"))
    }

    @Test("Empty and punctuation-only text yields no terms", arguments: ["", "   ", "!!!", "\n\t"])
    func emptyTextHasNoTerms(text: String) {
        #expect(JournalLanguage.terms(in: text).isEmpty)
    }

    // MARK: Search

    @Test("An entry is found by a word it does not spell identically")
    func findsInflectedMatch() throws {
        let results = JournalLanguage.search(
            documents([("a", "I was feeling anxious for most of it"), ("b", "slept well, good day")]),
            query: "felt anxious"
        )
        let best = try #require(results.first)
        #expect(best.id == "a", "ranked \(results.map(\.id)) — the anxious entry should lead")
    }

    /// A literal phrase hit is the strongest signal there is, and has to outrank
    /// an entry that merely shares the same words separately.
    @Test("An exact phrase outranks a scattered word match")
    func exactPhraseWins() throws {
        let results = JournalLanguage.search(
            documents([
                ("scattered", "the music was loud. later it got quiet."),
                ("exact", "it was loud music all night"),
            ]),
            query: "loud music"
        )
        let best = try #require(results.first)
        #expect(best.id == "exact", "ranked \(results.map { "\($0.id):\($0.score)" })")
    }

    @Test("A query sharing nothing returns nothing")
    func unrelatedQueryFindsNothing() {
        let results = JournalLanguage.search(
            documents([("a", "slept well and felt fine")]),
            query: "zzyzx quuxly"
        )
        #expect(results.isEmpty, "matched \(results.map(\.id))")
    }

    @Test("An empty query returns nothing rather than everything")
    func emptyQueryReturnsNothing() {
        let all = documents([("a", "one"), ("b", "two")])
        #expect(JournalLanguage.search(all, query: "").isEmpty)
        #expect(JournalLanguage.search(all, query: "   ").isEmpty)
    }

    @Test("Scores stay inside the range the callers assume")
    func scoresAreBounded() {
        let results = JournalLanguage.search(
            documents([("a", "loud music all night"), ("b", "quiet night in")]),
            query: "loud music all night"
        )
        for match in results {
            #expect(match.score > 0 && match.score <= 1, "\(match.id) scored \(match.score)")
        }
    }

    /// Ranking must not depend on the order the store handed rows over, or the
    /// same search shows different results on different reads.
    @Test("The ordering does not depend on input order")
    func orderingIsStable() {
        let pairs = [("a", "loud music"), ("b", "loud music"), ("c", "quiet")]
        let forward = JournalLanguage.search(documents(pairs), query: "loud music").map(\.id)
        let backward = JournalLanguage.search(documents(pairs.reversed()), query: "loud music").map(\.id)
        #expect(forward == backward, "\(forward) vs \(backward)")
    }

    // MARK: Sentiment

    /// Nil, not zero, when there is nothing to read. Zero is a lie that looks
    /// like data: on a chart it is indistinguishable from a neutral entry.
    @Test("Text too short to judge scores nil", arguments: ["", "ok", "fine", "good day"])
    func shortTextIsNotScored(text: String) {
        #expect(JournalLanguage.sentiment(of: text) == nil,
                "\(text.debugDescription) was given a score it cannot support")
    }

    /// Whatever the platform can do, a score that comes back has to be inside the
    /// range every caller assumes. Nil is a legitimate answer and is asserted
    /// separately: the sentiment model is an on-device asset, absent in the
    /// Simulator and not guaranteed on a device.
    @Test("Any score that comes back is inside the documented range")
    func scoreIsBounded() {
        let text = "Last night was genuinely lovely and I felt safe and looked after the whole time."
        guard let score = JournalLanguage.sentiment(of: text) else {
            #expect(JournalLanguage.sentimentIsAvailable == false,
                    "sentiment returned nil while claiming to be available")
            return
        }
        #expect(score >= -1 && score <= 1)
    }

    /// The direction has to be right, or the trend line is worse than nothing.
    /// Compared rather than thresholded, because the absolute numbers are
    /// Apple's and move between OS versions.
    ///
    /// `.enabled(if:)` rather than `#require`, because a platform without the
    /// model is not a failure — it is a platform without the model, and the
    /// behaviour there is asserted by `unavailableModelYieldsNil` instead. This
    /// does mean the direction goes unchecked in CI, where the Simulator has no
    /// sentiment assets; it runs on a device and on macOS.
    @Test("Warm writing scores above bleak writing",
          .enabled(if: JournalLanguage.sentimentIsAvailable))
    func directionIsCorrect() throws {
        let warm = try #require(JournalLanguage.sentiment(
            of: "Last night was genuinely lovely and I felt safe and looked after the whole time."))
        let bleak = try #require(JournalLanguage.sentiment(
            of: "Last night was awful and frightening and I felt alone and miserable the whole time."))
        #expect(warm > bleak, "warm scored \(warm), bleak scored \(bleak)")
    }

    /// The contract the trend card depends on: when the platform cannot read
    /// text, every entry scores nil and the card says so rather than drawing a
    /// flat line through zeros.
    @Test("An unavailable model yields nil, never zero")
    func unavailableModelYieldsNil() {
        guard !JournalLanguage.sentimentIsAvailable else { return }
        let scores = [
            "Last night was genuinely lovely and I felt safe the whole time.",
            "Last night was awful and frightening and I felt completely alone.",
        ].map { JournalLanguage.sentiment(of: $0) }
        #expect(scores.allSatisfy { $0 == nil },
                "an unreadable platform produced a score: \(scores)")
    }
}
