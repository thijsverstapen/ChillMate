import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Generates short, supportive affirmations entirely on-device using Apple's
/// FoundationModels framework (iOS 26+). Nothing leaves the device.
///
/// Safety stance: this app is a harm-reduction / wellbeing companion, so the
/// model is **never** used for medical, dosage, or substance advice. It only
/// produces gentle, general affirmations, and every path degrades safely:
/// when the model is unavailable (older device, Apple Intelligence off,
/// Simulator, generation error) the caller keeps the curated static pool.
enum OnDeviceAffirmationService {

    /// True when the on-device model is ready to generate text right now.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return true
        default:
            return false
        }
        #else
        return false
        #endif
    }

    /// Why the on-device model is not available, when it is not.
    ///
    /// The weekly reflection's written summary simply disappeared when the model
    /// was unavailable, which reads as a section that does not exist rather than
    /// one that could. Two of the three reasons are things the reader can act on,
    /// and the third is worth knowing rather than guessing at.
    enum Absence {
        /// The hardware cannot run Apple Intelligence.
        case deviceNotEligible
        /// The hardware can, and it is switched off.
        case notEnabled
        /// On its way: downloading, or warming up.
        case modelNotReady
        /// No FoundationModels at all, which is every build below iOS 26.
        case unsupported

        /// One sentence, in the reader's language, saying what is true and — when
        /// there is one — what they could do about it.
        var explanation: String {
            switch self {
            case .deviceNotEligible:
                String(localized: "This device cannot run Apple Intelligence, so there is no written summary here. Everything else on this page still works.")
            case .notEnabled:
                String(localized: "Turn on Apple Intelligence in your device settings and a short written summary will appear here.")
            case .modelNotReady:
                String(localized: "Apple Intelligence is still getting ready. The written summary will appear once it is.")
            case .unsupported:
                String(localized: "A written summary is not available on this device. Everything else on this page still works.")
            }
        }
    }

    /// Nil when the model is ready to generate.
    static var absence: Absence? {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .deviceNotEligible
            case .appleIntelligenceNotEnabled: return .notEnabled
            case .modelNotReady: return .modelNotReady
            // A reason added by a later OS is still an absence, and saying the
            // neutral thing beats saying nothing or guessing wrong.
            @unknown default: return .unsupported
            }
        }
        #else
        return .unsupported
        #endif
    }

    /// Generates up to `count` fresh affirmations on-device.
    ///
    /// Returns `nil` (not an empty array) when the model is unavailable or
    /// generation fails, so callers can cleanly fall back to their static pool.
    /// - Parameter languageCode: BCP-47-ish code (e.g. "en", "nl") so the model
    ///   replies in the user's language.
    static func generateAffirmations(count: Int, languageCode: String) async -> [String]? {
        #if canImport(FoundationModels)
        guard isAvailable else { return nil }

        let language = languageName(for: languageCode)
        let instructions = """
        You write very short, warm affirmations for ChillMate, a private wellbeing \
        and harm-reduction companion used by adults (18+) who track how they feel \
        and their own wellbeing goals.

        Rules you must always follow:
        - Each affirmation is one or two short sentences, under 140 characters.
        - Gentle, encouraging, non-judgmental, and in the second person ("you").
        - Never give medical, dosage, drug, treatment, or diagnostic advice.
        - Never name or refer to specific substances.
        - Never make promises about outcomes or recovery.
        - Keep a calm, grounding tone; assume the reader may be having a hard day.
        - Write entirely in \(language).
        """

        let prompt = """
        Write \(count) distinct affirmations. Put each one on its own line with no \
        numbering, quotes, or bullet characters.
        """

        do {
            let session = LanguageModelSession(instructions: { instructions })
            let response = try await session.respond(to: prompt)
            let lines = response.content
                .split(whereSeparator: \.isNewline)
                .map { cleanLine(String($0)) }
                .filter { !$0.isEmpty && $0.count <= 200 }
            return lines.isEmpty ? nil : Array(lines.prefix(count))
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Generates a short, private weekly reflection from aggregate stats only.
    /// No substance names, notes, or free text ever reach the model: counts and
    /// a generic sleep signal only, keeping the same safety stance as the
    /// affirmations. Returns nil when the model is unavailable or output is
    /// unusable, so the caller can simply hide the card.
    static func generateWeeklyReflection(
        chillCount: Int,
        substanceLogCount: Int,
        journalCount: Int,
        memoryGapCount: Int,
        averageSleepHours: Double?,
        languageCode: String
    ) async -> String? {
        #if canImport(FoundationModels)
        guard isAvailable else { return nil }

        let language = languageName(for: languageCode)
        let sleepLine = averageSleepHours.map {
            "Average sleep on logged nights: \($0.formatted(.number.precision(.fractionLength(1)))) hours."
        } ?? "No sleep data recorded."

        let instructions = """
        You write a short weekly reflection for ChillMate, a private wellbeing \
        and harm-reduction companion used by adults (18+).

        Rules you must always follow:
        - Two or three short sentences, under 320 characters in total.
        - Warm, non-judgmental, second person ("you"). Notice patterns without praise or blame.
        - Never give medical, dosage, drug, treatment, or diagnostic advice.
        - Never name or refer to specific substances.
        - Never make promises about outcomes or recovery.
        - Write entirely in \(language).
        """

        let prompt = """
        Write this week's reflection from these numbers alone:
        - Nights logged with a session: \(chillCount)
        - Nights that included substance use: \(substanceLogCount)
        - Journal entries written: \(journalCount)
        - Memory gaps reported: \(memoryGapCount)
        - \(sleepLine)
        Reply with plain text only: no headings, bullets, or quotes.
        """

        do {
            let session = LanguageModelSession(instructions: { instructions })
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text.count <= 600 else { return nil }
            return text
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Strips stray leading bullets / numbering / quotes the model may emit.
    private static func cleanLine(_ raw: String) -> String {
        var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while let first = line.first, "-•*0123456789.)\"' ".contains(first) {
            line.removeFirst()
            line = line.trimmingCharacters(in: .whitespaces)
        }
        return line.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    private static func languageName(for code: String) -> String {
        switch code.lowercased().prefix(2) {
        case "nl": return "Dutch"
        case "es": return "Spanish"
        case "de": return "German"
        case "fr": return "French"
        default: return "English"
        }
    }
}
