import AVFoundation
import SwiftUI
import UIKit

/// Plays the rendered launch animation (`FirstLaunchSplash.mp4`) full-screen, once,
/// then calls `onFinish`. Shown only on the very first app launch, before onboarding.
/// All other launches use the static `LaunchScreen.storyboard` and skip this entirely.
///
/// The clip is silent and video-only, so it never touches the audio session or
/// interrupts whatever the user is already listening to.
struct FirstLaunchSplashView: View {
    let onFinish: () -> Void

    @State private var player = AVPlayer()
    @State private var didFinish = false
    @State private var endObserver: NSObjectProtocol?

    var body: some View {
        ZStack {
            // Matches the storyboard splash + app background, so the hand-off from
            // the static launch screen into this animation is seamless.
            Color.chillDarkBackground
                .ignoresSafeArea()

            SplashPlayerView(player: player)
                .ignoresSafeArea()
        }
        .onAppear(perform: start)
        .onDisappear {
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
            }
        }
    }

    private func start() {
        guard let url = Bundle.main.url(forResource: "FirstLaunchSplash", withExtension: "mp4") else {
            // If the asset is missing for any reason, never block the first launch.
            finishOnce()
            return
        }

        let item = AVPlayerItem(url: url)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            finishOnce()
        }

        player.replaceCurrentItem(with: item)
        player.actionAtItemEnd = .pause
        player.isMuted = true
        player.play()

        // Safety net: if playback stalls or can't start, continue anyway.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
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
