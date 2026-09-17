import AVFoundation
import SwiftUI
import UIKit

/// Plays the rendered launch animation (`FirstLaunchSplash.mp4`) full-screen, once,
/// then calls `onFinish`. Shown only on the very first app launch, before onboarding.
/// All other launches use the static `LaunchScreen.storyboard` and skip this entirely.
///
/// The clip is silent and video-only, so it never touches the audio session or
/// interrupts whatever the user is already listening to.
///
/// **It is skippable, and it is skipped outright when motion is reduced.** The
/// animation is good and it is still six seconds standing between somebody and a
/// combination checker they may have installed the app for tonight. So a tap
/// anywhere ends it, the whole screen is one accessibility element that says so,
/// and anyone who has asked their phone for less movement never sees it at all —
/// a full-screen video is exactly what that setting is about.
struct FirstLaunchSplashView: View {
    let onFinish: () -> Void

    @Environment(\.chillReduceMotion) private var reduceMotion

    @State private var player = AVPlayer()
    @State private var didFinish = false
    @State private var endObserver: NSObjectProtocol?
    @State private var watchdog: Task<Void, Never>?
    @State private var canSkip = false

    var body: some View {
        ZStack {
            // Matches the storyboard splash + app background, so the hand-off from
            // the static launch screen into this animation is seamless.
            Color.chillDarkBackground
                .ignoresSafeArea()

            SplashPlayerView(player: player)
                .ignoresSafeArea()

            // Appears after a beat rather than immediately: a skip control on
            // screen from frame one reads as an apology for the thing it is on.
            if canSkip {
                VStack {
                    Spacer()
                    Text("Tap to skip")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.bottom, 44)
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: finishOnce)
        .accessibilityElement()
        .accessibilityLabel(Text("ChillMate is opening"))
        .accessibilityHint(Text("Double tap to skip the introduction animation."))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { finishOnce() }
        .onAppear(perform: start)
        .onDisappear {
            watchdog?.cancel()
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
            }
        }
    }

    private func start() {
        // Somebody who has asked for reduced motion has asked not to be shown a
        // six-second full-screen animation. There is no version of this that
        // respects that setting and still plays.
        guard !reduceMotion else {
            finishOnce()
            return
        }

        guard let url = Bundle.main.url(forResource: "FirstLaunchSplash", withExtension: "mp4") else {
            // If the asset is missing for any reason, never block the first launch.
            finishOnce()
            return
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard !didFinish else { return }
            withAnimation(.easeIn(duration: 0.3)) { canSkip = true }
        }

        let item = AVPlayerItem(url: url)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            // Delivered on the main queue (queue: .main above).
            MainActor.assumeIsolated { finishOnce() }
        }

        player.replaceCurrentItem(with: item)
        player.actionAtItemEnd = .pause
        player.isMuted = true
        player.play()

        // Safety net: if playback stalls or can't start, continue anyway.
        // A Task rather than asyncAfter so it stops with the view instead of firing
        // onFinish() six seconds after the splash has already been dismissed.
        watchdog?.cancel()
        watchdog = Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            finishOnce()
        }
    }

    private func finishOnce() {
        guard !didFinish else { return }
        didFinish = true
        onFinish()
    }
}

/// A controls-free video surface backed by `AVPlayerLayer`, scaled to fill.
private struct SplashPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = UIColor(red: 15 / 255, green: 17 / 255, blue: 23 / 255, alpha: 1)
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.player = player
    }

    final class PlayerLayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
