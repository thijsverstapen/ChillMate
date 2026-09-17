import SwiftUI

// Written against an iOS 27 that had not shipped yet, and the guess was half
// right.
//
// `.topBarPinnedTrailing` is real: a trailing placement that stays put while the
// navigation bar collapses. `toolbarMinimizeBehavior(_:for:)` is not. The iOS 27
// SDK has `tabBarMinimizeBehavior` and `windowMinimizeBehavior` and nothing that
// minimizes a navigation bar, so there is no modern path to take.
//
// It compiled for two years because it never compiled: the `#if !SDK_260000`
// guard excluded the whole branch while the iOS 26 SDK was current, and the
// first build against the iOS 27 SDK is the first time a compiler looked at it.
// A shim for an API nobody has seen is a guess with a delayed failure, and this
// is the delay expiring.
//
// SDK_260000 comes from SWIFT_ACTIVE_COMPILATION_CONDITIONS = SDK_$(SDK_VERSION_MAJOR),
// set at the project level. The deployment target stays at iOS 26, so #available
// still decides at runtime.

/// Trailing placement for a form's primary action. On iOS 27 it survives the
/// navigation bar minimizing on scroll; on iOS 26 it is the ordinary trailing slot.
var chillPinnedTrailingPlacement: ToolbarItemPlacement {
    #if !SDK_260000
    if #available(iOS 27.0, *) {
        return .topBarPinnedTrailing
    }
    #endif
    return .topBarTrailing
}

extension View {
    /// Kept as the seam it always was, doing nothing.
    ///
    /// If SwiftUI ever grows a navigation-bar equivalent of
    /// `tabBarMinimizeBehavior`, this is where it goes and the one call site does
    /// not move. Returning `self` is honest about today: the behaviour has never
    /// run, so nothing changes by saying so.
    @ViewBuilder
    func chillMinimizingNavigationBar() -> some View {
        self
    }
}
