import SwiftUI

/// Whether decorative motion should be suppressed, combining the system's
/// Reduce Motion switch with ChillMate's own accessibility toggle.
///
/// The in-app `chillReducedMotion` setting was advertised in Settings →
/// Accessibility but read in exactly one place: the onboarding flow in
/// ProfileSetupView. Everything else animated regardless — the breathing orb, the
/// craving-delay countdown that animates for ten unbroken minutes, the per-minute
/// PEP countdown, every glass transition, and the entire watch app. The setting
/// looked like an accommodation and behaved like a decoration.
///
/// Reading it through the environment means a view opts in by declaring
/// `@Environment(\.chillReduceMotion)` and cannot silently miss the AppStorage key.
/// The value is injected once at the app root.
///
/// This is the population that most needs the accommodation: people mid-comedown,
/// overstimulated, or anxious.
private struct ChillReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var chillReduceMotion: Bool {
        get { self[ChillReduceMotionKey.self] }
        set { self[ChillReduceMotionKey.self] = newValue }
    }
}

/// Injects the combined preference and keeps it current.
///
/// Applied once at the root so every descendant — including sheets and
/// `fullScreenCover` content, which inherit the environment — sees it.
struct ChillMotionPreferenceModifier: ViewModifier {
    @AppStorage(DefaultsKey.chillReducedMotion) private var chillReducedMotion = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    func body(content: Content) -> some View {
        content.environment(\.chillReduceMotion, systemReduceMotion || chillReducedMotion)
    }
}

/// Applies a tuned point size that still grows with Dynamic Type.
///
/// `.font(.system(size:))` is frozen: at the larger accessibility sizes the text
/// keeps its design size, and the layout copes by clipping or by leaning on
/// `minimumScaleFactor` to shrink it *further* — the opposite of what the user
/// asked for. `@ScaledMetric` keeps the tuned size at the default Dynamic Type
/// setting and scales from there, relative to the given text style.
///
/// Intended for text. SF Symbols drawn inside a fixed `.frame` legitimately keep
/// `.system(size:)`, since scaling the glyph without its frame just clips it.
struct ChillScaledFont: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, relativeTo textStyle: Font.TextStyle, design: Font.Design) {
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize, weight: weight, design: design))
    }
}

extension View {
    /// Dynamic-Type-aware replacement for `.font(.system(size:weight:design:))`.
    func chillScaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle = .body,
        design: Font.Design = .default
    ) -> some View {
        modifier(ChillScaledFont(size: size, weight: weight, relativeTo: textStyle, design: design))
    }
}

extension View {
    /// Publishes the combined reduce-motion preference to this subtree.
    func chillMotionPreference() -> some View {
        modifier(ChillMotionPreferenceModifier())
    }

    /// Applies `animation` only when motion is allowed.
    ///
    /// Use for decorative animation. Animation that carries meaning (a countdown
    /// advancing, a value changing) should stay, only without the flourish.
    func chillAnimation<V: Equatable>(
        _ animation: Animation?,
        value: V,
        reduceMotion: Bool
    ) -> some View {
        self.animation(reduceMotion ? nil : animation, value: value)
    }
}
