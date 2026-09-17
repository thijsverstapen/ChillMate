import CoreMotion
import SwiftUI

/// The animated first-run introduction.
///
/// The largest single thing in the old `ProfileSetupView.swift` and the least
/// related to it: a parallax scene, a wordmark, a morphing hero and the pages
/// that carry them. Split out unchanged.

/// Publishes a gently low-passed device tilt so the intro atmosphere can drift with
/// the phone, adding depth on top of the finger-follow parallax. Simulator reports no
/// device motion, so this reads as a harmless zero there. Gated behind Reduce Motion
/// by the caller (updates are never started when motion is off).
@MainActor
@Observable
private final class MotionTilt {
    var x: CGFloat = 0
    var y: CGFloat = 0
    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let targetX = max(-0.6, min(0.6, CGFloat(motion.attitude.roll)))
            let targetY = max(-0.6, min(0.6, CGFloat(motion.attitude.pitch - 0.6)))
            // Low-pass to kill jitter without per-frame animation transactions.
            self.x = self.x * 0.86 + targetX * 0.14
            self.y = self.y * 0.86 + targetY * 0.14
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }
}

/// No longer `private`: the profile wizard presents this and now lives in
/// another file. Everything it is built from stays private to this one.
@MainActor
struct ProfileIntroductionView: View {
    @State private var delays = DelayedActionRunner()
    let continueAction: () -> Void
    @State private var activePage = 0
    @State private var isCompleting = false
    @State private var dragX: CGFloat = 0
    @State private var nudge: CGFloat = 0
    @State private var containerWidth: CGFloat = 1
    @State private var tilt = MotionTilt()
    @Environment(\.accessibilityReduceMotion) private var reduceSystemMotion
    @AppStorage(DefaultsKey.chillReducedMotion) private var chillReducedMotion = false
    @AppStorage(DefaultsKey.onboardingSwipeHintShown) private var swipeHintShown = false

    private let pages = IntroPage.all
    private var currentPage: IntroPage {
        guard activePage < pages.count else { return IntroPage.fallback }
        return pages[activePage]
    }
    private var motionOff: Bool { reduceSystemMotion || chillReducedMotion }

    // Drag-coupled morph: which neighbour the finger is pulling toward, and how far.
    private var dragDirection: Int {
        if dragX < 0 { return 1 }        // dragging left → next slide
        if dragX > 0 { return -1 }       // dragging right → previous slide
        return 0
    }
    private var neighborIndex: Int { activePage + dragDirection }
    private var hasNeighbor: Bool { neighborIndex >= 0 && neighborIndex < pages.count }
    private var neighborKind: IntroAnimationKind {
        hasNeighbor ? pages[neighborIndex].animation : currentPage.animation
    }
    private var morphT: CGFloat {
        guard hasNeighbor else { return 0 }
        return min(1, abs(dragX) / max(containerWidth, 1) * 1.3)
    }
    // Resist at the ends (rubber-band) and fold in the one-time swipe nudge.
    private var effectiveParallax: CGFloat {
        (hasNeighbor ? dragX : dragX * 0.3) + nudge
    }

    var body: some View {
        ZStack {
            IntroRootBackground(kind: currentPage.animation)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.54), value: currentPage.animation)

            IntroSlideView(
                page: currentPage,
                index: activePage,
                isCompleting: isCompleting,
                parallax: effectiveParallax,
                activeKind: currentPage.animation,
                neighborKind: neighborKind,
                morphT: morphT,
                tiltX: motionOff ? 0 : tilt.x,
                tiltY: motionOff ? 0 : tilt.y,
                showSkip: activePage < pages.count - 1 && !isCompleting,
                onSkip: finish
            )
            .ignoresSafeArea()
            .scaleEffect(isCompleting ? 1.09 : 1)
            .blur(radius: isCompleting ? 12 : 0)
            .opacity(isCompleting ? 0.12 : 1)
            .animation(.easeInOut(duration: 0.44), value: isCompleting)

            IntroBottomControls(
                index: activePage,
                count: pages.count,
                isCompleting: isCompleting,
                actionTitle: activePage == pages.count - 1 ? String(localized: "Set up my profile") : String(localized: "Next"),
                action: advance
            )
            .opacity(isCompleting ? 0 : 1)
            .offset(y: isCompleting ? 24 : 0)
            .animation(.easeInOut(duration: 0.28), value: isCompleting)
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { containerWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newWidth in containerWidth = newWidth }
            }
        )
        .gesture(
            DragGesture(minimumDistance: 18)
                .onChanged { val in
                    dragX = val.translation.width
                }
                .onEnded { val in
                    let width = val.translation.width
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.90)) { dragX = 0 }
                    if width < -60 { advance() }
                    else if width > 60 { goBack() }
                }
        )
        .sensoryFeedback(.impact(weight: .light), trigger: activePage)
        .sensoryFeedback(trigger: isCompleting) { _, completing in
            completing ? .impact(weight: .heavy) : nil
        }
        .onAppear {
            if !motionOff { tilt.start() }
            armSwipeHint()
        }
        .onDisappear { tilt.stop() }
    }

    // One-time nudge on first launch: the slide drifts a few points and springs back,
    // signalling that it can be swiped. Reuses the parallax channel so hero, text, and
    // atmosphere all lean together, exactly like a real drag.
    private func armSwipeHint() {
        guard !swipeHintShown, !motionOff else { return }
        swipeHintShown = true
        delays.run(after: .milliseconds(1100), skipDelayWhenReducingMotion: false) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { nudge = -24 }
            delays.run(after: .milliseconds(440), skipDelayWhenReducingMotion: false) {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.7)) { nudge = 0 }
            }
        }
    }

    private func advance() {
        if activePage == pages.count - 1 {
            finish()
        } else {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.88)) { activePage += 1 }
        }
    }

    private func finish() {
        guard !isCompleting else { return }
        withAnimation(.spring(response: 0.56, dampingFraction: 0.82)) { isCompleting = true }
        delays.run(after: .milliseconds(500), reduceMotion: motionOff) { continueAction() }
    }

    private func goBack() {
        guard activePage > 0 else { return }
        withAnimation(.spring(response: 0.44, dampingFraction: 0.88)) { activePage -= 1 }
    }
}

private struct IntroBottomControls: View {
    @State private var delays = DelayedActionRunner()
    let index: Int
    let count: Int
    let isCompleting: Bool
    let actionTitle: String
    let action: () -> Void
    @State private var shimmerPhase: CGFloat = -0.4
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceSystemMotion
    @AppStorage(DefaultsKey.chillReducedMotion) private var chillReducedMotion = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            OnboardingProgress(index: index, count: count)

            Button {
                if !(reduceSystemMotion || chillReducedMotion) {
                    withAnimation(.spring(response: 0.20, dampingFraction: 0.68)) { isPressed = true }
                    delays.run(after: .milliseconds(140), skipDelayWhenReducingMotion: false) {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) { isPressed = false }
                    }
                }
                action()
            } label: {
                ZStack {
                    HStack(spacing: 10) {
                        Text(actionTitle)
                            .font(.headline.weight(.bold))
                        Image(systemName: index == count - 1 ? "person.crop.circle.badge.checkmark" : "arrow.right")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)

                    // Shimmer sweep
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: shimmerPhase - 0.18),
                            .init(color: .white.opacity(0.22), location: shimmerPhase),
                            .init(color: .clear, location: shimmerPhase + 0.18),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(LinearGradient.chillBrand, in: Capsule())
                .overlay { Capsule().stroke(.white.opacity(0.36), lineWidth: 1) }
                .shadow(color: Color.chillPrimary.opacity(0.50), radius: 24, x: 0, y: 14)
                .scaleEffect(isPressed ? 0.96 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.74), value: isPressed)
            }
            .buttonStyle(ChillPlainButtonStyle())
            .disabled(isCompleting)
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
            .onAppear {
                // Gate the endless shimmer sweep behind Reduce Motion, like the rest
                // of the intro. Left off, shimmerPhase stays parked off-screen left.
                guard !reduceSystemMotion, !chillReducedMotion else { return }
                withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false).delay(1.0)) {
                    shimmerPhase = 1.4
                }
            }
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }
}

private struct OnboardingProgress: View {
    let index: Int
    let count: Int

    // A thin bar that fills as you move through the intro, with faint ticks marking
    // each screen so the length reads at a glance ("four short screens").
    var body: some View {
        let fraction = CGFloat(index + 1) / CGFloat(max(count, 1))
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.16))
                    .frame(height: 5)

                Capsule()
                    .fill(LinearGradient.chillBrand)
                    .frame(width: max(14, width * fraction), height: 5)
                    .shadow(color: Color.chillPrimary.opacity(0.55), radius: 8)

                if count > 1 {
                    HStack(spacing: 0) {
                        ForEach(1..<count, id: \.self) { _ in
                            Spacer(minLength: 0)
                            Rectangle()
                                .fill(Color.chillDarkBackground.opacity(0.55))
                                .frame(width: 2, height: 5)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(height: 5)
        .frame(maxWidth: 210)
        .animation(.spring(response: 0.44, dampingFraction: 0.82), value: index)
        .accessibilityLabel("Onboarding page \(index + 1) of \(count)")
    }
}

private struct IntroPage {
    let eyebrow: String
    let title: String
    let subtitle: String
    let animation: IntroAnimationKind

    static let fallback = IntroPage(
        eyebrow: String(localized: "Track privately"),
        title: String(localized: "Your last 3 months, in one\u{00A0}place"),
        subtitle: String(localized: "Log the parts you want to remember, like sleep, substances, and aftercare. Then see your Chills, patterns, and wellbeing score in one private overview."),
        animation: .summary
    )

    static let all = [
        IntroPage(
            eyebrow: String(localized: "Welcome"),
            title: String(localized: "Welcome to ChillMate"),
            subtitle: String(localized: "A calm, private space to track Chills, stay safer, and recover softer. Let's set it up together."),
            animation: .welcome
        ),
        fallback,
        IntroPage(
            eyebrow: String(localized: "Your tools"),
            title: String(localized: "Grouped by the moment"),
            subtitle: String(localized: "Everything sits under four moments: plan before you go, stay safe while you’re out, check in with aftercare and health, then see your patterns. The one you need rises to the top."),
            animation: .care
        ),
        IntroPage(
            eyebrow: String(localized: "Private and honest"),
            title: String(localized: "Private, locked, and honest"),
            subtitle: String(localized: "Lock ChillMate with Face ID or a PIN, keep everything encrypted on this iPhone, and hide the screen in one tap. It offers reflection and safety information from verified sources. It is not medical advice."),
            animation: .privacy
        )
    ]
}

private enum IntroAnimationKind {
    case welcome
    case summary
    case log
    case care
    case privacy
    case notice
    case ready
}

@MainActor
private struct IntroSlideView: View {
    @State private var delays = DelayedActionRunner()
    let page: IntroPage
    let index: Int
    let isCompleting: Bool
    var parallax: CGFloat = 0
    var activeKind: IntroAnimationKind = .welcome
    var neighborKind: IntroAnimationKind = .welcome
    var morphT: CGFloat = 0
    var tiltX: CGFloat = 0
    var tiltY: CGFloat = 0
    var showSkip: Bool = false
    var onSkip: (() -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceSystemMotion
    @AppStorage(DefaultsKey.chillReducedMotion) private var chillReducedMotion = false
    @State private var checkmarkInPlace = false
    @State private var textVisible = false

    var body: some View {
        GeometryReader { proxy in
            let topPadding = max(proxy.safeAreaInsets.top + 16, 58)
            let heroHeight = min(max(proxy.size.height * 0.32, 220), 310)

            TimelineView(.animation) { ctx in
                let rawPhase = ctx.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: .pi * 2)
                let phase = (reduceSystemMotion || chillReducedMotion) ? 0.22 : rawPhase
                // Finger-following parallax: far layers move least, near layers most.
                let pOffset: CGFloat = (reduceSystemMotion || chillReducedMotion) ? 0 : parallax

                ZStack {
                    IntroAtmosphere(kind: page.animation, index: index, phase: phase)
                        .ignoresSafeArea()
                        .offset(x: pOffset * 0.05 + tiltX * 26, y: tiltY * 20)

                    VStack(alignment: .leading, spacing: 0) {
                        OnboardingTopBar(
                            checkmarkInPlace: checkmarkInPlace || isCompleting,
                            showSkip: showSkip,
                            onSkip: onSkip
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, topPadding)

                        Spacer(minLength: 14)

                        MorphingIntroHero(
                            activeKind: activeKind,
                            neighborKind: neighborKind,
                            morphT: morphT,
                            phase: phase,
                            isCompleting: isCompleting,
                            checkmarkInPlace: checkmarkInPlace || isCompleting
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: heroHeight)
                        .scaleEffect(isCompleting ? 1.16 : 1)
                        .blur(radius: isCompleting ? 6 : 0)
                        .animation(.spring(response: 0.56, dampingFraction: 0.76), value: isCompleting)
                        .offset(x: pOffset * 0.16 + tiltX * 10, y: tiltY * 8)

                        Spacer(minLength: 28)

                        IntroTextBlock(page: page, isVisible: textVisible)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 196)
                            .offset(x: pOffset * 0.10)
                    }
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear { armEntrance() }
        .onChange(of: index) { _, _ in armEntrance() }
    }

    private func armEntrance() {
        textVisible = false
        checkmarkInPlace = false
        delays.run(after: .milliseconds(60), skipDelayWhenReducingMotion: false) {
            withAnimation(.spring(response: 0.58, dampingFraction: 0.80)) { textVisible = true }
        }
        delays.run(after: .milliseconds(160), skipDelayWhenReducingMotion: false) {
            withAnimation(.spring(response: 0.70, dampingFraction: 0.62)) { checkmarkInPlace = true }
        }
    }
}

private struct OnboardingTopBar: View {
    let checkmarkInPlace: Bool
    var showSkip: Bool = false
    var onSkip: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ChillMateIntroWordmark(checkmarkInPlace: checkmarkInPlace)

            Spacer(minLength: 12)

            if showSkip, let onSkip {
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.12), in: Capsule())
                        .overlay { Capsule().stroke(.white.opacity(0.16), lineWidth: 1) }
                }
                .buttonStyle(ChillPlainButtonStyle())
                .transition(.opacity)
                .accessibilityLabel("Skip introduction")
            }
        }
        .frame(height: 42, alignment: .center)
        .animation(.easeInOut(duration: 0.25), value: showSkip)
    }
}

private struct IntroTextBlock: View {
    let page: IntroPage
    let isVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(page.eyebrow.uppercased())
                .font(.caption.weight(.heavy))
                .tracking(2.4)
                .foregroundStyle(LinearGradient.chillBrand)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 10)
                .blur(radius: isVisible ? 0 : 5)
                .animation(.spring(response: 0.50, dampingFraction: 0.82), value: isVisible)

            Text(page.title)
                .chillScaledFont(size: 39, weight: .black, relativeTo: .largeTitle, design: .rounded)
                .foregroundStyle(.white)
                .lineSpacing(1)
                .minimumScaleFactor(0.74)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 8)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 18)
                .blur(radius: isVisible ? 0 : 5)
                .animation(.spring(response: 0.54, dampingFraction: 0.80).delay(0.06), value: isVisible)

            Text(page.subtitle)
                .font(.title3.weight(.semibold))
                .lineSpacing(4)
                .foregroundStyle(.white.opacity(0.86))
                .minimumScaleFactor(0.86)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 22)
                .blur(radius: isVisible ? 0 : 5)
                .animation(.spring(response: 0.58, dampingFraction: 0.78).delay(0.12), value: isVisible)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct IntroRootBackground: View {
    let kind: IntroAnimationKind
    @Environment(\.accessibilityReduceMotion) private var reduceSystemMotion
    @AppStorage(DefaultsKey.chillReducedMotion) private var chillReducedMotion = false

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = (reduceSystemMotion || chillReducedMotion)
                ? 0
                : ctx.date.timeIntervalSinceReferenceDate
            MeshGradient(
                width: 3,
                height: 3,
                points: meshPoints(t),
                colors: meshColors,
                smoothsColors: true
            )
            .overlay {
                LinearGradient(
                    colors: [.black.opacity(0.06), .black.opacity(0.18), .black.opacity(0.64)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .animation(.easeInOut(duration: 0.54), value: kind)
    }

    // Corners stay pinned; edge mid-points slide along their own edge and the
    // centre drifts in both axes, so the gradient morphs like a slow liquid.
    private func meshPoints(_ t: TimeInterval) -> [SIMD2<Float>] {
        func wob(_ base: Float, speed: Double, amp: Float, phase: Double) -> Float {
            base + Float(sin(t * speed + phase)) * amp
        }
        return [
            SIMD2<Float>(0, 0),
            SIMD2<Float>(wob(0.5, speed: 0.43, amp: 0.07, phase: 0.0), 0),
            SIMD2<Float>(1, 0),
            SIMD2<Float>(0, wob(0.5, speed: 0.37, amp: 0.07, phase: 1.3)),
            SIMD2<Float>(wob(0.5, speed: 0.31, amp: 0.09, phase: 2.1), wob(0.5, speed: 0.35, amp: 0.08, phase: 0.7)),
            SIMD2<Float>(1, wob(0.5, speed: 0.41, amp: 0.07, phase: 3.0)),
            SIMD2<Float>(0, 1),
            SIMD2<Float>(wob(0.5, speed: 0.39, amp: 0.07, phase: 4.2), 1),
            SIMD2<Float>(1, 1),
        ]
    }

    private var meshColors: [Color] {
        switch kind {
        case .welcome:
            [Color.chillDarkBackground, Color.chillPrimary.opacity(0.94), Color.chillMint.opacity(0.72),
             Color.chillDarkBackground, Color.chillPrimary.opacity(0.56), Color.chillMint.opacity(0.40),
             Color.chillDarkBackground, Color.chillDarkBackground, Color.chillDarkBackground]
        case .summary:
            [Color.chillDarkBackground, Color.chillPrimary.opacity(0.88), Color.chillMint.opacity(0.66),
             Color.chillDarkBackground, Color.chillPrimary.opacity(0.52), Color.chillMint.opacity(0.38),
             Color.chillDarkBackground, Color.chillDarkBackground, Color.chillDarkBackground]
        case .log:
            [Color.chillDarkBackground, Color.chillIconPink.opacity(0.72), Color.chillSecondaryBlue.opacity(0.72),
             Color.chillDarkBackground, Color.chillIconPink.opacity(0.36), Color.chillSecondaryBlue.opacity(0.38),
             Color.chillDarkBackground, Color.chillDarkBackground, Color.chillDarkBackground]
        case .care:
            [Color.chillDarkBackground, Color.chillIconTeal.opacity(0.74), Color.chillMint.opacity(0.60),
             Color.chillDarkBackground, Color.chillIconTeal.opacity(0.38), Color.chillMint.opacity(0.28),
             Color.chillDarkBackground, Color.chillDarkBackground, Color.chillDarkBackground]
        case .privacy:
            [Color.chillDarkBackground, Color.chillSurfaceDark, Color.chillPrimary.opacity(0.78),
             Color.chillDarkBackground, Color.chillSurfaceDark.opacity(0.66), Color.chillPrimary.opacity(0.40),
             Color.chillDarkBackground, Color.chillDarkBackground, Color.chillDarkBackground]
        case .notice:
            [Color.chillDarkBackground, Color.chillIconOrange.opacity(0.70), Color.chillPrimary.opacity(0.70),
             Color.chillDarkBackground, Color.chillIconOrange.opacity(0.32), Color.chillPrimary.opacity(0.36),
             Color.chillDarkBackground, Color.chillDarkBackground, Color.chillDarkBackground]
        case .ready:
            [Color.chillDarkBackground, Color.chillPrimary.opacity(0.92), Color.chillMint.opacity(0.72),
             Color.chillDarkBackground, Color.chillPrimary.opacity(0.54), Color.chillMint.opacity(0.36),
             Color.chillDarkBackground, Color.chillDarkBackground, Color.chillDarkBackground]
        }
    }
}

private struct IntroAtmosphere: View {
    let kind: IntroAnimationKind
    let index: Int
    let phase: TimeInterval

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { item in
                Circle()
                    .fill(accent(for: item).opacity(0.16))
                    .frame(width: CGFloat(190 + item * 58), height: CGFloat(190 + item * 58))
                    .blur(radius: CGFloat(14 + item * 4))
                    .offset(
                        x: CGFloat(item % 2 == 0 ? -76 : 86) + wave(item, amount: 18),
                        y: CGFloat(-260 + item * 112) + wave(item + 2, amount: 14)
                    )
            }

            Image(systemName: symbol)
                .font(.system(size: 260, weight: .black))
                .foregroundStyle(.white.opacity(0.055))
                .rotationEffect(.degrees(Double(index * 8 - 18) + Double(wave(index, amount: 3))))
                .offset(x: 108, y: -18)

            VStack(spacing: 15) {
                Spacer()
                ForEach(0..<5, id: \.self) { line in
                    Capsule()
                        .fill(.white.opacity(0.055 + Double(line) * 0.010))
                        .frame(width: CGFloat(180 + line * 54), height: 6)
                        .rotationEffect(.degrees(-17))
                        .offset(x: CGFloat(-58 + line * 12), y: CGFloat(-18 * line))
                }
                Spacer().frame(height: 176)
            }
        }
    }

    private var symbol: String {
        switch kind {
        case .welcome: "sparkles"
        case .summary: "chart.bar.xaxis"
        case .log: "heart.text.square.fill"
        case .care: "checkmark.shield.fill"
        case .privacy: "lock.shield.fill"
        case .notice: "exclamationmark.triangle.fill"
        case .ready: "person.crop.circle.badge.checkmark"
        }
    }

    private func wave(_ item: Int, amount: CGFloat) -> CGFloat {
        let raw = (phase * (0.22 + Double(item) * 0.025) + Double(item) * 0.31)
            .truncatingRemainder(dividingBy: 2)
        let normalized = raw < 0 ? raw + 2 : raw
        let triangle = normalized <= 1 ? normalized : 2 - normalized
        return CGFloat(triangle * 2 - 1) * amount
    }

    private func accent(for item: Int) -> Color {
        let colors: [Color]
        switch kind {
        case .welcome:
            colors = [Color.chillPrimary, Color.chillMint, Color.chillSecondaryBlue]
        case .summary:
            colors = [Color.chillPrimary, Color.chillMint, Color.chillSecondaryBlue]
        case .log:
            colors = [Color.chillSecondaryBlue, Color.chillPrimary, Color.chillMint]
        case .care:
            colors = [Color.chillMint, Color.chillPrimary, Color.chillAccentTeal]
        case .privacy:
            colors = [Color.chillPrimary, Color.chillSecondaryBlue, Color.chillMint]
        case .notice:
            colors = [Color.chillPrimary, Color.chillSecondaryBlue, Color.chillMint]
        case .ready:
            colors = [Color.chillPrimary, Color.chillMint, Color.chillSecondaryBlue]
        }
        return colors[item % colors.count]
    }
}

private struct ChillMateIntroWordmark: View {
    let checkmarkInPlace: Bool

    var body: some View {
        HStack(spacing: 10) {
            ChillMateOnboardingLogo(checkmarkInPlace: checkmarkInPlace, size: 38)
            Text("ChillMate")
                .font(.headline.weight(.heavy))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.chillPrimary, Color.chillSecondaryBlue, Color.chillMint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ChillMate")
    }
}

private struct ChillMateOnboardingLogo: View {
    let checkmarkInPlace: Bool
    var size: CGFloat = 136

    var body: some View {
        // Real app-icon glyph (C + checkmark). See ChillMateBrandMark.
        // `checkmarkInPlace` drives a gentle pop-in entrance so the mark
        // animates onto screen while always resolving to the exact icon art.
        Image("ChillMateGlyph")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(checkmarkInPlace ? 1 : 0.6)
            .opacity(checkmarkInPlace ? 1 : 0)
            .shadow(color: Color.chillPrimary.opacity(0.40), radius: size * 0.13, x: 0, y: size * 0.06)
            .shadow(color: Color.chillMint.opacity(0.30), radius: size * 0.10, x: 0, y: size * 0.04)
            .accessibilityHidden(true)
    }
}

/// A single, persistent hero that morphs between the four intro states, instead of
/// each slide spawning and discarding its own. It stacks every scene and cross-fades
/// / scales the active one, so the mark reads as one element transforming through the
/// story rather than four separate reveals. Reuses the existing `IntroHeroScene`
/// visuals as morph layers.
@MainActor
private struct MorphingIntroHero: View {
    let activeKind: IntroAnimationKind
    var neighborKind: IntroAnimationKind = .welcome
    var morphT: CGFloat = 0
    let phase: TimeInterval
    let isCompleting: Bool
    let checkmarkInPlace: Bool

    private let kinds: [IntroAnimationKind] = [.welcome, .summary, .care, .privacy]

    // `morphT` (0…1) tracks the finger during a swipe, blending the active scene into
    // the one being dragged toward. At rest it is 0, so the active scene sits at full
    // and everything else is parked small and transparent. Releasing without committing
    // springs the parallax back to 0, which unwinds the blend, so the morph is reversible.
    var body: some View {
        ZStack {
            ForEach(Array(kinds.enumerated()), id: \.offset) { _, kind in
                let isActive = kind == activeKind
                let isNeighbor = kind == neighborKind && neighborKind != activeKind
                let opacity: Double = isActive
                    ? Double(1 - morphT)
                    : (isNeighbor ? Double(morphT) : 0)
                let scale: CGFloat = isActive
                    ? (1 - 0.10 * morphT)
                    : (isNeighbor ? (0.72 + 0.28 * morphT) : 0.72)
                let rotation: Double = isActive
                    ? Double(6 * morphT)
                    : (isNeighbor ? Double(10 * (1 - morphT)) : 10)

                IntroHeroScene(
                    kind: kind,
                    phase: phase,
                    isCompleting: isCompleting && isActive,
                    checkmarkInPlace: checkmarkInPlace,
                    // Constant index: the scenes are assembled once and never
                    // re-enter on page change. The blend above carries the motion.
                    pageIndex: 0
                )
                .opacity(opacity)
                .scaleEffect(max(0.0001, scale))
                .rotationEffect(.degrees(rotation))
                .allowsHitTesting(isActive)
            }
        }
        // Only the committed page change springs; the drag-driven blend tracks the
        // finger directly (no implicit animation on morphT).
        .animation(.spring(response: 0.62, dampingFraction: 0.74), value: activeKind)
    }
}

@MainActor
private struct IntroHeroScene: View {
    @State private var delays = DelayedActionRunner()
    let kind: IntroAnimationKind
    let phase: TimeInterval
    let isCompleting: Bool
    let checkmarkInPlace: Bool
    let pageIndex: Int

    @State private var appeared = false
    @State private var careLead: Int? = nil
    @State private var careTapped = false
    @Environment(\.accessibilityReduceMotion) private var reduceSystemMotion
    @AppStorage(DefaultsKey.chillReducedMotion) private var chillReducedMotion = false

    private var careMotionOff: Bool { reduceSystemMotion || chillReducedMotion }

    var body: some View {
        ZStack {
            switch kind {
            case .welcome:   welcomeScene
            case .summary:   summaryScene
            case .log:       logScene
            case .care:      careScene
            case .privacy:   privacyScene
            case .notice:    noticeScene
            case .ready:     readyScene
            }
        }
        .scaleEffect(isCompleting ? 1.18 : (appeared ? 1 : 0.82))
        .opacity(appeared || isCompleting ? 1 : 0)
        .blur(radius: appeared ? 0 : 10)
        .animation(.spring(response: 0.62, dampingFraction: 0.76).delay(0.04), value: appeared)
        .animation(.spring(response: 0.56, dampingFraction: 0.76), value: isCompleting)
        // A soft tap the instant a moment is chosen and rises to the top.
        .sensoryFeedback(.impact(weight: .medium), trigger: careLead)
        .onAppear {
            appeared = false
            delays.run(after: .milliseconds(40), skipDelayWhenReducingMotion: false) {
                withAnimation { appeared = true }
            }
        }
        .onChange(of: pageIndex) { _, _ in
            appeared = false
            delays.run(after: .milliseconds(40), skipDelayWhenReducingMotion: false) {
                withAnimation { appeared = true }
            }
        }
        .cancellingDelayedActions(delays)
    }

    private func selectMoment(_ index: Int) {
        if careMotionOff {
            careLead = index
            careTapped = true
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.76)) {
                careLead = index
                careTapped = true
            }
        }
    }

    // MARK: - Welcome: logomark bloom (continues the launch splash)

    private var welcomeScene: some View {
        ZStack {
            // Soft glow halo, echoing the splash's final beat.
            Circle()
                .fill(RadialGradient(
                    colors: [Color.chillPrimary.opacity(0.55), .clear],
                    center: .center, startRadius: 4, endRadius: 150))
                .frame(width: 300, height: 300)
                .blur(radius: 22)
                .scaleEffect(appeared ? 1 + bob(0, amount: 0.03) : 0.6)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.80, dampingFraction: 0.82), value: appeared)

            // Gentle breathing brand ring.
            Circle()
                .stroke(LinearGradient.chillBrand, lineWidth: 2)
                .frame(width: 208, height: 208)
                .scaleEffect(appeared ? 1 + bob(1, amount: 0.04) : 0.72)
                .opacity(appeared ? 0.65 : 0)
                .animation(.spring(response: 0.90, dampingFraction: 0.84).delay(0.05), value: appeared)

            // The app logomark, blooming in just like the launch splash.
            ChillMateOnboardingLogo(checkmarkInPlace: checkmarkInPlace, size: 150)
                .scaleEffect(appeared ? 1 : 0.7)
                .animation(.spring(response: 0.70, dampingFraction: 0.72), value: appeared)
        }
        .shadow(color: Color.chillPrimary.opacity(0.34), radius: 30, y: 16)
    }

    // MARK: - Summary: animated bar chart + logo

    private var summaryScene: some View {
        ZStack {
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(0..<4, id: \.self) { i in
                    let targetHeights: [CGFloat] = [108, 158, 80, 132]
                    let colors: [Color] = [.chillSecondaryBlue, Color(red: 251/255, green: 146/255, blue: 60/255), .chillAccentTeal, .chillMint]
                    let labels = ["Chills", "Sleep", "Care", "Score"]
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(LinearGradient(colors: [colors[i], colors[i].opacity(0.50)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 44, height: appeared ? targetHeights[i] + bob(i, amount: 5) : 4)
                            .overlay(alignment: .top) {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(.white.opacity(0.24))
                                    .frame(width: 44, height: 13)
                            }
                            .shadow(color: colors[i].opacity(0.42), radius: 14, y: 6)
                            .animation(.spring(response: 0.78, dampingFraction: 0.68).delay(Double(i) * 0.09), value: appeared)
                        Text(labels[i])
                            .chillScaledFont(size: 9, weight: .bold, relativeTo: .caption2)
                            .foregroundStyle(.white.opacity(0.74))
                    }
                }
            }
            .offset(y: 28)

            ChillMateOnboardingLogo(checkmarkInPlace: checkmarkInPlace, size: 90)
                .offset(x: 0, y: -82 + bob(0, amount: 4))

            ScoreRing(progress: appeared ? 0.74 : 0, tint: Color.chillMint)
                .frame(width: 82, height: 82)
                .offset(x: 116, y: -48 + bob(2, amount: 4))
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.72, dampingFraction: 0.76).delay(0.20), value: appeared)
        }
    }

    // MARK: - Log: pills fly in with stagger

    private var logScene: some View {
        ZStack {
            // LocalizedStringResource, not String: Text(someString) renders
            // verbatim, so these onboarding labels were English everywhere.
            let titles: [LocalizedStringResource] = ["Time", "Sleep", "Condom", "People", "Location"]
            let symbols = ["clock.fill", "bed.double.fill", "checkmark.shield.fill", "person.2.fill", "location.fill"]
            let tints: [Color] = [.chillSecondaryBlue, Color(red: 251/255, green: 146/255, blue: 60/255), .chillMint, Color(red: 244/255, green: 114/255, blue: 182/255), .chillAccentTeal]

            ForEach(0..<5, id: \.self) { i in
                let x: CGFloat = i % 2 == 0 ? -54 : 46
                TimelinePill(title: titles[i], symbol: symbols[i], tint: tints[i])
                    .offset(x: x, y: appeared ? CGFloat(-124 + i * 56) + bob(i, amount: 4) : 110)
                    .opacity(appeared ? 1 : 0)
                    .blur(radius: appeared ? 0 : 3)
                    .animation(.spring(response: 0.60, dampingFraction: 0.74).delay(Double(i) * 0.10), value: appeared)
            }

            Image(systemName: "plus")
                .font(.system(size: 42, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(LinearGradient.chillBrand, in: Circle())
                .shadow(color: Color.chillPrimary.opacity(0.56), radius: 28, y: 14)
                .scaleEffect(appeared ? 1 : 0.28)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.62, dampingFraction: 0.60).delay(0.52), value: appeared)
                .offset(x: 92, y: 94 + bob(1, amount: 5))
        }
    }

    // MARK: - Care: real circular orbit

    /// Teaches the four Home "moments" (the same icons, colours, and order the
    /// user meets on the dashboard) and lets the user *do* the core Home behaviour
    /// once: tap the moment you're in, and it rises to the top with a "Now" badge,
    /// exactly the way the real dashboard rearranges itself.
    private var careScene: some View {
        let moments: [(title: String, symbol: String, tint: Color)] = [
            (String(localized: "Before you go"), "checkmark.shield.fill", .chillSecondaryBlue),
            (String(localized: "While you’re out"), "timer", Color(red: 251/255, green: 146/255, blue: 60/255)),
            (String(localized: "Aftercare & health"), "heart.text.square.fill", .chillMint),
            (String(localized: "Your patterns"), "chart.xyaxis.line", .chillPrimary)
        ]
        // Promote the chosen moment to the top, keeping the rest in their order.
        let order: [Int] = {
            guard let lead = careLead else { return Array(moments.indices) }
            return [lead] + moments.indices.filter { $0 != lead }
        }()

        return ZStack {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(.white.opacity(0.10))
                .frame(width: 288, height: 262)
                .overlay {
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 1.1)
                }

            VStack(spacing: 8) {
                ForEach(order, id: \.self) { index in
                    let moment = moments[index]
                    let isLead = careLead == index
                    HStack(spacing: 12) {
                        Image(systemName: moment.symbol)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(moment.tint)
                            .frame(width: 38, height: 38)
                            .background(moment.tint.opacity(0.22), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                        Text(moment.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .chillLineLimit(1, scale: 0.7)

                        Spacer(minLength: 6)

                        if isLead {
                            Text("Now")
                                .chillScaledFont(size: 10, weight: .heavy, relativeTo: .caption2)
                                .foregroundStyle(moment.tint)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(moment.tint.opacity(0.22), in: Capsule())
                                .fixedSize()
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(.white.opacity(isLead ? 0.12 : 0.0001))
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(moment.tint.opacity(isLead ? 0.5 : 0), lineWidth: 1.2)
                            }
                    )
                    .frame(width: 240, alignment: .leading)
                    .contentShape(Rectangle())
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : -26)
                    .animation(.spring(response: 0.52, dampingFraction: 0.78).delay(Double(index) * 0.10 + 0.12), value: appeared)
                    .onTapGesture { selectMoment(index) }
                }

                careHint
                    .frame(width: 240, alignment: .leading)
                    .padding(.top, 2)
            }
            .offset(y: bob(1, amount: 2.0))
        }
        .shadow(color: Color.chillPrimary.opacity(0.30), radius: 26, y: 14)
    }

    /// The one-line coach mark under the moments: an invitation before the first tap,
    /// then a confirmation of what just happened.
    private var careHint: some View {
        HStack(spacing: 6) {
            Image(systemName: careTapped ? "arrow.up" : "hand.tap.fill")
                .font(.system(size: 11, weight: .bold))
                .symbolEffect(.pulse, options: careTapped || careMotionOff ? .nonRepeating : .repeating, isActive: !careTapped)
            Text(careTapped
                 ? String(localized: "The moment you’re in rises to the top")
                 : String(localized: "Tap the one you’re in right now"))
                .chillScaledFont(size: 11, weight: .semibold, relativeTo: .caption2)
                .chillLineLimit(1, scale: 0.75)
        }
        .foregroundStyle(.white.opacity(0.66))
    }

    // MARK: - Privacy: ping rings + face ID

    private var privacyScene: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.chillSurfaceDark.opacity(0.90), Color.chillPrimary.opacity(0.30), .white.opacity(0.14)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 238, height: 260)
                .overlay {
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .stroke(.white.opacity(0.24), lineWidth: 1.2)
                }

            VStack(spacing: 14) {
                ZStack {
                    // Expanding ping rings
                    ForEach(0..<3, id: \.self) { ring in
                        let raw = (phase * 0.36 + Double(ring) * 0.60).truncatingRemainder(dividingBy: 1.8)
                        let progress = raw / 1.8
                        Circle()
                            .stroke(
                                LinearGradient.chillBrand.opacity(0.30 * (1 - progress)),
                                lineWidth: 1.4
                            )
                            .frame(width: 72 + CGFloat(progress * 60), height: 72 + CGFloat(progress * 60))
                    }
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.chillDarkBackground.opacity(0.80))
                        .frame(width: 96, height: 96)
                    ChillMateOnboardingLogo(checkmarkInPlace: checkmarkInPlace, size: 72)
                }

                ForEach(0..<3, id: \.self) { item in
                    HStack(spacing: 9) {
                        Image(systemName: ["faceid", "lock.fill", "key.fill"][item])
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle([Color.chillPrimary, Color.chillMint, Color.chillSecondaryBlue][item])
                        Capsule()
                            .fill(.white.opacity(0.24))
                            .frame(width: CGFloat([82, 124, 102][item]), height: 7)
                    }
                    .frame(width: 156, alignment: .leading)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : -20)
                    .animation(.spring(response: 0.50, dampingFraction: 0.80).delay(Double(item) * 0.10 + 0.22), value: appeared)
                }
            }
            .offset(y: -6)

            // The real "quick hide" control from Home: a red stop button that
            // instantly drops the privacy shield ("Screen paused"); tap to resume.
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(.red)
                .frame(width: 74, height: 74)
                .background(Color.chillDarkBackground.opacity(0.74), in: Circle())
                .overlay { Circle().stroke(.red.opacity(0.34), lineWidth: 1) }
                .offset(x: 96, y: 102 + bob(1, amount: 3.5))
                .scaleEffect(1 + bob(0, amount: 0.05))
                .shadow(color: .red.opacity(0.42), radius: 18, y: 8)
        }
        .shadow(color: Color.chillPrimary.opacity(0.34), radius: 30, y: 16)
    }

    // MARK: - Notice: staggered lines + pulsing badge

    private var noticeScene: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(.white.opacity(0.13))
                .frame(width: 252, height: 252)
                .overlay {
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .stroke(.white.opacity(0.26), lineWidth: 1.2)
                }

            VStack(spacing: 18) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(LinearGradient.chillBrand)
                    .symbolEffect(.bounce, options: .repeating.speed(0.5))
                    .scaleEffect(1 + bob(0, amount: 0.018))

                VStack(spacing: 9) {
                    let lines = [("Wellbeing only", "heart.text.square.fill"),
                                 ("Support is nearby", "person.2.fill"),
                                 ("No dosage advice", "checkmark.shield.fill")]
                    ForEach(Array(lines.enumerated()), id: \.offset) { i, pair in
                        BetaNoticeLine(text: pair.0, symbol: pair.1)
                            .opacity(appeared ? 1 : 0)
                            .offset(x: appeared ? 0 : -24)
                            .animation(.spring(response: 0.50, dampingFraction: 0.80).delay(Double(i) * 0.12 + 0.10), value: appeared)
                    }
                }
            }
        }
        .rotationEffect(.degrees(bob(1, amount: 1.2)))
    }

    // MARK: - Ready: sparkle orbit + person + logo bounce

    private var readyScene: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 230, height: 230)
                .overlay { Circle().stroke(.white.opacity(0.24), lineWidth: 1.5) }

            // Sparkle orbit
            ForEach(0..<8, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(i % 2 == 0 ? Color.chillPrimary : Color.chillMint)
                    .offset(y: -112)
                    .rotationEffect(.degrees(Double(i) * 45 + (phase * 14).truncatingRemainder(dividingBy: 360)))
                    .opacity(appeared ? 0.68 + bob(i, amount: 0.28) : 0)
                    .scaleEffect(appeared ? 0.80 + bob(i, amount: 0.26) : 0)
                    .animation(.spring(response: 0.66, dampingFraction: 0.66).delay(Double(i) * 0.06 + 0.28), value: appeared)
            }

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 110, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.chillSecondaryBlue, Color.chillPrimary],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .offset(y: -12)
                .scaleEffect(appeared ? 1 : 0.46)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.66, dampingFraction: 0.66).delay(0.08), value: appeared)

            ChillMateOnboardingLogo(checkmarkInPlace: checkmarkInPlace, size: 90)
                .offset(x: 72, y: 84)
                .scaleEffect(appeared ? 1 : 0.28)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.68, dampingFraction: 0.60).delay(0.18), value: appeared)
        }
        .shadow(color: Color.chillMint.opacity(0.30), radius: 30, y: 18)
    }

    // MARK: - Helpers

    private func bob(_ item: Int, amount: CGFloat) -> CGFloat {
        let raw = (phase * (0.30 + Double(item) * 0.035) + Double(item) * 0.27)
            .truncatingRemainder(dividingBy: 2)
        let normalized = raw < 0 ? raw + 2 : raw
        let tri = normalized <= 1 ? normalized : 2 - normalized
        return CGFloat(tri * 2 - 1) * amount
    }
}

private struct BetaNoticeLine: View {
    let text: String
    let symbol: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(LinearGradient.chillBrand)
                .frame(width: 26, height: 26)
                .background(Color.chillPrimary.opacity(0.18), in: Circle())
            Text(text)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white.opacity(0.86))
                .chillLineLimit(2, scale: 0.7)
                .fixedSize(horizontal: false, vertical: true)
        }
        // A fixed 202pt width with a one-line limit clipped this at the larger
        // text sizes. The width stays, because the row it sits in is built around
        // it; the text is allowed to use two lines inside that width.
        .frame(width: 202, alignment: .leading)
    }
}

private struct MiniMetricBubble: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.70))
        }
        .frame(width: 86, height: 86)
        .background(.white.opacity(0.13), in: Circle())
        .overlay {
            Circle().stroke(.white.opacity(0.20), lineWidth: 1)
        }
    }
}

private struct ScoreRing: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.14), lineWidth: 18)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [tint, Color.chillSecondaryBlue], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.44), radius: 10)
            Circle()
                .fill(.white.opacity(0.06))
                .padding(30)
        }
    }
}

private struct TimelinePill: View {
    let title: LocalizedStringResource
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.20), in: Circle())
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white.opacity(0.14), in: Capsule())
        .overlay {
            Capsule().stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct ProfileIntroTile: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ProfileSetupIcon(systemImage: systemImage)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.chillText)

                Text(subtitle)
                    .font(.footnote)
                    .lineSpacing(2)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)
    }
}
