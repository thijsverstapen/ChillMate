import Foundation
import SwiftUI
import UIKit

/// The single grouped tool section on Home: four full-width "moment" rows (before,
/// during, after, reflect) that replaced the old twelve-card grids. `groups` is
/// passed in already ordered so the caller can promote the current moment to the top,
/// and `highlightedPage` marks that moment with a "Now" badge and a live hint.
struct MomentGroupsSection: View {
    let groups: [CareToolGroup]
    var highlightedPage: CareToolPage? = nil
    var highlightHint: String? = nil
    let open: (CareToolPage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CareSectionTitle(title: String(localized: "Your tools"), symbol: "square.grid.2x2.fill")

            VStack(spacing: 8) {
                ForEach(groups) { group in
                    ToolRow(
                        title: group.title,
                        subtitle: group.subtitle,
                        symbol: group.symbol,
                        tint: group.tint,
                        isHighlighted: group.page == highlightedPage,
                        hint: group.page == highlightedPage ? highlightHint : nil
                    ) {
                        open(group.page)
                    }
                }
            }
        }
    }
}

/// The shared full-width tool container used everywhere tools are listed (the Home
/// "moment" groups and every group landing page), so tool containers look identical
/// across pages: colored icon, title (with an optional "Now" badge), a subtitle or
/// live hint, and a chevron.
struct ToolRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    var isHighlighted: Bool = false
    var hint: String? = nil
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 46, height: 46)
                    .background(tint.opacity(0.20), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.chillText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if isHighlighted {
                            Text("Now")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(tint, in: Capsule())
                        }
                    }
                    Text(hint ?? subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(hint == nil ? Color.chillSecondary : tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.chillTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(radius: 22, tint: tint.opacity(isHighlighted ? 0.20 : 0.10), interactive: true)
        }
        .buttonStyle(ChillPlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(title). \(hint ?? subtitle)"))
    }
}

/// Landing page pushed when a Home "moment" card is tapped. Lists that group's
/// member tools, each of which pushes onto the same navigation stack.
struct CareToolGroupView: View {
    let group: CareToolGroup
    let open: (CareToolPage) -> Void

    var body: some View {
        ZStack {
            DashboardBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(
                        title: group.title,
                        subtitle: group.subtitle,
                        symbol: group.symbol,
                        tint: group.tint
                    )

                    VStack(spacing: 8) {
                        ForEach(group.members) { member in
                            let tool = CareToolCatalog.definition(for: member)
                            ToolRow(
                                title: tool.title,
                                subtitle: tool.subtitle,
                                symbol: tool.symbol,
                                tint: tool.tint
                            ) {
                                open(member)
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct PageHeader: View {
    @AppStorage(DefaultsKey.lastDailyRecoveryScore) private var lastDailyRecoveryScore = 42
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    private var palette: DailyScorePalette {
        DailyScorePalette(score: lastDailyRecoveryScore)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [tint.opacity(0.22), tint.opacity(0.10)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.36), lineWidth: 1)
                    }
                    .shadow(color: tint.opacity(0.28), radius: 10, y: 4)

                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(palette.heroText)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.80)
            }

            Text(subtitle)
                .font(.callout)
                .lineSpacing(3)
                .foregroundStyle(palette.heroSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct EmergencyRedFlagCard: View {
    @State private var checkedFlags: Set<String> = []

    private let flags = [
        String(localized: "Chest pain or severe pressure"),
        String(localized: "Fainting, seizure, or cannot be woken"),
        String(localized: "Blue lips, slow breathing, or gasping"),
        String(localized: "Very confused, overheating, or rigid muscles"),
        String(localized: "Severe panic that does not settle")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CareSectionTitle(title: String(localized: "Emergency red flags"), symbol: "exclamationmark.triangle.fill")

                Spacer()

                if !checkedFlags.isEmpty {
                    Button("Renew") {
                        checkedFlags.removeAll()
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
                }
            }

            Text("If any of these are happening, do not wait for the app. Call \(EmergencyContactInfo.number) or your local emergency number.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(flags, id: \.self) { flag in
                Button {
                    if checkedFlags.contains(flag) {
                        checkedFlags.remove(flag)
                    } else {
                        checkedFlags.insert(flag)
                    }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: checkedFlags.contains(flag) ? "checkmark.circle.fill" : "circle")
                            .font(.headline)
                            .foregroundStyle(checkedFlags.contains(flag) ? .red : Color.chillSecondary)

                        Text(flag)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(Color.chillText)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .glassSurface(radius: 18, tint: (checkedFlags.contains(flag) ? Color.red : Color.black).opacity(0.06), interactive: true)
                }
                .buttonStyle(ChillPlainButtonStyle())
            }

            Button(role: .destructive) {
                guard let url = EmergencyContactInfo.dialURL else { return }
                UIApplication.shared.open(url)
            } label: {
                Label("Call \(EmergencyContactInfo.number)", systemImage: "phone.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChillPillButtonStyle(prominent: true, tint: .red))
        }
        .padding(16)
        .glassSurface(radius: 28, tint: .red.opacity(0.08), interactive: true)
        .accessibilityElement(children: .contain)
    }
}

struct ClinicalReviewNoticeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Clinical review note", systemImage: "checkmark.seal.text.page.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("ChillMate avoids calling combinations safe. It shows risk signals and source links to help you make more informed choices.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: 24, tint: Color.chillMint.opacity(0.08))
    }
}

struct CareSectionTitle: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(LinearGradient.chillBrand)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.chillText)
        }
    }
}

struct CareEmptyState: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(Color.chillSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassSurface(radius: 24, tint: .black.opacity(0.04))
    }
}
