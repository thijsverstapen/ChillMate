import SwiftUI

/// Cancellable replacement for `DispatchQueue.main.asyncAfter` in view code.
///
/// The app sequenced animations with nine bare `asyncAfter` calls carrying magic
/// delays (0.04, 0.06, 0.14, 0.35, 0.44, 0.50, 1.1, 6.0 seconds). Those closures
/// cannot be cancelled, so they still fire after the view has gone away (running
/// an animation or a navigation on a screen the user already left), and they
/// ignore the reduce-motion preference entirely.
///
/// A `Task` is cancellable, ties naturally to view lifetime, and checks
/// cancellation before doing anything.
// No observable state: views hold this purely for its lifetime, so it needs
// @State for ownership rather than @Observable for change tracking.
@MainActor
final class DelayedActionRunner {
    private var tasks: [Task<Void, Never>] = []

    /// Runs `action` after `delay`, unless cancelled first.
    ///
    /// With `skipDelayWhenReducingMotion`, a reduce-motion user gets the outcome
    /// immediately rather than waiting through a pause that exists only to let an
    /// animation play.
    func run(
        after delay: Duration,
        reduceMotion: Bool = false,
        skipDelayWhenReducingMotion: Bool = true,
        _ action: @escaping @MainActor () -> Void
    ) {
        if reduceMotion && skipDelayWhenReducingMotion {
            action()
            return
        }

        let task = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            action()
        }
        tasks.append(task)
    }

    /// Cancels everything still pending. Call from `onDisappear`.
    func cancelAll() {
        for task in tasks { task.cancel() }
        tasks.removeAll()
    }

    deinit {
        for task in tasks { task.cancel() }
    }
}

extension View {
    /// Cancels the runner's pending work when this view goes away.
    func cancellingDelayedActions(_ runner: DelayedActionRunner) -> some View {
        onDisappear { runner.cancelAll() }
    }
}

/// Compile-time-safe URLs for the fixed links the app ships.
///
/// The care screens force-unwrapped 19 `URL(string:)` literals. They cannot fail
/// as written, but a force unwrap turns any future typo into a crash. And these
/// specific links are the emergency, crisis, and help-resource ones, i.e. exactly
/// where a crash is least acceptable.
///
/// `staticURL` traps only in debug, so a malformed link is caught during
/// development, while a release build degrades to a nil (unshown) link instead of
/// taking the app down while someone is looking for help.
func staticURL(_ string: String, file: StaticString = #fileID, line: UInt = #line) -> URL? {
    guard let url = URL(string: string) else {
        assertionFailure("Malformed static URL: \(string)", file: file, line: line)
        return nil
    }
    return url
}
