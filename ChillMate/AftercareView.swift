import Foundation
import SwiftData
import SwiftUI

struct AftercareView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(ChillMateQueries.recentEntries) private var entries: [NightEntry]

    private var trackedEntries: [NightEntry] {
        entries.filter { $0.hadSex && !$0.skippedNight }
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Aftercare"),
                            subtitle: String(localized: "A softer next-day check-in for sleep, feelings, and emotional care. Start with sleep, water, food, and symptoms; add what feels useful and skip what does not."),
                            symbol: "heart.text.square.fill",
                            tint: Color.chillAccentTeal
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tiny care plan")
                                .font(.headline)
                                .foregroundStyle(Color.chillText)
                            Text("Drink water, eat something gentle, rest, and avoid judging yourself while your body settles. If something feels unsafe or too heavy, reach out to someone you trust or a professional helper.")
                                .font(.callout)
                                .foregroundStyle(Color.chillSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: Color.chillAccentTeal.opacity(0.10))

                        PrepGuideCard()

                        if trackedEntries.isEmpty {
                            CareEmptyState(text: String(localized: "No tracked Chills available for aftercare."))
                        } else {
                            ForEach(trackedEntries.prefix(12)) { entry in
                                AftercareEntryCard(entry: entry)
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .endEditingOnTap()
        }
    }
}

private struct AftercareEntryCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var entry: NightEntry
    @State private var isImportingSleep = false
    @State private var sleepImportMessage = ""
    @State private var didAutoImportSleep = false
    @AppStorage(DefaultsKey.healthKitSleepReadWriteEnabled) private var healthKitSleepReadWriteEnabled = false
    @AppStorage(DefaultsKey.healthKitAutoSync) private var healthKitAutoSync = false

    private var moodBinding: Binding<AftercareMood> {
        Binding {
            AftercareMood(rawValue: entry.aftercareMood) ?? .okay
        } set: { mood in
            entry.aftercareMood = mood.rawValue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)
                        .foregroundStyle(Color.chillText)
                    Text(entry.aftercareCompletedAt == nil ? String(localized: "Open check-in") : String(localized: "Completed"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(entry.aftercareCompletedAt == nil ? Color.chillAccentTeal : Color.chillMint)
                }

                Spacer()

                Text((AftercareMood(rawValue: entry.aftercareMood) ?? .okay).emoji)
                    .font(.largeTitle)
            }

            Toggle("Record sleep now", isOn: $entry.aftercareSleepRecorded)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.chillText)
                .tint(Color.chillMint)

            if entry.aftercareSleepRecorded {
                HStack {
                    Text("\(entry.aftercareSleepHours.formatted(.number.precision(.fractionLength(0...1)))) h")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)
                        .frame(width: 72, alignment: .leading)
                    Slider(value: $entry.aftercareSleepHours, in: 0...12, step: 0.5)
                        .tint(Color.chillMint)
                }
            }

            Button {
                importSleepFromHealth()
            } label: {
                Label(isImportingSleep ? "Reading Apple Health" : "Import sleep from Apple Health", systemImage: "heart.text.square.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChillPillButtonStyle(prominent: false))
            .disabled(isImportingSleep)

            if !sleepImportMessage.isEmpty {
                Text(sleepImportMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle("Drank water", isOn: $entry.aftercareDrankWater)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.chillText)
                .tint(Color.chillSecondaryBlue)

            Toggle("Ate something", isOn: $entry.aftercareAteFood)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.chillText)
                .tint(.orange)

            if entry.aftercareAteFood {
                TextField("What did you eat? Optional", text: $entry.aftercareFoodNote, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.chillText)
                    .padding(14)
                    .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)
            }

            aftercareDetailFields
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillAccentTeal.opacity(0.08), interactive: true)
        .task {
            // Auto-fill sleep from Apple Health once, only when the user granted sleep
            // reads and no sleep is known yet from any source (never overwrite a value
            // the user already entered manually or in the log sheet).
            guard healthKitSleepReadWriteEnabled, !didAutoImportSleep,
                  !entry.aftercareSleepRecorded, !entry.sleptYet, entry.sleepHours == 0 else { return }
            didAutoImportSleep = true
            importSleepFromHealth(autoImport: true)
        }
    }

    private func toggleSymptom(_ symptom: AftercareSymptom) {
        var symptoms = entry.aftercareSymptoms
        if symptoms.contains(symptom) {
            symptoms.removeAll { $0 == symptom }
        } else {
            symptoms.append(symptom)
        }
        entry.aftercareSymptoms = symptoms
    }

    private func importSleepFromHealth(autoImport: Bool = false) {
        isImportingSleep = true
        sleepImportMessage = ""

        Task {
            do {
                let end = Calendar.current.date(byAdding: .hour, value: 18, to: entry.endDate) ?? entry.endDate.addingTimeInterval(18 * 60 * 60)
                let hours = try await HealthKitService.shared.sleepHours(from: entry.endDate, to: end)

                // HealthKit returns 0 (not an error) when the window has no samples,
                // which is common for a just-ended or still-ongoing night. Never
                // overwrite an existing value with 0.
                guard hours > 0 else {
                    if !autoImport {
                        sleepImportMessage = String(localized: "No sleep found in Apple Health for this window yet.")
                    }
                    isImportingSleep = false
                    return
                }

                entry.aftercareSleepRecorded = true
                entry.aftercareSleepHours = hours
                entry.sleptYet = true
                entry.sleepHours = hours
                modelContext.saveChanges()

                if hours >= 6, (try? await NotificationService.shared.requestAuthorization()) == true {
                    NotificationService.shared.schedulePositiveSleepNotification(hours: hours)
                }

                sleepImportMessage = "Apple Health sleep: \(hours.formatted(.number.precision(.fractionLength(0...1)))) h."
            } catch {
                sleepImportMessage = error.localizedDescription
            }

            isImportingSleep = false
        }
    }

    /// Mood, symptoms, free-text and the save button, split out of a 150-line body.
    @ViewBuilder
    private var aftercareDetailFields: some View {
        Picker("Mood", selection: moodBinding) {
            ForEach(AftercareMood.allCases) { mood in
                Text("\(mood.emoji) \(mood.localizedDisplayName)").tag(mood)
            }
        }
        .pickerStyle(.menu)
        .tint(Color.chillAccentTeal)

        VStack(alignment: .leading, spacing: 10) {
            CareSectionTitle(title: String(localized: "Symptoms"), symbol: "heart.text.clipboard.fill")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 126), spacing: 10)], spacing: 10) {
                ForEach(AftercareSymptom.allCases) { symptom in
                    Button {
                        toggleSymptom(symptom)
                    } label: {
                        Text(symptom.localizedDisplayName)
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(ChillPlainButtonStyle())
                    .foregroundStyle(entry.aftercareSymptoms.contains(symptom) ? .white : Color.chillText)
                    .background {
                        Capsule()
                            .fill(entry.aftercareSymptoms.contains(symptom) ? Color.chillAccentTeal : Color.white.opacity(0.45))
                    }
                }
            }

            if !entry.aftercareSymptoms.isEmpty {
                SymptomInsightCard(symptoms: entry.aftercareSymptoms)
            }
        }

        TextField("How do you feel about last Chill?", text: $entry.aftercareFeeling, axis: .vertical)
            .lineLimit(2...5)
            .textFieldStyle(.plain)
            .foregroundStyle(Color.chillText)
            .padding(14)
            .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

        GlassActionButton(prominent: true) {
            entry.aftercareCompletedAt = .now
            if entry.aftercareSleepRecorded {
                entry.sleptYet = true
                entry.sleepHours = entry.aftercareSleepHours
            }
            modelContext.saveChanges()

            // Mirror the mood to Apple Health's State of Mind when the user
            // already syncs logs to Health. Failures stay silent because the
            // local check-in is the source of truth.
            if healthKitAutoSync {
                let mood = AftercareMood(rawValue: entry.aftercareMood) ?? .okay
                let completedAt = entry.aftercareCompletedAt ?? .now
                Task {
                    try? await HealthKitService.shared.saveStateOfMind(date: completedAt, mood: mood)
                }
            }
        } label: {
            Label("Save aftercare", systemImage: "checkmark.heart.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct SymptomInsightCard: View {
    let symptoms: [AftercareSymptom]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Most likely causes")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            ForEach(symptoms) { symptom in
                VStack(alignment: .leading, spacing: 2) {
                    Text(symptom.localizedDisplayName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.chillMint)
                    Text(symptom.likelyCause)
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassSurface(radius: 20, tint: Color.chillAccentTeal.opacity(0.09))
    }
}
