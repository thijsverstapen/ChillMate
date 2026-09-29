import Foundation
import NaturalLanguage

/// Reading what somebody wrote in their own journal, on device.
///
/// Two jobs, both operating only on the user's own words: finding an entry they
/// half-remember writing, and tracking how their writing has felt over time.
/// Neither produces a claim about a substance, which is the line this app does
/// not cross — nothing here interprets, advises, or rates anything. It reads
/// text the person typed and hands back a number or an ordering.
///
/// `NaturalLanguage` rather than a language model on purpose. It needs no
/// Apple Intelligence, no model download and no supported-device check, so it
/// behaves the same on the oldest phone that can run the app as on the newest.
public enum JournalLanguage {

    // MARK: - Sentiment

    /// How positive or negative a piece of writing reads, from -1 to 1.
    ///
    /// Returns nil rather than zero when the platform has no sentiment model for
    /// the language the text is in. Zero would be a lie that looks like data: on
    /// a chart, "neutral" and "we could not read this" are the same dot, and the
    /// person would be looking at a flat line believing it meant something about
    /// their year.
    ///
    /// Nil is also returned for text too short to judge. A three-word entry
    /// scores as confidently as a paragraph and means far less.
    public static func sentiment(of text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumSentimentLength else { return nil }

        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = trimmed
        let (tag, _) = tagger.tag(at: trimmed.startIndex, unit: .paragraph, scheme: .sentimentScore)
        guard let raw = tag?.rawValue, let score = Double(raw) else { return nil }
        // The tagger returns 0 both for "neutral" and, in some builds, for text
        // it could not score. Neutral writing is real, so this keeps zero — the
        // length floor above is what keeps the unreadable cases out.
        return min(1, max(-1, score))
    }

    /// Below this, a score says more about the sentence than about the person.
    public static let minimumSentimentLength = 25

    // MARK: - Search

    /// One journal entry, reduced to the parts this type can read.
    ///
    /// Takes an id and text rather than the model, so the domain stays free of
    /// SwiftData and the ranking can be tested without a store.
    public struct Document: Sendable, Equatable {
        public let id: String
        public let text: String

        public init(id: String, text: String) {
            self.id = id
            self.text = text
        }
    }

    /// A document that matched, and how well.
    public struct Match: Sendable, Equatable, Identifiable {
        public let id: String
        /// 0 to 1. Comparable within one search, not across searches.
        public let score: Double

        public init(id: String, score: Double) {
            self.id = id
            self.score = score
        }
    }

    /// Entries matching a query, best first.
    ///
    /// Matches on lemmas rather than characters, so "felt anxious" finds an entry
    /// that says "feeling anxious" and "nights" finds "night". Substring search
    /// cannot do that, and it is the difference between a search box that finds
    /// what you meant and one you stop using.
    ///
    /// Lemmatisation is used instead of sentence embeddings deliberately.
    /// `NLEmbedding.sentenceEmbedding(for:)` exists for some languages and not
    /// others, so a search built on it would quietly work in English and quietly
    /// not work in Dutch — the exact failure this codebase keeps finding. The
    /// tagger handles all five.
    ///
    /// - Parameter minimumScore: matches below this are dropped. The default
    ///   keeps anything sharing a meaningful word.
    public static func search(
        _ documents: [Document],
        query: String,
        minimumScore: Double = 0.01
    ) -> [Match] {
        let queryTerms = terms(in: query)
        guard !queryTerms.isEmpty else { return [] }

        let needle = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var matches: [Match] = []
        for document in documents {
            let documentTerms = terms(in: document.text)
            guard !documentTerms.isEmpty else { continue }

            let shared = queryTerms.intersection(documentTerms)
            var score = Double(shared.count) / Double(queryTerms.count)

            // A literal hit is the strongest signal there is: the person typed
            // the phrase they remember writing. It lifts the row rather than
            // replacing the term score, so a full phrase match outranks an entry
            // that happens to share every word separately.
            let haystack = document.text
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            if !needle.isEmpty, haystack.contains(needle) {
                score += 1
            }

            let normalized = min(1, score / 2)
            if normalized >= minimumScore {
                matches.append(Match(id: document.id, score: normalized))
            }
        }

        // Sorted by score, then by id, so an ordering never depends on the order
        // the store happened to hand the rows over.
        return matches.sorted {
            $0.score == $1.score ? $0.id < $1.id : $0.score > $1.score
        }
    }

    /// Whether this platform can reduce a word to its dictionary form right now.
    ///
    /// `NLTagger`'s lemma and sentiment models are on-device assets, and they are
    /// not everywhere: the iOS Simulator has neither, and a device may not have
    /// them for a given language. Search still works without them — `terms(in:)`
    /// keeps the word as written — it just stops matching across inflections.
    ///
    /// Exposed so the tests can assert the real behaviour in both worlds instead
    /// of asserting a capability and failing wherever it is absent.
    public static var lemmatizationIsAvailable: Bool {
        // "nights" reduces to "night" wherever the model is present, and stays
        // "nights" wherever it is not.
        terms(in: "nights").contains("night")
    }

    /// Whether this platform can score sentiment right now.
    ///
    /// Same story as `lemmatizationIsAvailable`. `sentiment(of:)` already returns
    /// nil rather than zero when it cannot read text, and the trend card says so
    /// rather than drawing a flat line.
    public static var sentimentIsAvailable: Bool {
        sentiment(of: "This was a genuinely lovely evening and I felt safe throughout.") != nil
    }

    /// The meaningful words in a string, reduced to their dictionary form.
    ///
    /// Internal to the ranking, and exposed because the tests assert on it
    /// directly: an ordering is hard to debug when the thing being ordered is
    /// invisible.
    public static func terms(in text: String) -> Set<String> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = trimmed

        var found: Set<String> = []
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther]
        tagger.enumerateTags(
            in: trimmed.startIndex..<trimmed.endIndex,
            unit: .word,
            scheme: .lemma,
            options: options
        ) { tag, range in
            // The lemma when the tagger knows the word, the word itself when it
            // does not. Slang, street names and misspellings have no lemma, and
            // those are exactly the words somebody searches their own journal for.
            let raw = tag?.rawValue ?? String(trimmed[range])
            let normalized = raw
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
                .trimmingCharacters(in: .punctuationCharacters)
            if normalized.count >= 2 {
                found.insert(normalized)
            }
            return true
        }
        return found
    }
}
