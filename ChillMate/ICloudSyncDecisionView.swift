import SwiftUI

/// The one question an install from before 5.1.0 is asked, before its store opens.
///
/// Shown in place of the whole app, ahead of the app lock, and it touches no data:
/// it cannot, because the container is not built until this is answered. That
/// ordering is the point. The store's CloudKit setting is fixed when the container
/// is created, so asking after the app had opened would mean one more session
/// syncing on a setting nobody chose.
///
/// Showing it ahead of the app lock leaks nothing — there is no data on this screen —
/// and grants nothing either: of the two answers, one is what the store was already
/// doing and the other copies less, not more.
///
/// It says what happened plainly, including that it happened without being asked,
/// and it does not pretend that switching off deletes anything. What is already in
/// iCloud stays there until the person removes it, and removing it is done in iOS
/// Settings rather than from here: that is Apple's own, tested path, and a deletion
/// written here could not be tested without a real iCloud account.
struct ICloudSyncDecisionView: View {
    let onDecide: (ICloudSyncPreference.Choice) -> Void

    var body: some View {
        ZStack {
            DashboardBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(
                        title: String(localized: "Your data and iCloud"),
                        subtitle: String(localized: "One choice before you carry on."),
                        symbol: "icloud",
                        tint: Color.chillPrimary
                    )

                    Text("Until now, whenever you were signed into iCloud, ChillMate kept a copy of your data in your private iCloud without asking you first. That copy is how your history can move to a new iPhone. From this version it is your choice, and it stays your choice.")
                        .font(.subheadline)
                        .foregroundStyle(Color.chillText)
                        .fixedSize(horizontal: false, vertical: true)

                    option(
                        title: String(localized: "Keep everything on this iPhone"),
                        detail: String(localized: "Nothing new is copied to iCloud. The copy already there is not deleted by this. You can remove it in iOS Settings, under your iCloud storage."),
                        symbol: "iphone",
                        prominent: true,
                        choice: .off
                    )

                    option(
                        title: String(localized: "Keep the iCloud copy"),
                        detail: String(localized: "Your history can move to a new iPhone or come back after reinstalling. Apple stores it, and unless you have turned on Advanced Data Protection, Apple holds the keys to it."),
                        symbol: "icloud.fill",
                        prominent: false,
                        choice: .on
                    )

                    Text("You can change this at any time in Settings.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
        }
    }

    /// One answer: what it is called, what it actually does, and the button.
    ///
    /// Staying on the phone is the prominent option on purpose. It is the answer
    /// that matches what this app has always said about itself, and the one that
    /// is safer to have chosen by accident.
    @ViewBuilder
    private func option(
        title: String,
        detail: String,
        symbol: String,
        prominent: Bool,
        choice: ICloudSyncPreference.Choice
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(detail)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            GlassActionButton(prominent: prominent, action: { onDecide(choice) }) {
                Label(title, systemImage: symbol)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: 24, tint: Color.chillPrimary.opacity(0.06))
    }
}
