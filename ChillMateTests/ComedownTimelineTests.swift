import Foundation
import Testing
import ChillMateCore
@testable import ChillMate

/// The half of the curve the app used to leave out.
///
/// Two things are being protected here. The first is that nothing in
/// `ComedownTimeline` invents a duration: every boundary has to trace back to a
/// figure in `SubstanceReference`, and a substance whose source publishes no
/// after-effects window has to produce no window rather than a plausible one.
/// The second is direction: every range is read at its outer edge, so the answer
/// errs towards "this may still be working" and never towards "you are done".
@Suite("Comedown timeline")
struct ComedownTimelineTests {

    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func minutes(_ value: Double) -> Date {
        start.addingTimeInterval(value * 60)
    }

    // MARK: - Nothing is invented

    /// The rule from CLAUDE.md, as a test. A substance with no published
    /// after-effects figure must not acquire one.
    @Test("A substance with no published after-effects window gets none")
    func unpublishedWindowsStayEmpty() throws {
        let cocaine = try #require(ComedownTimeline(substance: .cocaine, startedAt: start))
        #expect(cocaine.afterEffectsEnd == nil)
        #expect(cocaine.lastPublishedMoment == cocaine.over.upperBound)
    }

    @Test("Substances with no reference produce no timeline", arguments: [Substance.unknown, .other])
    func unreferencedSubstancesProduceNothing(substance: Substance) {
        #expect(ComedownTimeline(substance: substance, startedAt: start) == nil)
    }

    /// Categories, not substances. Both carry a `noDoseReason` and no timings, and
    /// a timeline built from nothing would be a straight line through zero.
    @Test("Categories produce no timeline", arguments: [Substance.psychedelics, .benzodiazepines])
    func categoriesProduceNothing(substance: Substance) {
        #expect(ComedownTimeline(substance: substance, startedAt: start) == nil)
    }

    /// Every after-effects figure in the file has to come with the name of
    /// whoever published it, because the screen prints that name and a reader is
    /// invited to go and check it.
    @Test("Every published after-effects window names its source")
    func everyWindowIsAttributed() {
        for substance in Substance.allCases {
            guard let reference = substance.reference else { continue }
            for timing in reference.timings where timing.afterEffects != nil {
                let timeline = ComedownTimeline(
                    substance: substance, route: timing.route, startedAt: start
                )
                #expect(
                    timeline?.afterEffectsSourceName?.isEmpty == false,
                    "\(substance.rawValue) has an after-effects window with no source"
                )
            }
        }
    }

    /// GHB's and GBL's dose ladders are Drugs and Me's; their after-effects
    /// windows are PsychonautWiki's. Printing the first name over the second
    /// figure would send someone checking to a page that does not carry it.
    @Test("GHB and GBL credit the after-effects figures to PsychonautWiki",
          arguments: [Substance.ghb, .gbl])
    func borrowedFiguresKeepTheirOwnAttribution(substance: Substance) throws {
        let timeline = try #require(ComedownTimeline(substance: substance, startedAt: start))
        #expect(timeline.afterEffectsSourceName == "PsychonautWiki")
        #expect(substance.reference?.source.name == "Drugs and Me")
    }

    // MARK: - Ordering

    /// A curve that goes backwards would render as a filled bar with no meaning.
    @Test("Every timeline runs forwards")
    func boundariesAreOrdered() {
        for substance in Substance.allCases {
            guard let reference = substance.reference else { continue }
            for timing in reference.timings {
                guard let timeline = ComedownTimeline(
                    substance: substance, route: timing.route, startedAt: start
                ) else { continue }
                let label = "\(substance.rawValue) \(String(describing: timing.route))"
                #expect(timeline.onset.lowerBound >= timeline.startedAt, "\(label): onset before the dose")
                #expect(timeline.peak.upperBound >= timeline.onset.lowerBound, "\(label): peak before onset")
                #expect(timeline.over.upperBound >= timeline.peak.lowerBound, "\(label): over before peak")
                if let end = timeline.afterEffectsEnd {
                    #expect(end > timeline.over.upperBound, "\(label): after effects end before the effects do")
                }
            }
        }
    }

    // MARK: - Phases

    /// MDMA: onset 30–45 min, total 3–6 h, after effects 12–48 h.
    @Test("MDMA walks through every phase in order")
    func mdmaPhases() throws {
        let timeline = try #require(ComedownTimeline(substance: .mdma, startedAt: start))

        #expect(timeline.phase(at: minutes(10)) == .comingUp)
        // Still "coming up" at 44 minutes: the upper bound of the onset range has
        // not passed, so the app must not say it has arrived.
        #expect(timeline.phase(at: minutes(44)) == .comingUp)
        #expect(timeline.phase(at: minutes(60)) == .inEffect)
        // Between the earliest and latest end of the effects.
        #expect(timeline.phase(at: minutes(4 * 60)) == .wearingOff)
        #expect(timeline.phase(at: minutes(7 * 60)) == .afterEffects)
        // 6 h total + 48 h after effects = 54 h, and not a minute before.
        #expect(timeline.phase(at: minutes(53 * 60)) == .afterEffects)
        #expect(timeline.phase(at: minutes(55 * 60)) == .done)
    }

    /// The direction that matters: the outer edge of every range decides, so the
    /// app never says "done" while a published figure still covers the moment.
    @Test("Phases are read at the outer edge of every range")
    func phasesAreConservative() throws {
        let timeline = try #require(ComedownTimeline(substance: .alcohol, startedAt: start))
        // Alcohol: total 1.5–5 h. At four hours the shortest reading is long over.
        #expect(timeline.phase(at: minutes(4 * 60)) != .done)
        // After effects 6–48 h on top of a 5 h total: 53 h.
        #expect(timeline.isActive(at: minutes(52 * 60)))
        #expect(!timeline.isActive(at: minutes(54 * 60)))
    }

    /// Without a published after-effects window, the ladder has to skip the phase
    /// rather than stall in it.
    @Test("A substance with no after-effects window finishes at the end of the effects")
    func withoutAfterEffectsTheTimelineEndsEarlier() throws {
        let timeline = try #require(ComedownTimeline(substance: .cocaine, startedAt: start))
        #expect(timeline.phase(at: minutes(5)) == .comingUp)
        // Cocaine's total is 10–90 minutes.
        #expect(timeline.phase(at: minutes(30)) == .wearingOff)
        #expect(timeline.phase(at: minutes(91)) == .done)
    }

    // MARK: - Routes

    /// The bug this whole shape exists to prevent, in its comedown form: an
    /// edible's after-effects window is six to twelve hours and a joint's is
    /// three-quarters of an hour to three. One standing in for the other is the
    /// difference between planning a morning and writing one off.
    @Test("Cannabis routes carry different comedowns")
    func cannabisRoutesDiffer() throws {
        let smoked = try #require(ComedownTimeline(substance: .cannabis, route: .smoked, startedAt: start))
        let eaten = try #require(ComedownTimeline(substance: .cannabis, route: .oral, startedAt: start))
        let smokedEnd = try #require(smoked.afterEffectsEnd)
        let eatenEnd = try #require(eaten.afterEffectsEnd)
        #expect(eatenEnd > smokedEnd)
        #expect(eatenEnd.timeIntervalSince(smokedEnd) > 8 * 60 * 60)
    }

    /// An unmatched route must fall back to the longest curve on file, not the
    /// first or the shortest. Injected meth has no row here, and answering with
    /// the snorted curve would tell somebody it is over four hours early.
    @Test("An unknown route falls back to the longest published curve")
    func unmatchedRoutesFallBackConservatively() throws {
        let injected = try #require(
            ComedownTimeline(substance: .methamphetamine, route: nil, startedAt: start)
        )
        let oral = try #require(
            ComedownTimeline(substance: .methamphetamine, route: .oral, startedAt: start)
        )
        #expect(injected.lastPublishedMoment == oral.lastPublishedMoment)
    }

    @Test("Injection maps to no reference route rather than to the oral one")
    func injectionHasNoReferenceRoute() {
        #expect(AdministrationRoute.injected.referenceRoute == nil)
        #expect(AdministrationRoute.swallowed.referenceRoute == .oral)
        #expect(AdministrationRoute.sniffed.referenceRoute == .insufflated)
        #expect(AdministrationRoute.smoked.referenceRoute == .smoked)
    }

    // MARK: - Wording

    /// Every phase has to say something in the reader's language. An empty label
    /// is a blank row on the card, which reads as a bug rather than as silence.
    @Test("Every phase has a label and a detail", arguments: ComedownTimeline.Phase.allCases)
    func everyPhaseIsDescribed(phase: ComedownTimeline.Phase) {
        #expect(!phase.label.isEmpty)
        #expect(!phase.detail.isEmpty)
        #expect(!phase.symbolName.isEmpty)
    }
}
