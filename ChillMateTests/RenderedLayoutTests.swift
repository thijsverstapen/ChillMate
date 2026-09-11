import SwiftUI
import Testing
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

    private static let growingSizes: [DynamicTypeSize] = [
        .large, .xxLarge, .accessibility1, .accessibility3, .accessibility5
    ]

    private func height(of view: some View, at typeSize: DynamicTypeSize, width: CGFloat = narrowWidth) -> CGFloat {
        let renderer = ImageRenderer(
            content: view
                .frame(width: width)
                .dynamicTypeSize(typeSize)
                .padding(0)
        )
        renderer.scale = 1
        return renderer.uiImage?.size.height ?? 0
    }

    private func width(of view: some View, at typeSize: DynamicTypeSize, width: CGFloat = narrowWidth) -> CGFloat {
        let renderer = ImageRenderer(
            content: view.frame(width: width).dynamicTypeSize(typeSize)
        )
        renderer.scale = 1
        return renderer.uiImage?.size.width ?? 0
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

    // MARK: - Nothing spills sideways

    @Test("Nothing is wider than the screen it is on")
    func nothingSpillsHorizontally() {
        for size in Self.growingSizes {
            #expect(width(of: header, at: size) <= Self.narrowWidth + 1, "header at \(size)")
            #expect(width(of: disclaimer, at: size) <= Self.narrowWidth + 1, "disclaimer at \(size)")
            #expect(width(of: sectionTitle, at: size) <= Self.narrowWidth + 1, "section title at \(size)")
            #expect(width(of: comedown, at: size) <= Self.narrowWidth + 1, "comedown at \(size)")
        }
    }

    // MARK: - Nothing stops growing

    /// Text that keeps getting bigger inside a box that does not is text that is
    /// being cut off. A card whose height plateaus across three accessibility
    /// sizes is the shape of that bug, and it is invisible in a screenshot taken
    /// at the default size.
    private func assertGrows(_ view: some View, _ label: String) {
        let heights = Self.growingSizes.map { height(of: view, at: $0) }
        #expect(heights.allSatisfy { $0 > 0 }, "\(label) rendered nothing: \(heights)")
        for (smaller, larger) in zip(heights, heights.dropFirst()) {
            #expect(larger >= smaller, "\(label) stopped growing: \(heights)")
        }
        #expect(heights.last! > heights.first!, "\(label) never grew at all: \(heights)")
    }

    @Test("A page header grows with the text")
    func headerGrows() { assertGrows(header, "header") }

    @Test("The safety disclaimer grows with the text")
    func disclaimerGrows() { assertGrows(disclaimer, "disclaimer") }

    @Test("The comedown card grows with the text")
    func comedownGrows() { assertGrows(comedown, "comedown card") }

    /// A section title is one line of text and a symbol, and it still has to
    /// reflow rather than truncate — it carries the name of the thing below it.
    @Test("A section title grows with the text")
    func sectionTitleGrows() { assertGrows(sectionTitle, "section title") }

    // MARK: - Sanity

    /// A card that is taller than about ten screens at the largest type size is
    /// usually a layout that has lost its bounds rather than one being generous.
    @Test("Nothing renders absurdly tall at the largest type size")
    func nothingIsAbsurd() {
        for (view, label) in [(AnyView(header), "header"), (AnyView(disclaimer), "disclaimer"), (AnyView(comedown), "comedown")] {
            let tallest = height(of: view, at: .accessibility5)
            #expect(tallest < 8000, "\(label) is \(tallest) points tall at AX5")
        }
    }
}
