import SwiftUI
import Testing
import ChillMateCore
@testable import ChillMate

/// Snapshot tests that snapshot the *layout* rather than the pixels.
///
/// Pixel baselines were the obvious way to do this and the wrong one here. A
/// reference PNG goes stale on an OS bump, a font metric change or a new device
/// idiom, so it fails for reasons that have nothing to do with the change under
/// test — and the project carries no third-party dependencies at all, which is
/// not an accident in an app whose pitch is that nothing leaves the device.
///
/// What is asserted instead is what actually goes wrong: a card that spills past
/// the screen, or one that *stops growing* as the text gets bigger, which is what
/// clipping looks like from the outside.
///
/// The real leverage is that CI runs this suite once per shipped language. German
/// is reliably the longest of the five and Dutch is close behind, so a
/// translation that breaks a card fails here rather than in a screenshot somebody
/// takes three weeks later.
@MainActor
@Suite("Rendered layout")
struct RenderedLayoutTests {

    /// The narrowest iPhone ChillMate supports, because that is where text runs
    /// out of room first.
    private static let narrowWidth: CGFloat = 320

    /// Three points on the ladder, not five.
    ///
    /// Rendering is the expensive part of this suite — a `ImageRenderer` pass is
    /// most of a second — and the suite runs five times, once per language. Three
    /// points still prove monotonic growth and still span the whole range; five
    /// cost four minutes of CI to prove the same thing.
    private static let growingSizes: [DynamicTypeSize] = [.large, .accessibility1, .accessibility5]

    /// One render per size, not two.
    ///
    /// Width and height were asked for separately, which rendered every component
    /// at every size twice over.
    private func size(of view: some View, at typeSize: DynamicTypeSize) -> CGSize {
        let renderer = ImageRenderer(
            content: view
                .frame(width: Self.narrowWidth)
                .dynamicTypeSize(typeSize)
        )
        renderer.scale = 1
        return renderer.uiImage?.size ?? .zero
    }

    /// Everything this suite asserts about one component, in a single pass over
    /// the type sizes.
    private func check(_ view: some View, _ label: String) {
        let sizes = Self.growingSizes.map { size(of: view, at: $0) }

        #expect(sizes.allSatisfy { $0.height > 0 }, "\(label) rendered nothing: \(sizes)")

        // Nothing spills sideways.
        for (size, typeSize) in zip(sizes, Self.growingSizes) {
            #expect(
                size.width <= Self.narrowWidth + 1,
                "\(label) is \(size.width)pt wide at \(typeSize)"
            )
        }

        // Text that keeps getting bigger inside a box that does not is text that
        // is being cut off. A height that plateaus across the ladder is the shape
        // of that bug, and it is invisible in a screenshot at the default size.
        for (smaller, larger) in zip(sizes, sizes.dropFirst()) {
            #expect(larger.height >= smaller.height, "\(label) stopped growing: \(sizes.map(\.height))")
        }
        #expect(sizes.last!.height > sizes.first!.height, "\(label) never grew at all: \(sizes.map(\.height))")

        // A component taller than about ten screens at the largest type size is
        // usually a layout that has lost its bounds rather than a generous one.
        #expect(sizes.last!.height < 8000, "\(label) is \(sizes.last!.height)pt tall at AX5")
    }

    // MARK: - The components under test

    private var header: some View {
        PageHeader(
            title: String(localized: "Safe route home"),
            subtitle: String(localized: "Plan transport, share where you are, or open a get-me-home flow quickly. Search an address, choose transit, driving, or cycling, then open Maps or message your trusted contact."),
            symbol: "location.fill",
            tint: Color.chillMint
        )
    }

    private var disclaimer: some View {
        MedicalSafetyDisclaimerCard(compact: false)
    }

    private var sectionTitle: some View {
        CareSectionTitle(title: String(localized: "Current and past check-ins"), symbol: "clock.arrow.circlepath")
    }

    private var comedown: some View {
        // MDMA has the longest published after-effects window and the only
        // comedown note, so it is the tallest this card ever gets.
        ComedownPhaseCard(
            timeline: ComedownTimeline(substance: .mdma, startedAt: .now.addingTimeInterval(-8 * 3600))!,
            now: .now
        )
    }

    // MARK: - The components

    @Test("A page header fits and grows")
    func headerIsSound() { check(header, "page header") }

    @Test("The safety disclaimer fits and grows")
    func disclaimerIsSound() { check(disclaimer, "safety disclaimer") }

    /// A section title is one line of text and a symbol, and it still has to
    /// reflow rather than truncate: it carries the name of the thing below it.
    @Test("A section title fits and grows")
    func sectionTitleIsSound() { check(sectionTitle, "section title") }

    @Test("The comedown card fits and grows")
    func comedownIsSound() { check(comedown, "comedown card") }

}
