import Foundation
import SwiftData
import SwiftUI

struct UnifiedTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(ChillMateQueries.recentEntries) private var entries: [NightEntry]
    @Query(ChillMateQueries.recentJournalEntries) private var journalEntries: [JournalEntry]
    @Query(ChillMateQueries.recentTimers) private var timers: [DrugDoseTimerRecord]
    @Query(ChillMateQueries.recentPlansByDate) private var plans: [SaferSessionPlan]
    @Query(ChillMateQueries.recentTests) private var tests: [STDTestRecord]

    private var events: [UnifiedTimelineEvent] {
        var result: [UnifiedTimelineEvent] = []
        result += entries.map {
            UnifiedTimelineEvent(
                date: $0.date,
                title: $0.skippedNight ? "Skipped Chill check" : "Chill log",
                detail: $0.skippedNight ? "Marked as skipped" : "\($0.partnerSummary), \($0.substances.isEmpty ? "no substances" : $0.substances.joined(separator: ", "))",
                symbol: $0.skippedNight ? "moon.zzz.fill" : "heart.text.square.fill",
                tint: $0.skippedNight ? Color.chillIconPurple : Color.chillIconPink
            )
        }
        result += journalEntries.map {
            UnifiedTimelineEvent(date: $0.date, title: String(localized: "Journal"), detail: $0.rememberClearly.isEmpty ? "Saved reflection" : $0.rememberClearly, symbol: "book.closed.fill", tint: Color.chillIconPurple)
        }
        result += timers.map {
            let route = AdministrationRoute(rawValue: $0.administrationRoute)?.displayName ?? "Saved route"
            return UnifiedTimelineEvent(date: $0.startedAt, title: "\($0.substanceName) check-in", detail: "\(route), \($0.durationHours.formatted(.number.precision(.fractionLength(0...1)))) h reminder", symbol: "timer", tint: Color.chillIconAmber)
        }
        result += plans.map {
            UnifiedTimelineEvent(date: $0.plannedDate, title: String(localized: "Before-Chill plan"), detail: $0.transportPlan.isEmpty ? "Ends \($0.endingDate.formatted(date: .omitted, time: .shortened))" : $0.transportPlan, symbol: "checkmark.shield.fill", tint: Color.chillMint)
        }
        result += tests.map {
            UnifiedTimelineEvent(date: $0.testDate, title: String(localized: "STI test"), detail: $0.hasPositiveResult ? "Positive result saved" : "Results \($0.resultsDueDate.formatted(date: .abbreviated, time: .omitted))", symbol: "cross.case.fill", tint: Color.chillIconTeal)
        }
        return result.sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PageHeader(title: String(localized: "Full timeline"), subtitle: String(localized: "One private timeline with logs, journal notes, plans, timers, and STI tests."), symbol: "timeline.selection", tint: Color.chillSecondaryBlue)
                        if events.isEmpty {
                            Text("Nothing has been saved yet.")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Color.chillSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .glassSurface(radius: 24, tint: .black.opacity(0.04))
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(Array(events.prefix(80))) { event in
                                    UnifiedTimelineEventRow(event: event)
                                }
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

private struct UnifiedTimelineEvent: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
}

private struct UnifiedTimelineEventRow: View {
    let event: UnifiedTimelineEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(event.tint)
                .frame(width: 36, height: 36)
                .glassSurface(radius: 18, tint: event.tint.opacity(0.12))
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title).font(.headline).foregroundStyle(Color.chillText)
                Text(event.detail).font(.caption.weight(.semibold)).foregroundStyle(Color.chillSecondary).lineLimit(2)
                Text(event.date.formatted(date: .abbreviated, time: .shortened)).font(.caption2.weight(.bold)).foregroundStyle(Color.chillTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassSurface(radius: 22, tint: event.tint.opacity(0.08))
    }
}

struct PrivacyTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(DefaultsKey.lastICloudBackupTimestamp) private var lastICloudBackupTimestamp = 0.0
    @AppStorage(DefaultsKey.lastICloudRestoreTimestamp) private var lastICloudRestoreTimestamp = 0.0
    @AppStorage(DefaultsKey.lastOnDeviceRecoverySnapshotTimestamp) private var lastOnDeviceRecoverySnapshotTimestamp = 0.0
    @AppStorage(DefaultsKey.lastOnDeviceRecoveryRestoreTimestamp) private var lastOnDeviceRecoveryRestoreTimestamp = 0.0
    @AppStorage(DefaultsKey.lastAppUseTimestamp) private var lastAppUseTimestamp = 0.0
    @AppStorage(DefaultsKey.lastOnDeviceRecoveryStatus) private var lastOnDeviceRecoveryStatus = ""
    @AppStorage(DefaultsKey.lastICloudBackupStatus) private var lastICloudBackupStatus = ""
    @AppStorage(DefaultsKey.requiresFaceID) private var requiresFaceID = false
    @AppStorage(DefaultsKey.requiresPIN) private var requiresPIN = false
    @AppStorage(DefaultsKey.iCloudBackupEnabled) private var iCloudBackupEnabled = false
    @AppStorage(DefaultsKey.discreetNotifications) private var discreetNotifications = false

    private var rows: [PrivacyTimelineRowModel] {
        [
            PrivacyTimelineRowModel(title: String(localized: "iCloud backup"), detail: iCloudBackupEnabled ? statusText(lastICloudBackupStatus, fallback: String(localized: "Enabled")) : String(localized: "Off"), date: date(from: lastICloudBackupTimestamp), symbol: "icloud.and.arrow.up.fill", tint: Color.chillSecondaryBlue),
            PrivacyTimelineRowModel(title: String(localized: "iCloud restore"), detail: String(localized: "Latest restore attempt"), date: date(from: lastICloudRestoreTimestamp), symbol: "icloud.and.arrow.down.fill", tint: Color.chillIconTeal),
            PrivacyTimelineRowModel(title: String(localized: "iPhone recovery backup"), detail: statusText(lastOnDeviceRecoveryStatus, fallback: "Automatic encrypted snapshot"), date: date(from: lastOnDeviceRecoverySnapshotTimestamp), symbol: "externaldrive.fill.badge.checkmark", tint: Color.chillMint),
            PrivacyTimelineRowModel(title: String(localized: "Recovery restore"), detail: String(localized: "Recovered after reinstall when available"), date: date(from: lastOnDeviceRecoveryRestoreTimestamp), symbol: "arrow.counterclockwise.circle.fill", tint: Color.chillIconPurple),
            PrivacyTimelineRowModel(title: String(localized: "App lock"), detail: requiresFaceID || requiresPIN ? "Face ID or PIN is on" : "No extra app lock is on", date: nil, symbol: "lock.shield.fill", tint: Color.chillMint),
            PrivacyTimelineRowModel(title: String(localized: "Notifications"), detail: discreetNotifications ? "Discreet text is on" : "Detailed text may show", date: nil, symbol: "bell.badge.fill", tint: Color.chillIconAmber),
            PrivacyTimelineRowModel(title: String(localized: "Last opened"), detail: String(localized: "Latest app activity saved locally"), date: date(from: lastAppUseTimestamp), symbol: "iphone", tint: Color.chillSecondaryBlue)
        ]
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PageHeader(title: String(localized: "Privacy timeline"), subtitle: String(localized: "A simple history of backups, restores, lock choices, and app privacy settings."), symbol: "clock.badge.checkmark.fill", tint: Color.chillIconTeal)
                        VStack(spacing: 10) {
                            ForEach(rows) { row in PrivacyTimelineRow(row: row) }
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

    private func date(from timestamp: Double) -> Date? { timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil }
    private func statusText(_ status: String, fallback: String) -> String { status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : status }
}

private struct PrivacyTimelineRowModel: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let date: Date?
    let symbol: String
    let tint: Color
}

private struct PrivacyTimelineRow: View {
    let row: PrivacyTimelineRowModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: row.symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(row.tint)
                .frame(width: 36, height: 36)
                .glassSurface(radius: 18, tint: row.tint.opacity(0.12))
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title).font(.headline).foregroundStyle(Color.chillText)
                Text(row.detail).font(.caption.weight(.semibold)).foregroundStyle(Color.chillSecondary).fixedSize(horizontal: false, vertical: true)
                if let date = row.date {
                    Text(date.formatted(date: .abbreviated, time: .shortened)).font(.caption2.weight(.bold)).foregroundStyle(Color.chillTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassSurface(radius: 22, tint: row.tint.opacity(0.08))
    }
}
