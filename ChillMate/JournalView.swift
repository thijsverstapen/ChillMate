import Foundation
import PhotosUI
import MapKit
import SwiftData
import SwiftUI
import UIKit

// Journal feature views extracted from CareToolsView.swift as part of splitting that file.

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var journalEntries: [JournalEntry]

    @State private var date = Date.now
    @State private var rememberClearly = ""
    @State private var uncomfortableMoments = ""
    @State private var consentConcerns = ""
    @State private var regrets = ""
    @State private var feelsGoodAbout = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoData: [Data] = []
    @State private var isShowingMorePrompts = false
    @State private var isEditing = false
    @State private var isShowingMonthCalendar = false
    @State private var journalHaptic: SensoryFeedback?
    @State private var journalHapticTick = 0

    /// When false, the view renders its content without its own NavigationStack so
    /// it can be embedded inside the History tab's stack (no nested stacks).
    let embedsOwnStack: Bool

    init(embedsOwnStack: Bool = true) {
        self.embedsOwnStack = embedsOwnStack
    }

    private var selectedJournalEntry: JournalEntry? {
        journalEntries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    /// Drives whether the day shows a read-only overview or the editable form.
    private var mode: JournalMode {
        if selectedJournalEntry == nil { return .new }
        return isEditing ? .editing : .viewing
    }

    var body: some View {
        if embedsOwnStack {
            NavigationStack { journalContent }
        } else {
            journalContent
        }
    }

    @ViewBuilder
    private var journalContent: some View {
        // Local `let` (not a main-actor property) so the @Sendable PhotosPicker
        // label closure can capture it by value without a concurrency warning.
        let photoPickerTitle = photoData.count == 0
            ? String(localized: "Add photos")
            : "\(photoData.count) photo\(photoData.count == 1 ? "" : "s")"

        ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Journal"),
                            subtitle: String(localized: "Pick a day, write the few things you want to remember, and come back anytime to edit."),
                            symbol: "book.closed.fill",
                            tint: Color.chillPrimary
                        )
                        .sensoryFeedback(trigger: journalHapticTick) { _, _ in journalHaptic }
                        .disablesRootSwipeBack()

                        VStack(alignment: .leading, spacing: 12) {
                            JournalWeekStrip(selectedDate: $date, entries: journalEntries)
                                .disabled(mode == .editing)

                            HStack(spacing: 10) {
                                Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                    .font(.headline)
                                    .foregroundStyle(Color.chillText)

                                Spacer(minLength: 0)

                                Button {
                                    isShowingMonthCalendar = true
                                } label: {
                                    Image(systemName: "calendar")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.chillPrimary)
                                        .frame(width: 34, height: 34)
                                        .background(Color.chillPrimary.opacity(0.14), in: Circle())
                                        .contentShape(Circle())
                                }
                                .buttonStyle(ChillPlainButtonStyle())
                                .disabled(mode == .editing)
                                .opacity(mode == .editing ? 0.4 : 1)
                                .accessibilityLabel("Open month calendar")

                                JournalStatusPill(mode: mode)
                            }

                            if mode == .viewing, let entry = selectedJournalEntry {
                                // ── Read-only overview of the saved day ──
                                JournalEntryOverview(entry: entry)

                                HStack(spacing: 10) {
                                    GlassActionButton(prominent: true, action: beginEditing) {
                                        Label("Edit entry", systemImage: "pencil")
                                            .font(.headline)
                                            .frame(maxWidth: .infinity)
                                    }

                                    GlassActionButton(prominent: false, tint: .red, action: deleteJournalEntry) {
                                        Image(systemName: "trash.fill")
                                    }
                                    .accessibilityLabel("Delete entry")
                                }
                            } else {
                                // ── Editable form (new entry, or editing an existing one) ──
                                JournalPromptField(title: String(localized: "What do you remember?"), text: $rememberClearly)
                                JournalPromptField(title: String(localized: "How do you feel about it now?"), text: $feelsGoodAbout)
                                JournalPromptField(title: String(localized: "Any safety or consent concerns?"), text: $consentConcerns)

                                DisclosureGroup(isExpanded: $isShowingMorePrompts) {
                                    VStack(spacing: 10) {
                                        JournalPromptField(title: String(localized: "Any uncomfortable moments?"), text: $uncomfortableMoments)
                                        JournalPromptField(title: String(localized: "Regrets or loose ends"), text: $regrets)
                                    }
                                    .padding(.top, 8)
                                } label: {
                                    Label("Any regrets?", systemImage: "chevron.down.circle.fill")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.chillText)
                                }
                                .tint(Color.chillPrimary)
                                .padding(12)
                                .background(.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                                HStack(spacing: 10) {
                                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 6, matching: .images) {
                                        Label(photoPickerTitle, systemImage: "photo.on.rectangle.angled")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(ChillPillButtonStyle(prominent: false))
                                    .onChange(of: selectedPhotos) { _, items in
                                        loadPhotos(items)
                                    }
                                }

                                HStack(spacing: 10) {
                                    GlassActionButton(prominent: true, action: saveJournalEntry) {
                                        Label(mode == .editing ? "Save changes" : "Save journal", systemImage: "checkmark.circle.fill")
                                            .font(.headline)
                                            .frame(maxWidth: .infinity)
                                    }

                                    if mode == .editing {
                                        GlassActionButton(prominent: false, action: cancelEditing) {
                                            Text("Cancel")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("")
            .endEditingOnTap()
            .onAppear(perform: loadSelectedJournalEntry)
            .onChange(of: date) { _, _ in
                isEditing = false
                loadSelectedJournalEntry()
            }
            .sheet(isPresented: $isShowingMonthCalendar) {
                JournalMonthCalendarSheet(date: $date)
            }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) {
        Task {
            var loaded: [Data] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let optimizedData = await ChillImageOptimizer.downsampledJPEG(from: data, maxPixelSize: 1200, compressionQuality: 0.80)
                    loaded.append(optimizedData)
                }
            }
            photoData = loaded
        }
    }

    private func saveJournalEntry() {
        journalHaptic = .impact(weight: .medium)
        journalHapticTick += 1

        if let entry = selectedJournalEntry {
            entry.rememberClearly = rememberClearly.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.uncomfortableMoments = uncomfortableMoments.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.consentConcerns = consentConcerns.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.regrets = regrets.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.feelsGoodAbout = feelsGoodAbout.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.photos = photoData
            modelContext.saveChanges()
            SpotlightService.shared.indexJournalEntry(entry)
        } else {
            let entry = JournalEntry(
                date: date,
                rememberClearly: rememberClearly.trimmingCharacters(in: .whitespacesAndNewlines),
                uncomfortableMoments: uncomfortableMoments.trimmingCharacters(in: .whitespacesAndNewlines),
                consentConcerns: consentConcerns.trimmingCharacters(in: .whitespacesAndNewlines),
                regrets: regrets.trimmingCharacters(in: .whitespacesAndNewlines),
                feelsGoodAbout: feelsGoodAbout.trimmingCharacters(in: .whitespacesAndNewlines),
                photos: photoData
            )
            modelContext.insert(entry)
            modelContext.saveChanges()
            SpotlightService.shared.indexJournalEntry(entry)
        }

        // Saved → drop back to the read-only overview for the day.
        withAnimation(.snappy) { isEditing = false }
    }

    private func beginEditing() {
        journalHaptic = .impact(weight: .light)
        journalHapticTick += 1
        loadSelectedJournalEntry()
        withAnimation(.snappy) { isEditing = true }
    }

    private func cancelEditing() {
        loadSelectedJournalEntry() // discard unsaved edits
        withAnimation(.snappy) { isEditing = false }
    }

    private func deleteJournalEntry() {
        guard let entry = selectedJournalEntry else { return }
        journalHaptic = .warning
        journalHapticTick += 1
        SpotlightService.shared.removeJournalEntry(entry)
        modelContext.delete(entry)
        modelContext.saveChanges()
        isEditing = false
        loadSelectedJournalEntry()
    }

    private func loadSelectedJournalEntry() {
        guard let entry = selectedJournalEntry else {
            rememberClearly = ""
            uncomfortableMoments = ""
            consentConcerns = ""
            regrets = ""
            feelsGoodAbout = ""
            selectedPhotos = []
            photoData = []
            return
        }

        rememberClearly = entry.rememberClearly
        uncomfortableMoments = entry.uncomfortableMoments
        consentConcerns = entry.consentConcerns
        regrets = entry.regrets
        feelsGoodAbout = entry.feelsGoodAbout
        selectedPhotos = []
        photoData = entry.photos
    }
}

enum HistorySegment: String, CaseIterable, Identifiable {
    case calendar
    case journal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: String(localized: "Calendar")
        case .journal: String(localized: "Journal")
        }
    }
}

/// The merged "History" tab: one navigation stack that shows either the calendar
/// overview or the journal, switched by a segmented control. Both children render
/// stack-free content, so nothing nests (which would blank the screen).
struct HistoryTabView: View {
    @Binding var segment: HistorySegment

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                VStack(spacing: 0) {
                    Picker("", selection: $segment) {
                        ForEach(HistorySegment.allCases) { seg in
                            Text(seg.title).tag(seg)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                    .disablesRootSwipeBack()

                    switch segment {
                    case .calendar:
                        CalendarOverviewView(showsBackButton: false)
                    case .journal:
                        JournalView(embedsOwnStack: false)
                    }
                }
            }
        }
    }
}

/// A quick month-view calendar so a day can be found without scrolling the strip.
private struct JournalMonthCalendarSheet: View {
    @Binding var date: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                VStack(spacing: 16) {
                    DatePicker(
                        "",
                        selection: $date,
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(Color.chillPrimary)
                    .padding(8)
                    .glassSurface(radius: 24, tint: .black.opacity(0.04))

                    Spacer(minLength: 0)
                }
                .padding(20)
            }
            .navigationTitle("Pick a date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct JournalWeekStrip: View {
    @Binding var selectedDate: Date
    let entries: [JournalEntry]

    private var calendar: Calendar { .current }

    /// A rolling range of days the user can scroll horizontally through (roughly
    /// the last ten weeks up to the end of the current week). This replaces the
    /// old static single-week row and the separate date picker.
    private var days: [Date] {
        let today = calendar.startOfDay(for: Date.now)
        let startSeed = calendar.date(byAdding: .weekOfYear, value: -9, to: today) ?? today
        guard let startInterval = calendar.dateInterval(of: .weekOfYear, for: startSeed),
              let endInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        }

        var result: [Date] = []
        var day = startInterval.start
        while day < endInterval.end {
            result.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        dayCell(day).id(day)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                DispatchQueue.main.async { scroll(to: selectedDate, with: proxy, animated: false) }
            }
            .onChange(of: selectedDate) { _, newValue in
                scroll(to: newValue, with: proxy, animated: true)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let hasEntry = entries.contains { calendar.isDate($0.date, inSameDayAs: day) }

        return Button {
            selectedDate = day
        } label: {
            VStack(spacing: 4) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? .white.opacity(0.80) : Color.chillSecondary)
                Text(day.formatted(.dateTime.day()))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? .white : Color.chillText)
                Circle()
                    .fill(hasEntry ? (isSelected ? .white.opacity(0.72) : Color.chillMint) : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 46, height: 58)
            .background(
                isSelected ? Color.chillPrimary : Color.clear,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(ChillPlainButtonStyle())
        .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted))\(hasEntry ? ", journal entry saved" : "")")
    }

    private func scroll(to date: Date, with proxy: ScrollViewProxy, animated: Bool) {
        let target = calendar.startOfDay(for: date)
        if animated {
            withAnimation(.snappy) { proxy.scrollTo(target, anchor: .center) }
        } else {
            proxy.scrollTo(target, anchor: .center)
        }
    }
}

private enum JournalMode { case new, viewing, editing }

private struct JournalStatusPill: View {
    let mode: JournalMode

    private var content: (title: String, symbol: String, tint: Color) {
        switch mode {
        case .new: ("New", "plus.circle.fill", Color.chillSecondaryBlue)
        case .viewing: ("Saved", "checkmark.seal.fill", Color.chillMint)
        case .editing: ("Editing", "pencil.circle.fill", Color.chillPrimary)
        }
    }

    var body: some View {
        let c = content
        Label(c.title, systemImage: c.symbol)
            .font(.caption.weight(.bold))
            .foregroundStyle(c.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(c.tint.opacity(0.12), in: Capsule())
    }
}

/// Read-only summary of a saved journal day — shown instead of the input form
/// once a day has an entry, so a saved day reads as a finished overview rather
/// than a blank form that looks like it still needs input.
private struct JournalEntryOverview: View {
    let entry: JournalEntry

    private var answeredPrompts: [(prompt: String, answer: String)] {
        [
            ("What do you remember?", entry.rememberClearly),
            ("How do you feel about it now?", entry.feelsGoodAbout),
            ("Any safety or consent concerns?", entry.consentConcerns),
            ("Any uncomfortable moments?", entry.uncomfortableMoments),
            ("Regrets or loose ends", entry.regrets)
        ].filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if answeredPrompts.isEmpty && entry.photos.isEmpty {
                Text("No details saved for this day yet. Tap Edit to add some.")
                    .font(.subheadline)
                    .foregroundStyle(Color.chillSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(answeredPrompts.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.prompt)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.chillSecondary)
                        Text(item.answer)
                            .font(.subheadline)
                            .foregroundStyle(Color.chillText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if !entry.photos.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(entry.photos.enumerated()), id: \.offset) { _, data in
                            if let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct JournalPromptField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.chillMint)

            TextField(title, text: $text, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.chillText)
                .padding(12)
                .glassSurface(radius: 16, tint: .black.opacity(0.04), interactive: true)
        }
    }
}

private struct JournalEntryCard: View {
    @Environment(\.modelContext) private var modelContext
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .foregroundStyle(Color.chillText)

                Spacer()

                Button(role: .destructive) {
                    RecentlyDeletedStore.record(
                        kind: "Journal",
                        title: String(localized: "Journal entry"),
                        detail: entry.date.formatted(date: .abbreviated, time: .omitted)
                    )
                    modelContext.delete(entry)
                    modelContext.saveChanges()
                } label: {
                    Image(systemName: "trash.fill")
                }
                .buttonStyle(ChillPlainButtonStyle())
                .foregroundStyle(Color.chillSecondary)
            }

            JournalLine(title: String(localized: "Clear memory"), value: entry.rememberClearly)
            JournalLine(title: String(localized: "Uncomfortable"), value: entry.uncomfortableMoments)
            JournalLine(title: String(localized: "Consent"), value: entry.consentConcerns)
            JournalLine(title: String(localized: "Regrets"), value: entry.regrets)
            JournalLine(title: String(localized: "Good"), value: entry.feelsGoodAbout)

            if !entry.photos.isEmpty {
                Text("\(entry.photos.count) picture\(entry.photos.count == 1 ? "" : "s")")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillPrimary)
            }
        }
        .padding(16)
        .glassSurface(radius: 24, tint: .black.opacity(0.04))
    }
}

private struct JournalLine: View {
    let title: String
    let value: String

    var body: some View {
        if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondary)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(Color.chillText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
