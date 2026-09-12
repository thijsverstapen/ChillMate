import Foundation

/// Where a dose is on its curve, including the half of the curve that used to be
/// missing.
///
/// ChillMate already showed onset, peak and total duration. All three describe the
/// part of the night somebody is awake for and paying attention to. The part they
/// are not paying attention to is the next day, and that is where most of the
/// avoidable damage to a week actually happens: a session planned around a
/// six-hour total, and then a Tuesday nobody connected to the Saturday.
///
/// Every figure here is `SubstanceReference`'s, which is PsychonautWiki's. Nothing
/// in this type invents a duration, and where a source publishes no after-effects
/// window there is no window — `afterEffects` is nil and the screen says the
/// source is silent rather than filling the gap with a guess.
///
/// The boundaries are deliberately read at their *outer* edge. A dose is "still
/// working" until the longest published figure has passed, never the shortest.
/// Being told you are done when you might not be is the error that matters; being
/// told you might still be feeling it when you are not costs nothing.
public struct ComedownTimeline: Equatable, Sendable {

    /// The phase a dose is in, read conservatively.
    public enum Phase: String, Equatable, Sendable, CaseIterable {
        /// Taken, possibly not arrived. The window in which a second dose gets
        /// taken because the first "isn't working".
        case comingUp
        /// Up and running.
        case inEffect
        /// Inside the window where the published total runs out.
        case wearingOff
        /// The effects are over and the source still reports after-effects.
        case afterEffects
        /// Past every published figure.
        case done
    }

    public let substance: Substance
    public let route: SubstanceReference.Route?
    public let startedAt: Date

    /// Earliest and latest the effects are reported to arrive.
    public let onset: ClosedRange<Date>
    /// Earliest and latest the effects are reported to peak.
    public let peak: ClosedRange<Date>
    /// Earliest and latest the effects themselves are reported to be over.
    public let over: ClosedRange<Date>
    /// When after-effects can still be running until, or nil where the source
    /// publishes no window for this substance.
    public let afterEffectsEnd: Date?

    /// What the source says about this comedown in words, where it says anything.
    public let note: String?

    /// Who to credit for the after-effects figure — not always who to credit for
    /// the dose ladder.
    public let afterEffectsSourceName: String?

    /// Builds a timeline, or nil when nothing is published for this substance.
    ///
    /// - Parameters:
    ///   - substance: what was taken.
    ///   - route: how, where that is known. A route with no published figures
    ///     falls back to the longest timing on file rather than to nothing, because
    ///     a conservative answer beats no answer here.
    ///   - startedAt: when the dose was taken.
    public init?(substance: Substance, route: SubstanceReference.Route? = nil, startedAt: Date) {
        guard let reference = substance.reference,
              let timing = reference.timing(for: route) else { return nil }

        self.substance = substance
        self.route = timing.route
        self.startedAt = startedAt

        func offset(_ minutes: Double) -> Date {
            startedAt.addingTimeInterval(minutes * 60)
        }

        onset = offset(timing.onset.lowerBound)...offset(timing.onset.upperBound)
        peak = offset(timing.peak.lowerBound)...offset(timing.peak.upperBound)
        over = offset(timing.total.lowerBound)...offset(timing.total.upperBound)
        afterEffectsEnd = timing.afterEffectsEndFromDose.map(offset)
        note = reference.comedownNote
        afterEffectsSourceName = timing.afterEffects == nil
            ? nil
            : (reference.afterEffectsSource ?? reference.source).name
    }

    /// The phase at a given moment, read at the outer edge of every range.
    public func phase(at now: Date) -> Phase {
        if now < onset.upperBound { return .comingUp }
        if now < over.lowerBound { return .inEffect }
        if now < over.upperBound { return .wearingOff }
        if let afterEffectsEnd, now < afterEffectsEnd { return .afterEffects }
        return .done
    }

    /// Whether anything published is still running.
    public func isActive(at now: Date) -> Bool {
        phase(at: now) != .done
    }

    /// The last moment any published figure covers.
    public var lastPublishedMoment: Date {
        afterEffectsEnd ?? over.upperBound
    }
}

extension ComedownTimeline.Phase {

    /// A short name for the phase, for a row that also carries the times.
    public var label: String {
        switch self {
        case .comingUp: String(localized: "Coming up", bundle: .main)
        case .inEffect: String(localized: "In effect", bundle: .main)
        case .wearingOff: String(localized: "Wearing off", bundle: .main)
        case .afterEffects: String(localized: "After effects", bundle: .main)
        case .done: String(localized: "Past the published window", bundle: .main)
        }
    }

    /// What the phase means for the person in it.
    ///
    /// These describe the published figures and stop there. None of them tells
    /// anybody what to take, and none of them promises how they will feel.
    public var detail: String {
        switch self {
        case .comingUp:
            String(localized: "It may not have arrived yet. This is the window where a second dose gets taken because the first seems not to be working.", bundle: .main)
        case .inEffect:
            String(localized: "Inside the reported window for the effects themselves.", bundle: .main)
        case .wearingOff:
            String(localized: "Around the point the reported effects run out. Anything after this is the comedown, not the dose.", bundle: .main)
        case .afterEffects:
            String(localized: "The effects are reported to be over and the after-effects are not. This is the part that lands on tomorrow.", bundle: .main)
        case .done:
            String(localized: "Past every figure published for this. That is about the reported window, not about how you actually feel.", bundle: .main)
        }
    }

    public var symbolName: String {
        switch self {
        case .comingUp: "arrow.up.circle.fill"
        case .inEffect: "waveform.path.ecg"
        case .wearingOff: "arrow.down.circle.fill"
        case .afterEffects: "moon.zzz.fill"
        case .done: "checkmark.circle.fill"
        }
    }
}

extension SubstanceReference {

    /// The timing that applies to a route.
    ///
    /// Exact match first, then a route-independent row, then the longest total on
    /// file. The last fallback is the conservative one on purpose: a substance
    /// logged as injected has no published row here, and answering with the
    /// shortest curve would tell somebody it is over when the figures do not say
    /// that.
    public func timing(for route: Route?) -> Timing? {
        if let route, let exact = timings.first(where: { $0.route == route }) {
            return exact
        }
        if let shared = timings.first(where: { $0.route == nil }) {
            return shared
        }
        return timings.max { $0.total.upperBound < $1.total.upperBound }
    }
}
