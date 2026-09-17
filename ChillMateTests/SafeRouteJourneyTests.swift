import Foundation
import Testing
@testable import ChillMate

/// The journey home check-in.
///
/// The Live Activity itself cannot be exercised here — ActivityKit needs a real
/// device session — so what is tested is the part that decides what it says, and
/// the part that decides whether it says anything at all.
@Suite("Safe route journey")
struct SafeRouteJourneyTests {

    private let expected = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func state(arrivedAt: Date? = nil) -> SafeRouteActivityAttributes.ContentState {
        SafeRouteActivityAttributes.ContentState(expectedArrival: expected, arrivedAt: arrivedAt)
    }

    /// The whole feature in one rule: the time passed and nobody said anything.
    @Test("Overdue is the expected time passing with no arrival marked")
    func overdueRule() {
        #expect(!state().isOverdue(at: expected.addingTimeInterval(-60)))
        #expect(state().isOverdue(at: expected.addingTimeInterval(60)))
    }

    /// Saying you are home has to survive the clock. Somebody who marks arrival
    /// early and then sits on the bus must not have the Lock Screen turn orange
    /// behind them and a notification arrive asking where they are.
    @Test("An arrival that has been marked never goes overdue")
    func arrivalWins() {
        let arrived = state(arrivedAt: expected.addingTimeInterval(-600))
        #expect(!arrived.isOverdue(at: expected.addingTimeInterval(3600)))
    }

    /// A default outside the picker's options draws a segmented control with
    /// nothing selected, and the first tap then looks like it changed something
    /// that was already set.
    @Test("The default duration is one of the options")
    func defaultIsSelectable() {
        #expect(SafeRouteReminder.selectableMinutes.contains(SafeRouteReminder.defaultMinutes))
    }

    @Test("The options are ordered and positive")
    func optionsAreSane() {
        #expect(SafeRouteReminder.selectableMinutes.allSatisfy { $0 > 0 })
        #expect(SafeRouteReminder.selectableMinutes == SafeRouteReminder.selectableMinutes.sorted())
    }

    /// The Lock Screen is readable by whoever is standing next to you. Nothing in
    /// the activity's payload may say where somebody lives or is going — this is
    /// the same reasoning behind the panic hide and the duress PIN, and it is
    /// enforced here because a later "it would be nicer with the destination on
    /// it" is exactly how it would get added.
    @Test("The activity payload carries no destination")
    func noDestinationCrossesToTheLockScreen() throws {
        let encoded = try JSONEncoder().encode(state())
        let fields = try #require(
            try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        #expect(Set(fields.keys) == ["expectedArrival"])

        let arrivedFields = try #require(
            try JSONSerialization.jsonObject(
                with: try JSONEncoder().encode(state(arrivedAt: expected))
            ) as? [String: Any]
        )
        #expect(Set(arrivedFields.keys) == ["expectedArrival", "arrivedAt"])
    }
}
