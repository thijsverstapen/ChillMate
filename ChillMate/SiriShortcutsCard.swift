import AppIntents
import SwiftUI

/// Where the voice actions become findable.
///
/// ChillMate has had a dozen App Shortcuts for a while and no screen that admits
/// it. The Shortcuts gallery is a place people go on purpose, and mostly do not,
/// so the actions existed for anybody who already knew they existed. That is the
/// wrong way round for the one action here that matters — panic support, which is
/// worth saying out loud precisely because the person saying it cannot work a
/// screen.
///
/// `SiriTipView` is doing the real work: it shows the exact phrase and adds the
/// shortcut in one tap. The three chosen are the ones worth having before you
/// need them, not the ones that demo best.
struct SiriShortcutsCard: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CareSectionTitle(title: String(localized: "Say it out loud"), symbol: "mic.fill")

            Text("Some of this works without touching the screen. Set these up now, while you are calm and reading a settings page, because the moment you want the first one is the moment you will not be doing this.")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            SiriTipView(intent: OpenPanicSupportIntent())
            SiriTipView(intent: CheckCombinationIntent())
            SiriTipView(intent: LogHydrationIntent())

            ShortcutsLink()
                .shortcutsLinkStyle(.automaticOutline)

            Text("Everything on this list runs on your phone. Siri hands the request to ChillMate and nothing about it leaves the device.")
                .font(.caption)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.10))
    }
}
