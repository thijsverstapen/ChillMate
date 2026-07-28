import Foundation
import SwiftData
import SwiftUI

struct DrugTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(DefaultsKey.drugTimerTrackedPeople) private var trackedPeopleData = Data("[]".utf8)
    @Query(ChillMateQueries.recentTimers) private var timers: [DrugDoseTimerRecord]
    @Query(ChillMateQueries.profile) private var profiles: [UserProfile]

    @State private var selectedSubstance: Substance = .cannabis
    @State private var timerScope: TimerScope = .myself
    @State private var selectedAdministrationRoute: AdministrationRoute?
    @State private var selectedTrackedPerson = ""
    @State private var newTrackedPerson = ""
    @State private var startedAt = Date.now
    @State private var doseNote = ""
    @State private var isShowingDiscardWarning = false
    @State private var saveHaptic = 0

    private let timerSubstances = Substance.allCases.filter { $0 != .unknown && $0 != .other }

    private var adjustedDefaultDuration: Double {
        guard let profile = profiles.first else {
            return selectedSubstance.defaultTimerHours
        }

        return selectedSubstance.adjustedTimerHours(weightKg: profile.weightKg, heightCm: profile.heightCm)
    }

    private var profileAdjustmentCaption: String {
        guard let profile = profiles.first else {
            return String(localized: "Add height and weight in Profile to personalize the reminder window.")
        }

        let kg = Int(profile.weightKg.rounded())
        let cm = Int(profile.heightCm.rounded())
        return String(localized: "Reminder window adjusted from \(kg) kg and \(cm) cm.")
    }

    private var trackedPeople: [String] {
        (try? JSONDecoder().decode([String].self, from: trackedPeopleData)) ?? []
    }

    private var visibleTimers: [DrugDoseTimerRecord] {
        timers.filter { timer in
            let isOther = !timer.personName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return timerScope == .myself ? !isOther : isOther
        }
    }

    private var canStartTimer: Bool {
        selectedAdministrationRoute != nil &&
        (timerScope == .myself || !selectedTrackedPerson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var hasUnsavedChanges: Bool {
        selectedSubstance != .cannabis ||
        timerScope != .myself ||
        selectedAdministrationRoute != nil ||
        !selectedTrackedPerson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !newTrackedPerson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !Calendar.current.isDate(startedAt, equalTo: .now, toGranularity: .minute) ||
        !doseNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Check-in timers"),
                            subtitle: String(localized: "Set private wellbeing reminders after a substance-related log. This is for reflection and support, not dosing advice or a safety approval."),
                            symbol: "timer",
                            tint: Color.chillSecondaryBlue
                        )
                        .sensoryFeedback(.impact(flexibility: .rigid), trigger: saveHaptic)

                        MedicalSafetyDisclaimerCard(compact: true)

                        VStack(alignment: .leading, spacing: 14) {
                            Picker("Timer type", selection: $timerScope) {
                                ForEach(TimerScope.allCases) { scope in
                                    Text(scope.localizedDisplayName).tag(scope)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(4)
                            .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                            if timerScope == .others {
                                TimerPeopleManager(
                                    people: trackedPeople,
                                    selectedPerson: $selectedTrackedPerson,
                                    newPerson: $newTrackedPerson,
                                    addPerson: addTrackedPerson,
                                    removePerson: removeTrackedPerson
                                )
                            }

                            Picker("Substance", selection: $selectedSubstance) {
                                ForEach(timerSubstances) { substance in
                                    Text(substance.localizedDisplayName).tag(substance)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color.chillSecondaryBlue)

                            AdministrationRoutePicker(selectedRoute: $selectedAdministrationRoute)

                            DatePicker("Taken at", selection: $startedAt, displayedComponents: [.date, .hourAndMinute])
                                .tint(Color.chillSecondaryBlue)

                            StaticEffectWindowSummary(
                                substance: selectedSubstance,
                                adjustedDuration: adjustedDefaultDuration,
                                profileCaption: profileAdjustmentCaption
                            )

                            TextField("Private note, optional", text: $doseNote)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color.chillText)
                                .padding(14)
                                .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                            GlassActionButton(prominent: true, action: startTimer) {
                                Label("Start check-in", systemImage: "timer.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(!canStartTimer)
                            .opacity(canStartTimer ? 1 : 0.55)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                        .padding(16)
                        .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.10), interactive: true)

                        VStack(alignment: .leading, spacing: 12) {
                            CareSectionTitle(title: String(localized: "Current and past check-ins"), symbol: "clock.arrow.circlepath")

                            let activeTimers = visibleTimers.filter { $0.endsAt > .now }
                            let pastTimers = visibleTimers.filter { $0.endsAt <= .now }

                            if visibleTimers.isEmpty {
                                CareEmptyState(text: String(localized: "No timers yet."))
                            } else {
                                if !activeTimers.isEmpty {
                                    TimelineView(.periodic(from: .now, by: 60)) { context in
                                        LazyVStack(spacing: 12) {
                                            ForEach(activeTimers) { timer in
                                                DrugTimerCard(timer: timer, now: context.date)
                                            }
                                        }
                                    }
                                }

                                if !pastTimers.isEmpty {
                                    LazyVStack(spacing: 12) {
                                        ForEach(pastTimers) { timer in
                                            DrugTimerCard(timer: timer, now: .now)
                                        }
                                    }
                                }
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: startTimer) {
                        Text("Start").font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(Color.chillPrimary)
                    .disabled(!canStartTimer)
                    .opacity(canStartTimer ? 1 : 0.5)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .chillMateRefreshTimers)) { _ in
                Task { @MainActor in
                    for timer in timers where !timer.liveActivityID.isEmpty {
                        await DrugTimerLiveActivityController.update(timer)
                    }
                }
            }
            .endEditingOnTap()
        }
    }

    private func startTimer() {
        guard let route = selectedAdministrationRoute else {
            return
        }

        let timer = DrugDoseTimerRecord(
            substanceName: selectedSubstance.rawValue,
            startedAt: startedAt,
            durationHours: adjustedDefaultDuration,
            administrationRoute: route,
            personName: timerScope == .others ? selectedTrackedPerson.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            doseNote: doseNote.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        saveHaptic += 1
        modelContext.insert(timer)
        modelContext.saveChanges()
        DrugTimerLiveActivityController.start(for: timer)
        modelContext.saveChanges()
        syncTimersToWatch()

        Task {
            if (try? await NotificationService.shared.requestAuthorization()) == true {
                NotificationService.shared.scheduleSessionCheckIns(
                    id: timer.id,
                    startsAt: timer.startedAt,
                    endsAt: timer.endsAt,
                    destination: .timers
                )
                NotificationService.shared.scheduleRedoseNudge(
                    id: timer.id,
                    startsAt: timer.startedAt,
                    durationHours: timer.durationHours
                )
            }
        }

        selectedSubstance = .cannabis
        selectedAdministrationRoute = nil
        startedAt = .now
        doseNote = ""
    }

    private func syncTimersToWatch() {
        let all = modelContext.fetchLogging(FetchDescriptor<DrugDoseTimerRecord>())
        WatchConnectivityService.shared.sendActiveTimers(all)
    }

    private func addTrackedPerson() {
        let name = newTrackedPerson.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return
        }

        var people = trackedPeople
        if !people.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            people.append(name)
            saveTrackedPeople(people)
        }
        selectedTrackedPerson = name
        newTrackedPerson = ""
    }

    private func removeTrackedPerson(_ name: String) {
        let people = trackedPeople.filter { $0 != name }
        saveTrackedPeople(people)
        if selectedTrackedPerson == name {
            selectedTrackedPerson = people.first ?? ""
        }
    }

    private func saveTrackedPeople(_ people: [String]) {
        trackedPeopleData = (try? JSONEncoder().encode(people)) ?? Data("[]".utf8)
    }
}

private enum TimerScope: String, CaseIterable, Identifiable {
    case myself = "Myself"
    case others = "Others"

    var id: String { rawValue }
}

private struct TimerPeopleManager: View {
    let people: [String]
    @Binding var selectedPerson: String
    @Binding var newPerson: String
    let addPerson: () -> Void
    let removePerson: (String) -> Void

    private var canAdd: Bool {
        !newPerson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("People you support", systemImage: "person.2.badge.gearshape.fill")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            HStack(spacing: 10) {
                TextField("Add a name", text: $newPerson)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.chillText)
                    .padding(12)
                    .glassSurface(radius: 16, tint: .black.opacity(0.04), interactive: true)

                Button(action: addPerson) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(ChillPlainButtonStyle())
                .foregroundStyle(canAdd ? Color.chillSecondaryBlue : Color.chillTertiary)
                .disabled(!canAdd)
            }

            if people.isEmpty {
                Text("Add someone before starting an \"Others\" check-in.")
                    .font(.caption)
                    .foregroundStyle(Color.chillSecondary)
            } else {
                Picker("Person", selection: $selectedPerson) {
                    Text("Choose person").tag("")
                    ForEach(people, id: \.self) { person in
                        Text(person).tag(person)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.chillSecondaryBlue)

                FlowLayout(spacing: 8) {
                    ForEach(people, id: \.self) { person in
                        HStack(spacing: 6) {
                            Button {
                                selectedPerson = person
                            } label: {
                                HStack(spacing: 6) {
                                    Text(person)
                                    Image(systemName: selectedPerson == person ? "checkmark.circle.fill" : "circle")
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Select \(person)"))

                            Button {
                                removePerson(person)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Remove \(person)"))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassSurface(radius: 14, tint: (selectedPerson == person ? Color.chillSecondaryBlue : Color.black).opacity(0.10), interactive: true)
                    }
                }
            }
        }
        .padding(14)
        .glassSurface(radius: 22, tint: Color.chillSecondaryBlue.opacity(0.08), interactive: true)
    }
}

private struct AdministrationRoutePicker: View {
    @Binding var selectedRoute: AdministrationRoute?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Label("Route context", systemImage: "checklist")
                    .font(.headline)
                    .foregroundStyle(Color.chillText)
                Text("Required")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondaryBlue)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(AdministrationRoute.allCases) { route in
                    let isSelected = selectedRoute == route
                    Button {
                        selectedRoute = route
                    } label: {
                        Label(route.displayName, systemImage: route.symbolName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isSelected ? Color.chillSecondaryBlue : Color.chillText)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ChillPlainButtonStyle())
                    .glassSurface(
                        radius: 18,
                        tint: isSelected ? Color.chillSecondaryBlue.opacity(0.30) : Color.black.opacity(0.04),
                        interactive: true
                    )
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.chillSecondaryBlue, lineWidth: 1.5)
                        }
                    }
                }
            }
        }
    }
}

private struct StaticEffectWindowSummary: View {
    let substance: Substance
    let adjustedDuration: Double
    let profileCaption: String

    private var normalizedPosition: Double {
        let range = substance.effectWindow
        let span = max(0.1, range.upperBound - range.lowerBound)
        return min(1, max(0, (adjustedDuration - range.lowerBound) / span))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Private check-in window: \(adjustedDuration.formatted(.number.precision(.fractionLength(1)))) h")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.chillText)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.chillSecondaryBlue.opacity(0.16))
                    Capsule()
                        .fill(Color.chillSecondaryBlue.opacity(0.82))
                        .frame(width: max(10, proxy.size.width * normalizedPosition))
                }
            }
            .frame(height: 10)

            Text("This is a reminder window for checking wellbeing, water, rest, consent, and support. It does not estimate impairment or recommend timing, amounts, or use.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(profileCaption)
                .font(.caption)
                .foregroundStyle(Color.chillSecondary)
        }
        .padding(12)
        .glassSurface(radius: 18, tint: Color.chillSecondaryBlue.opacity(0.08))
    }
}

private struct DrugTimerCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var timer: DrugDoseTimerRecord
    let now: Date

    private var isActive: Bool {
        timer.endsAt > now
    }

    private var progress: Double {
        let total = max(60, timer.endsAt.timeIntervalSince(timer.startedAt))
        let elapsed = max(0, now.timeIntervalSince(timer.startedAt))
        return min(1, elapsed / total)
    }

    private var redoseDecision: RedoseDecision {
        RedoseDecision(rawValue: timer.redoseDecision) ?? .undecided
    }

    private var shouldShowRedoseNudge: Bool {
        timer.redoseNudgeIsActive(at: now) && redoseDecision == .undecided
    }

    private var remainingText: String {
        let interval = max(0, timer.endsAt.timeIntervalSince(now))
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours) h \(minutes) min left"
        }
        return "\(minutes) min left"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "timer")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isActive ? Color.chillSecondaryBlue : Color.chillSecondary)
                    .frame(width: 42, height: 42)
                    .glassSurface(radius: 21, tint: (isActive ? Color.chillSecondaryBlue : Color.black).opacity(0.10))

                VStack(alignment: .leading, spacing: 5) {
                    Text(timer.substanceName)
                        .font(.headline)
                        .foregroundStyle(Color.chillText)
                    Text(isActive ? remainingText : String(localized: "Check-in ended"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isActive ? Color.chillSecondaryBlue : Color.chillSecondary)
                    Text("Until \(timer.endsAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                    if !timer.doseNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(timer.doseNote)
                            .font(.footnote)
                            .foregroundStyle(Color.chillSecondary)
                            .lineLimit(2)
                    }

                    if redoseDecision != .undecided {
                        Text(redoseDecision.displayTitle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(redoseDecision == .avoided ? Color.chillMint : .orange)
                    }
                }

                Spacer()

                Button(role: .destructive) {
                    Task {
                        await DrugTimerLiveActivityController.end(timer)
                    }
                    RecentlyDeletedStore.record(
                        kind: "Timer",
                        title: "\(timer.substanceName) timer",
                        detail: timer.startedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                    NotificationService.shared.clearSessionCheckIns(id: timer.id)
                    NotificationService.shared.clearRedoseNudge(id: timer.id)
                    modelContext.delete(timer)
                    modelContext.saveChanges()
                    WatchConnectivityService.shared.sendActiveTimers(
                        modelContext.fetchLogging(FetchDescriptor<DrugDoseTimerRecord>())
                    )
                } label: {
                    Image(systemName: "trash.fill")
                }
                .buttonStyle(ChillPlainButtonStyle())
                .foregroundStyle(Color.chillSecondary)
            }

            if isActive {
                ProgressView(value: progress)
                    .tint(progress >= 0.4 ? .orange : Color.chillSecondaryBlue)
            }

            if shouldShowRedoseNudge {
                RedoseNudgeCard(
                    progress: progress,
                    previousDoseText: "\(timer.substanceName) at \(timer.startedAt.formatted(date: .omitted, time: .shortened))",
                    avoid: { saveRedoseDecision(.avoided) },
                    redose: { saveRedoseDecision(.redosed) }
                )
            }
        }
        .padding(16)
        .glassSurface(radius: 24, tint: .black.opacity(0.04))
        .task(id: Int(now.timeIntervalSinceReferenceDate / 60)) {
            guard isActive else {
                return
            }
            await DrugTimerLiveActivityController.update(timer, now: now)
        }
    }

    private func saveRedoseDecision(_ decision: RedoseDecision) {
        timer.redoseDecision = decision.rawValue
        timer.redoseDecisionAt = .now
        modelContext.saveChanges()
        Task {
            await DrugTimerLiveActivityController.update(timer, now: now)
        }
    }
}

private struct RedoseNudgeCard: View {
    let progress: Double
    let previousDoseText: String
    let avoid: () -> Void
    let redose: () -> Void
    @State private var isConfirmingRedose = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Pause before continuing", systemImage: "hand.raised.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text("If you feel pulled to continue, pause first. Check your body, water, food, sleep, consent, and whether someone trusted should know.")
                .font(.caption)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Earlier log: \(previousDoseText)")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.chillText)

            Text("Check-in progress: \(progress.formatted(.percent.precision(.fractionLength(0))))")
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)

            if isConfirmingRedose {
                ProgressView("Pause for 5 seconds")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondary)
            }

            HStack(spacing: 10) {
                Button(action: avoid) {
                    Label("I am stopping now", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChillPillButtonStyle(prominent: true))

                Button(action: delayedRedose) {
                    Text("Log that I continued")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChillPillButtonStyle(prominent: false))
                .disabled(isConfirmingRedose)
            }
        }
        .padding(14)
        .glassSurface(radius: 20, tint: .orange.opacity(0.10), interactive: true)
    }

    private func delayedRedose() {
        guard !isConfirmingRedose else { return }
        isConfirmingRedose = true
        Task {
            try? await Task.sleep(for: .seconds(5))
            await MainActor.run {
                isConfirmingRedose = false
                redose()
            }
        }
    }
}
