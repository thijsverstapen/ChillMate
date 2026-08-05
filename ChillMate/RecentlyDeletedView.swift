import Foundation
import SwiftUI

struct RecentlyDeletedView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items = RecentlyDeletedStore.items()

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PageHeader(title: String(localized: "Recently deleted"), subtitle: String(localized: "This list helps you remember what was removed. To restore actual data, use an encrypted backup."), symbol: "trash.circle.fill", tint: Color.chillIconOrange)
                        if items.isEmpty {
                            Text("No deleted items have been recorded.")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Color.chillSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .glassSurface(radius: 24, tint: .black.opacity(0.04))
                        } else {
                            VStack(spacing: 10) { ForEach(items) { RecentlyDeletedRow(item: $0) } }
                            GlassActionButton(prominent: false) {
                                RecentlyDeletedStore.clear()
                                items = []
                            } label: {
                                Label("Clear this list", systemImage: "trash")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

private struct RecentlyDeletedRow: View {
    let item: RecentlyDeletedItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "trash.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.chillIconOrange)
                .frame(width: 36, height: 36)
                .glassSurface(radius: 18, tint: Color.chillIconOrange.opacity(0.12))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline).foregroundStyle(Color.chillText)
                Text(item.detail).font(.caption.weight(.semibold)).foregroundStyle(Color.chillSecondary).fixedSize(horizontal: false, vertical: true)
                Text("\(item.kind) • \(item.deletedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption2.weight(.bold)).foregroundStyle(Color.chillTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassSurface(radius: 22, tint: Color.chillIconOrange.opacity(0.08))
    }
}
