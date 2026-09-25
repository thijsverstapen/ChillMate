import SwiftUI
import ChillMateCore

/// How the journal has read over time, split into a recent half and an earlier
/// one.
///
/// Computed from the person's own writing with `NaturalLanguage`, on device.
/// Nothing here is a claim about a substance, a night, or a cause: it reports
/// how the words scored and how many it could score, and stops there. A sentence
/// telling somebody *why* their writing has darkened would be exactly the
/// invented content this app does not ship.
struct JournalMoodSummary: Equatable {
    /// Mean sentiment of the more recent half, -1 to 1.
    let recent: Double?
    /// Mean sentiment of the earlier half.
    let earlier: Double?
    /// How many entries carried enough text to score.
    let readCount: Int
    /// How many entries were looked at.
    let totalCount: Int

    /// Three on each side, matching the sleep card. Two entries are not a trend,
    /// and an app that draws a confident line through them teaches people to
    /// distrust the ones it draws through two hundred.
    static let minimumPerSide = 3

    var hasEnoughToCompare: Bool {
        recent != nil && earlier != nil && readCount >= Self.minimumPerSide * 2
    }

    /// Scores the entries, newest first, and splits them down the middle.
    ///
    /// Takes text rather than models so it can be tested without a store, and so
    /// the scoring stays off the view.
    static func make(newestFirst texts: [String]) -> JournalMoodSummary {
        let scored = texts.compactMap { JournalLanguage.sentiment(of: $0) }
        guard scored.count >= 2 else {
            return JournalMoodSummary(
                recent: nil, earlier: nil,
                readCount: scored.count, totalCount: texts.count
            )
        }

        let half = scored.count / 2
        let recentHalf = Array(scored.prefix(half))
        let earlierHalf = Array(scored.suffix(scored.count - half))

        func mean(_ values: [Double]) -> Double? {
            values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        }

        return JournalMoodSummary(
            recent: mean(recentHalf),
            earlier: mean(earlierHalf),
            readCount: scored.count,
            totalCount: texts.count
        )
    }
}

/// The card. Scoring happens in a `.task` rather than in `body`, because reading
/// a few hundred entries with the tagger is real work and a computed property on
/// a view is re-evaluated on every render.
struct JournalMoodTrendCard: View {
    let texts: [String]

    @State private var summary: JournalMoodSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CareSectionTitle(title: String(localized: "How your writing has felt"), symbol: "text.quote")

            if let summary, summary.hasEnoughToCompare {
                row(label: String(localized: "Recent entries"), score: summary.recent, tint: Color.chillPrimary)
                row(label: String(localized: "Earlier entries"), score: summary.earlier, tint: Color.chillSecondaryBlue)

                Text("Read from \(summary.readCount) of \(summary.totalCount) entries. Very short ones are left out.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Not enough written yet to compare. This needs a few entries on each side, long enough to read.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glassSurface(radius: 24, tint: Color.chillIconPurple.opacity(0.08))
        .task(id: texts) {
            summary = JournalMoodSummary.make(newestFirst: texts)
        }
    }

    /// A score as a bar, never as a number.
    ///
    /// -0.42 reads as a measurement of a person's month, which it is not: it is
    /// how a sentiment model scored some words. A bar says the same thing with
    /// the precision it actually has.
    @ViewBuilder
    private func row(label: String, score: Double?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.chillSecondary)

            GeometryReader { proxy in
                let fraction = ((score ?? 0) + 1) / 2
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.15))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(6, proxy.size.width * fraction))
                }
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(accessibilityValue(for: score)))
    }

    /// Words, not a number, for the same reason the bar is not a number.
    private func accessibilityValue(for score: Double?) -> String {
        guard let score else { return String(localized: "Not enough to read") }
        if score > 0.15 { return String(localized: "Mostly warm") }
        if score < -0.15 { return String(localized: "Mostly heavy") }
        return String(localized: "Mixed")
    }
}
