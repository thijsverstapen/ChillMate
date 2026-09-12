import Foundation
import Testing
@testable import ChillMate

/// The Live Activity's payload, which crosses a version boundary.
///
/// A Live Activity outlives the app update that changes it: one started on
/// Tuesday is still on the Lock Screen when the user installs Wednesday's build,
/// and the running system decodes the old `ContentState` with the new type. That
/// is why `startedAt` is optional and why adding a non-optional field here would
/// be a bug rather than a refactor.
///
/// The extension itself cannot be unit tested — it has no test host and its views
/// need an `ActivityViewContext` only ActivityKit can make — so what is tested is
/// the contract between the two ends, which is where the breakage would be.
@Suite("Drug timer Live Activity payload")
struct DrugTimerActivityTests {

    private static let started = Date(timeIntervalSince1970: 1_757_500_000)
    private static let ends = started.addingTimeInterval(4 * 3600)

    private static func state(startedAt: Date?) -> DrugTimerActivityAttributes.ContentState {
        DrugTimerActivityAttributes.ContentState(
            substanceName: "GHB",
            endsAt: ends,
            redoseNudgeActive: false,
            startedAt: startedAt
        )
    }

    @Test("A state survives a round trip unchanged")
    func roundTrips() throws {
        let original = Self.state(startedAt: Self.started)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DrugTimerActivityAttributes.ContentState.self, from: data)
        #expect(decoded == original)
    }

    /// The compatibility case, written as the payload an older build actually
    /// produced: no `startedAt` key at all.
    @Test("A payload from before startedAt existed still decodes")
    func decodesPayloadWithoutStartedAt() throws {
        let legacy = """
        {"substanceName":"GHB","endsAt":\(Self.ends.timeIntervalSinceReferenceDate),"redoseNudgeActive":true}
        """
        let decoded = try JSONDecoder().decode(
            DrugTimerActivityAttributes.ContentState.self,
            from: Data(legacy.utf8)
        )

        #expect(decoded.substanceName == "GHB")
        #expect(decoded.redoseNudgeActive)
        #expect(decoded.startedAt == nil, "a missing startedAt must decode as nil, not fail")
    }

    /// What the progress bar asks before it draws. Nil is the older-build case and
    /// an inverted range is a clock change or a corrupted timer; both must fall
    /// back to the plain countdown rather than draw something nonsensical.
    @Test("The progress bar only draws for a range that runs forwards", arguments: [
        (Date?.none, false),
        (Date?.some(Self.ends.addingTimeInterval(3600)), false),
        (Date?.some(Self.ends), false),
        (Date?.some(Self.started), true),
    ])
    func progressIsDrawnOnlyForForwardRanges(startedAt: Date?, expected: Bool) {
        let state = Self.state(startedAt: startedAt)
        let canDraw = state.startedAt.map { $0 < state.endsAt } ?? false
        #expect(canDraw == expected)
    }

    @Test("Attributes keep the timer they were made for")
    func attributesCarryTheTimerIdentity() {
        let id = UUID()
        let attributes = DrugTimerActivityAttributes(timerID: id, substanceName: "Ketamine")
        #expect(attributes.timerID == id)
        #expect(attributes.substanceName == "Ketamine")
    }

    /// The redose nudge is the only thing that changes the activity's colour and
    /// its wording, so it has to survive the encoding that carries it.
    @Test("The redose nudge flag survives encoding")
    func redoseFlagSurvives() throws {
        for active in [true, false] {
            let original = DrugTimerActivityAttributes.ContentState(
                substanceName: "MDMA",
                endsAt: Self.ends,
                redoseNudgeActive: active,
                startedAt: Self.started
            )
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(DrugTimerActivityAttributes.ContentState.self, from: data)
            #expect(decoded.redoseNudgeActive == active)
        }
    }
}
