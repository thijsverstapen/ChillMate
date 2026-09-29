import SwiftUI

/// The page shown once after an update: what is new, in a few plain sentences.
struct WhatsNewView: View {
    let release: WhatsNewRelease
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            DashboardBackdrop()

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 6) {
                        Text("What's New")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color.chillText)
                        Text("Version \(release.version)")
                            .font(.title3)
                            .foregroundStyle(Color.chillSecondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.top, 36)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    VStack(alignment: .leading, spacing: 26) {
                        ForEach(release.items) { item in
                            WhatsNewRow(item: item)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            // Always in reach, however long the list or large the text: the
            // items scroll, the way out does not.
            .safeAreaInset(edge: .bottom) {
                GlassActionButton(prominent: true, action: dismiss) {
                    Label("Continue", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: 560)
            }
        }
    }
}

/// One thing that is new: a symbol, a short title and a sentence or two.
struct WhatsNewRow: View {
    let item: WhatsNewItem

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: item.symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.chillPrimary)
                .frame(width: 44, height: 44)
                .glassSurface(radius: 14, tint: Color.chillPrimary.opacity(0.14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(Color.chillText)
                Text(item.detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
