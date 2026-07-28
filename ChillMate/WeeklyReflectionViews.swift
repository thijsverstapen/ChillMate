import Foundation
import SwiftData
import SwiftUI

// Weekly reflection views extracted from CareToolsView.swift as part of splitting that file.

struct WeeklyReflectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(ChillMateQueries.recentEntries) private var entries: [NightEntry]
    @Query(ChillMateQueries.recentJournalEntries) private var journalEntries: [JournalEntry]
    @AppStorage(DefaultsKey.appLanguage) private var appLanguage = "en"
    @State private var aiReflection: String?
    @State private var didRequestReflection = false

    private var recentEntries: [NightEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        return entries.filter { $0.date >= cutoff }
    }

    private var recentJournals: [JournalEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        return journalEntries.filter { $0.date >= cutoff }
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PageHeader(title: String(localized: "Weekly reflection"), subtitle: String(localized: "A quick look at the last 7 days, made for noticing patterns without judging yourself."), symbol: "calendar.badge.clock", tint: Color.chillIconPurple)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            WeeklyReflectionMetric(title: String(localized: "Chills"), value: "\(recentEntries.filter { !$0.skippedNight }.count)", symbol: "heart.text.square.fill", tint: Color.chillIconPink)
                            WeeklyReflectionMetric(title: String(localized: "Substance logs"), value: "\(recentEntries.filter { !$0.substances.isEmpty }.count)", symbol: "pills.fill", tint: Color.chillSecondaryBlue)
                            WeeklyReflectionMetric(title: String(localized: "Journals"), value: "\(recentJournals.count)", symbol: "book.closed.fill", tint: Color.chillIconPurple)
                            WeeklyReflectionMetric(title: String(localized: "Memory gaps"), value: "\(recentEntries.filter(\.reportedMemoryGap).count)", symbol: "questionmark.circle.fill", tint: Color.chillIconOrange)
                        }
                        if OnDeviceAffirmationService.isAvailable {
                            VStack(alignment: .leading, spacing: 10) {
                                CareSectionTitle(title: String(localized: "This week, in a few words"), symbol: "sparkles.rectangle.stack.fill")

                                if let aiReflection {
                                    Text(aiReflection)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.chillText)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    HStack(spacing: 10) {
                                        ProgressView()
                                        Text("Writing your private reflection…")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.chillSecondary)
                                    }
                                }

                                Text("Generated on this iPhone from this week's counts only. Nothing leaves your device.")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.chillTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .glassSurface(radius: 24, tint: Color.chillMint.opacity(0.08))
                            .task { await generateReflectionIfNeeded() }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            CareSectionTitle(title: String(localized: "Gentle prompts"), symbol: "sparkles")
                            WeeklyPrompt(text: String(localized: "What felt easier this week than expected?"))
                            WeeklyPrompt(text: String(localized: "Was there a moment where you needed support sooner?"))
                            WeeklyPrompt(text: String(localized: "What is one small boundary that would help next time?"))
                        }
                        .padding(14)
                        .glassSurface(radius: 24, tint: Color.chillIconPurple.opacity(0.08))
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func generateReflectionIfNeeded() async {
        guard !didRequestReflection else { return }
        didRequestReflection = true

        let sleepValues = recentEntries.filter { $0.sleptYet && $0.sleepHours > 0 }.map(\.sleepHours)
        let averageSleep = sleepValues.isEmpty ? nil : sleepValues.reduce(0, +) / Double(sleepValues.count)

        aiReflection = await OnDeviceAffirmationService.generateWeeklyReflection(
            chillCount: recentEntries.filter { !$0.skippedNight }.count,
            substanceLogCount: recentEntries.filter { !$0.substances.isEmpty }.count,
            journalCount: recentJournals.count,
            memoryGapCount: recentEntries.filter(\.reportedMemoryGap).count,
            averageSleepHours: averageSleep,
            languageCode: appLanguage
        )
    }
}

private struct WeeklyReflectionMetric: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .glassSurface(radius: 16, tint: tint.opacity(0.12))
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title3.weight(.bold)).foregroundStyle(Color.chillText).monospacedDigit()
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(Color.chillSecondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .glassSurface(radius: 20, tint: tint.opacity(0.08))
    }
}

private struct WeeklyPrompt: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.chillIconPurple)
                .padding(.top, 2)
            Text(text)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.chillText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.20), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
