import SwiftUI

// iOS 27 lets a navigation bar minimize as the user scrolls, and adds a trailing
// placement that stays put while it does. Those symbols exist only in the iOS 27
// SDK, so the modern path has to be compiled out when building against iOS 26.
//
// SDK_260000 comes from SWIFT_ACTIVE_COMPILATION_CONDITIONS = SDK_$(SDK_VERSION_MAJOR),
// set at the project level. Testing for its absence rather than for SDK_270000
// means Xcode 28 and later keep the modern path without another edit here.
//
// The deployment target stays at iOS 26, so #available still decides at runtime.

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
    /// Collapses the navigation bar as content scrolls down, on iOS 27 and later.
    /// Pair with `chillPinnedTrailingPlacement` so the primary action stays reachable.
    @ViewBuilder
    func chillMinimizingNavigationBar() -> some View {
        #if !SDK_260000
        if #available(iOS 27.0, *) {
            toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
