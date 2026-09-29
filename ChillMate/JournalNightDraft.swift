import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// What a journal entry says about the night it describes, as fields a person
/// can check before anything is saved.
///
/// Logging is the part people stop doing. The journal is free text and the night
/// log is a form, so somebody who wrote three paragraphs about their night is
/// then asked to fill in a form about the same night — and does not. This reads
/// what they already wrote and offers to fill in what it found.
///
/// **What it deliberately does not extract: substances.** The model is reading
/// prose and could name one the person never wrote, and that name would land in
/// a harm-reduction log and then in the risk checker, the insights and the
/// summary somebody might hand a clinician. Substances stay a thing the person
/// taps for themselves. Everything here is a number or a yes/no that the person
/// sees and confirms before it is written.
struct JournalNightDraft: Equatable, Sendable {
    /// Hours of sleep the writing mentions, when it mentions any.
    var sleepHours: Double?
    /// Whether the writing says they have slept since.
    var slept: Bool?
    /// Whether the writing describes a gap in memory.
    var memoryGap: Bool?

    /// True when there is anything worth offering.
    var hasAnything: Bool {
        sleepHours != nil || slept != nil || memoryGap != nil
    }

    /// The range a sleep figure has to fall inside to be believed.
    ///
    /// A model reading "we were out till 5" can return 5 as an hours-slept
    /// figure. There is no way to tell from here whether it read or invented a
    /// number, so the only honest guards are the range and the confirmation step
    /// — a value outside a night's worth of sleep is dropped rather than shown.
    static let plausibleSleepHours: ClosedRange<Double> = 0...16

    /// Drops anything outside what a night can hold.
    func validated() -> JournalNightDraft {
        var copy = self
        if let hours = copy.sleepHours, !Self.plausibleSleepHours.contains(hours) {
            copy.sleepHours = nil
        }
        // Hours without having slept is a contradiction; the hours are the more
        // specific claim, so they win and the flag follows them.
        if copy.sleepHours != nil, copy.slept == false {
            copy.slept = true
        }
        return copy
    }
}

#if canImport(FoundationModels)
/// The shape the model is asked to fill.
///
/// Separate from `JournalNightDraft` so the type the rest of the app passes
/// around does not depend on FoundationModels being present.
@Generable
struct GeneratedNightDraft {
    @Guide(description: "Hours of sleep the text says the person got, or null if it does not say. A number between 0 and 16.")
    var sleepHours: Double?

    @Guide(description: "true if the text says they have slept since the night, false if it says they have not, null if it does not say.")
    var slept: Bool?

    @Guide(description: "true only if the text describes not remembering part of the night, null if it does not say.")
    var memoryGap: Bool?
}
#endif

extension OnDeviceAffirmationService {

    /// Reads a journal entry and offers what it found about the night.
    ///
    /// Returns nil when the model is unavailable or the text is too short to say
    /// anything, so the caller shows nothing rather than an empty offer.
    static func draftNight(from text: String) async -> JournalNightDraft? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 40 else { return nil }

        #if canImport(FoundationModels)
        guard isAvailable else { return nil }

        let instructions = """
        You extract facts from a personal journal entry for ChillMate, a private \
        wellbeing companion used by adults (18+).

        Rules you must always follow:
        - Only report what the text actually says. If it does not say something, \
        return null for that field. Never guess or infer.
        - Never mention, name, or reason about substances, drugs, medication, or \
        doses. They are not part of what you extract.
        - Give no advice, no interpretation, and no medical content of any kind.
        - Return only the structured fields you were asked for.
        """

        do {
            let session = LanguageModelSession(instructions: { instructions })
            let response = try await session.respond(
                to: "Journal entry:\n\n\(trimmed)",
                generating: GeneratedNightDraft.self
            )
            let generated = response.content
            let draft = JournalNightDraft(
                sleepHours: generated.sleepHours,
                slept: generated.slept,
                memoryGap: generated.memoryGap
            ).validated()
            return draft.hasAnything ? draft : nil
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}

// MARK: - Offering the draft

import SwiftUI
import SwiftData

/// Offers what the journal entry said about the night, and writes it only when
/// the person says so.
///
/// Deliberately not automatic. The app can read prose and be wrong about it, and
/// a night log is the thing the risk checker, the insights and the summary a
/// clinician might read are all built from. So the card shows each value it
/// found, in words, and nothing is written until the button is pressed.
struct JournalNightDraftCard: View {
    let text: String
    let date: Date

    @Environment(\.modelContext) private var modelContext
    @Query(ChillMateQueries.recentEntries) private var entries: [NightEntry]

    @State private var draft: JournalNightDraft?
    @State private var didApply = false

    private var sameDayEntry: NightEntry? {
        entries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        Group {
            if let draft, draft.hasAnything {
                VStack(alignment: .leading, spacing: 10) {
                    CareSectionTitle(title: String(localized: "From what you wrote"), symbol: "text.badge.checkmark")

                    ForEach(lines(for: draft), id: \.self) { line in
                        Label(line, systemImage: "checkmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(Color.chillText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if didApply {
                        Text("Added to your night log.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.chillSecondary)
                    } else {
                        Button {
                            apply(draft)
                        } label: {
                            Text("Add to your night log")
                                .font(.subheadline.weight(.bold))
                        }
                        .buttonStyle(ChillPlainButtonStyle())

                        Text("Read from your own words on this device. Check it before you add it.")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.chillTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassSurface(radius: 24, tint: Color.chillMint.opacity(0.08))
            }
        }
        .task(id: text) {
            didApply = false
            draft = await OnDeviceAffirmationService.draftNight(from: text)
        }
    }

    /// One sentence per field, so the person reads what will be written rather
    /// than a row of numbers.
    private func lines(for draft: JournalNightDraft) -> [String] {
        var lines: [String] = []
        if let hours = draft.sleepHours {
            lines.append(String(localized: "Sleep: \(hours.formatted(.number.precision(.fractionLength(0...1)))) hours"))
        }
        if draft.slept == true {
            lines.append(String(localized: "You have slept since"))
        }
        if draft.memoryGap == true {
            lines.append(String(localized: "A gap in your memory of the night"))
        }
        return lines
    }

    private func apply(_ draft: JournalNightDraft) {
        let entry = sameDayEntry ?? {
            let created = NightEntry(
                date: date,
                hadSex: false,
                partnerDetails: [],
                skippedNight: false,
                substances: [],
                injectionSubstances: [],
                triggerTags: []
            )
            modelContext.insert(created)
            return created
        }()

        if let hours = draft.sleepHours {
            entry.sleepHours = hours
            entry.sleptYet = true
        } else if draft.slept == true {
            entry.sleptYet = true
        }
        if draft.memoryGap == true {
            entry.reportedMemoryGap = true
        }

        try? modelContext.save()
        didApply = true
    }
}

// MARK: - Putting the person's own words in front of a clinician

extension OnDeviceAffirmationService {

    /// Condenses journal entries into a few sentences for a helper summary.
    ///
    /// The helper summary is the one document in this app a professional reads
    /// and acts on, and its whole design is that it reports what was logged and
    /// nothing else — no interpretation, no severity, no advice. A paragraph
    /// written by a model is interpretation by definition: choosing what to keep
    /// is an editorial act, and here the edit reaches a clinician.
    ///
    /// So this never writes into the summary. It produces a draft the person
    /// reads and edits in their own words before any of it is included, which is
    /// what makes the paragraph theirs rather than the model's. If they change
    /// nothing, they still chose to include it.
    ///
    /// Returns nil when the model is unavailable or there is too little to read.
    static func draftHelperNote(fromJournal texts: [String]) async -> String? {
        let joined = texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        guard joined.count >= 120 else { return nil }

        #if canImport(FoundationModels)
        guard isAvailable else { return nil }

        let instructions = """
        You condense somebody's own journal entries into a few sentences they may \
        choose to show a health professional. You are writing for them, in their \
        voice, about what they already wrote.

        Rules you must always follow:
        - Three or four short sentences, under 500 characters in total.
        - Use only what the entries say. Add nothing, and do not infer.
        - First person ("I"), plain language, no headings or bullets.
        - Never name or refer to substances, drugs, medication, or doses.
        - Never give medical, diagnostic, or treatment content of any kind.
        - Do not assess severity, risk, or urgency. Do not advise.
        - Write in the same language as the entries.
        """

        do {
            let session = LanguageModelSession(instructions: { instructions })
            let response = try await session.respond(to: "Journal entries:\n\n\(joined)")
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text.count <= 900 else { return nil }
            return text
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
