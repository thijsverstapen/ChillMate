import SwiftUI

/// Where a dose is on its published curve, including the part that lands on
/// tomorrow.
///
/// Shown against a running or finished check-in timer, which is the one place in
/// the app that knows both what was taken and when. The timer itself answers "how
/// long until I check in"; this answers "how long is this actually going on for",
/// which is a different question and the one people get wrong.
///
/// Nothing here is computed for the individual. Every boundary comes from
/// `SubstanceReference`, the ranges are read at their outer edge, and the card
/// says whose figures they are.
struct ComedownPhaseCard: View {
    let timeline: ComedownTimeline
    let now: Date

    private var phase: ComedownTimeline.Phase {
        timeline.phase(at: now)
    }

    private var tint: Color {
        switch phase {
        case .comingUp: Color.chillSecondaryBlue
        case .inEffect: Color.chillPrimary
        case .wearingOff: .orange
        case .afterEffects: Color.chillAccentTeal
        case .done: Color.chillSecondary
        }
    }

    /// A clock time for today and a date for anything further out. An
    /// after-effects window measured in days is the whole point of this card, so
    /// "until 14:00" with no day attached would be the one detail that undoes it.
    private func moment(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if Calendar.current.isDateInTomorrow(date) {
            return String(localized: "tomorrow \(date.formatted(date: .omitted, time: .shortened))")
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(phase.label, systemImage: phase.symbolName)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)

            Text(phase.detail)
                .font(.caption)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            PhaseTrack(timeline: timeline, now: now, tint: tint)

            if let end = timeline.afterEffectsEnd {
                Text("After effects reported until about \(moment(end)).")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let note = timeline.note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let source = timeline.afterEffectsSourceName {
                Text("After-effects figures: \(source)")
                    .font(.caption2)
                    .foregroundStyle(Color.chillSecondary.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassSurface(radius: 18, tint: tint.opacity(0.08))
        .accessibilityElement(children: .combine)
    }
}

/// The four phases as a bar, with the reached ones filled.
///
/// Deliberately not a moving needle against real time. The boundaries are ranges
/// several hours wide, and drawing a precise position along them would claim an
/// accuracy the figures do not have.
private struct PhaseTrack: View {
    let timeline: ComedownTimeline
    let now: Date
    let tint: Color

    private var phases: [ComedownTimeline.Phase] {
        timeline.afterEffectsEnd == nil
            ? [.comingUp, .inEffect, .wearingOff]
            : [.comingUp, .inEffect, .wearingOff, .afterEffects]
    }

    private var reachedIndex: Int {
        let current = timeline.phase(at: now)
        if current == .done { return phases.count }
        return phases.firstIndex(of: current) ?? 0
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(phases.enumerated()), id: \.offset) { index, _ in
                Capsule()
                    .fill(index <= reachedIndex ? tint.opacity(0.85) : tint.opacity(0.16))
                    .frame(height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}
