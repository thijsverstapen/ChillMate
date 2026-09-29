import PhotosUI
import SwiftUI
import UIKit
import ChillMateCore

/// The form rows the profile wizard and the intro are both built from.
///
/// Split out of `ProfileSetupView.swift` unchanged. They were already internal
/// rather than private, which is what made them the obvious seam.

struct ProfileSetupSectionHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(Color.chillSecondary)

            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Color.chillText)

            Text(subtitle)
                .font(.footnote)
                .lineSpacing(2)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A hairline separator between flat rows inside a setup card, inset to line up
/// under the row text (past the leading icon) the way iOS grouped lists do.
struct ProfileSetupRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 1)
            .padding(.leading, 50)
    }
}

struct ProfileSetupTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let systemImage: String
    var axis: Axis = .horizontal

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillMint)

                TextField(placeholder, text: $text, axis: axis)
                    .textFieldStyle(.plain)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.chillText)
                    .tint(Color.chillPrimary)
                    .lineLimit(axis == .vertical ? 1...4 : 1...1)
            }
        }
        .padding(.vertical, 8)
    }
}

struct ProfileSetupMeasurementRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            Stepper(value: $value, in: range, step: 1) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.chillMint)

                    Text("\(Int(value.rounded())) \(unit)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.chillText)
                }
            }
            .tint(.chillPrimary)
        }
        .padding(.vertical, 8)
    }
}

struct ProfileSetupPickerRow<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillMint)

                content
                    .pickerStyle(.menu)
                    .tint(Color.chillText)
                    .font(.body.weight(.semibold))
                    .fixedSize()
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}

struct ProfileSetupToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.chillText)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(.chillPrimary)
        }
        .padding(.vertical, 8)
    }
}

struct ProfileSetupDateRow: View {
    let title: String
    @Binding var date: Date
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            ProfileSetupIcon(systemImage: systemImage)

            DatePicker(title, selection: $date, displayedComponents: [.date])
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.chillText)
                .tint(.chillPrimary)
        }
        .padding(.vertical, 8)
    }
}

struct ProfileSetupIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color.chillMint)
            .frame(width: 38, height: 38)
            .background(Color.chillMint.opacity(0.16), in: Circle())
            .overlay {
                Circle()
                    .stroke(Color.chillMint.opacity(0.34), lineWidth: 1)
            }
    }
}

/// The shortest honest way into the app.
///
/// Two things cannot be skipped and both are here: being eighteen, and reading
/// what ChillMate does not claim to do. Everything the wizard asks for after
/// that — name, height, weight, medication, permissions, emergency contact — is
/// useful and none of it is a condition of entry, so it waits on the profile
/// screen until somebody has a calmer minute.
///
/// It creates a real profile with whatever has been filled in so far, which is
/// often nothing. An empty name is already handled everywhere it is read.
struct QuickStartSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var hasAgreed: Bool
    let isUnderage: Bool
    let age: Int
    let start: () -> Void

    private var canStart: Bool {
        hasAgreed && !isUnderage && age >= 18
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Go straight in"),
                            subtitle: String(localized: "You can set up your profile whenever you want. Two things first, and then you are in."),
                            symbol: "bolt.horizontal.circle.fill",
                            tint: Color.chillPrimary
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            CareSectionTitle(title: String(localized: "What ChillMate is not"), symbol: "info.circle.fill")

                            Text("ChillMate supports reflection, recovery, STI care, privacy, and emergency planning. It does not replace a clinician, diagnose conditions, decide whether something is safe, or recommend amounts, timing, or substance use. Its information is drawn from verified, official public-health sources and is updated over time as those sources change. ChillMate and its maker are not liable in any way for decisions made using the app. If someone may be in immediate danger, call local emergency services.")
                                .font(.footnote)
                                .foregroundStyle(Color.chillSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Toggle(isOn: $hasAgreed.animation(.snappy)) {
                                Text("I have read and agree to this.")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.chillText)
                            }
                            .tint(.chillMint)
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.08), interactive: true)

                        if isUnderage || age < 18 {
                            Text("ChillMate is for adults. Confirm your age on the first step to continue.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        GlassActionButton(prominent: true, action: start) {
                            Label("Take me in", systemImage: "arrow.right.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(!canStart)
                        .opacity(canStart ? 1 : 0.55)
                        .accessibilityIdentifier(AccessibilityID.setupQuickStartButton)

                        Text("Your profile stays on this device unless you turn on iCloud sync. Filling it in later makes the timers and the combination checker more useful to you, and nothing in the app is locked behind it.")
                            .font(.caption)
                            .foregroundStyle(Color.chillSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back to setup") { dismiss() }
                }
            }
        }
    }
}

struct ProfileSetupPhotoPicker: View {
    let imageData: Data?
    @Binding var selectedPhoto: PhotosPickerItem?
    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color.chillPrimary.opacity(0.62))
                            .padding(26)
                    }
                }
                .frame(width: 116, height: 116)
                .clipShape(Circle())
                .glassSurface(radius: 58, tint: Color.chillPrimary.opacity(0.18))

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.chillText)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay {
                            Circle().stroke(.white.opacity(0.35), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.16), radius: 10, y: 5)
                }
                .accessibilityLabel("Add profile picture")
            }

            Text(image == nil ? String(localized: "Add a photo (optional)") : String(localized: "Tap to change photo"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if image == nil, let imageData {
                image = UIImage(data: imageData)
            }
        }
        .onChange(of: imageData) { _, newValue in
            image = newValue.flatMap(UIImage.init(data:))
        }
    }
}

struct ProfileSetupBackupImportCard: View {
    let isImporting: Bool
    let isSyncOn: Bool
    let message: String?
    let importAction: () -> Void
    let turnOnSyncAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ProfileSetupIcon(systemImage: "externaldrive.badge.plus")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Used ChillMate before?")
                        .font(.headline)
                        .foregroundStyle(Color.chillText)
                    // Says what each button can and cannot do. The file option is
                    // an export, sealed with a key that stays on the phone that
                    // made it, so it is no help on a new one; iCloud sync is.
                    Text("Turn on iCloud sync to bring back history you synced, or import a backup file made on this iPhone.")
                        .font(.caption)
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button(action: turnOnSyncAction) {
                    Label(isSyncOn ? "iCloud sync is on" : "iCloud sync", systemImage: "arrow.triangle.2.circlepath.icloud")
                        .font(.headline)
                        .chillLineLimit(1, scale: 0.8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChillPillButtonStyle(prominent: true))
                .disabled(isSyncOn || isImporting)

                Button(action: importAction) {
                    HStack {
                        if isImporting {
                            ProgressView()
                        }
                        Label("File", systemImage: "square.and.arrow.down.fill")
                            .font(.headline)
                            .chillLineLimit(1, scale: 0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChillPillButtonStyle(prominent: false, tint: .chillSecondaryBlue))
                .disabled(isImporting)
            }

            if let message {
                Text(message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.08), interactive: true)
    }
}

struct ProfileSetupMedicationSection: View {
    @Binding var isEnabled: Bool
    @Binding var medications: [ProfileMedication]
    @Binding var name: String
    @Binding var dosage: String
    @Binding var takenAt: Date
    @Binding var effectiveHours: Double

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ProfileSetupSectionHeader(
                eyebrow: String(localized: "Medication"),
                title: String(localized: "Current medication"),
                subtitle: String(localized: "Turn this on only if you want ChillMate to remember medication for check-ins and risk checks.")
            )

            medicationCard
        }
    }

    private func addMedication() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        medications.append(
            ProfileMedication(
                name: trimmedName,
                dosage: dosage.trimmingCharacters(in: .whitespacesAndNewlines),
                takenAt: takenAt,
                effectiveHours: effectiveHours
            )
        )
        name = ""
        dosage = ""
        takenAt = .now
        effectiveHours = 8
    }

    /// Toggle and medication rows, split out of a 107-line body.
    @ViewBuilder
    private var medicationCard: some View {
        VStack(spacing: 0) {
            ProfileSetupToggleRow(
                title: String(localized: "I use current medication"),
                subtitle: isEnabled ? String(localized: "Medication fields are shown") : String(localized: "No medication fields needed"),
                isOn: $isEnabled,
                systemImage: "pills.fill"
            )

            if isEnabled {
                ProfileSetupRowDivider()

                ProfileSetupTextField(
                    title: String(localized: "Medication name"),
                    placeholder: String(localized: "For example sertraline"),
                    text: $name,
                    systemImage: "pills.fill"
                )

                ProfileSetupRowDivider()

                ProfileSetupTextField(
                    title: String(localized: "Prescription amount"),
                    placeholder: String(localized: "As written on your label"),
                    text: $dosage,
                    systemImage: "number"
                )

                ProfileSetupRowDivider()

                ProfileSetupDateRow(
                    title: String(localized: "Last taken"),
                    date: $takenAt,
                    systemImage: "clock.fill"
                )

                ProfileSetupRowDivider()

                ProfileSetupMeasurementRow(
                    title: String(localized: "Medication duration"),
                    value: $effectiveHours,
                    range: 0.5...72,
                    unit: "h",
                    systemImage: "timer"
                )

                GlassActionButton(prominent: false, action: addMedication) {
                    Label("Add medication", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .disabled(!canAdd)
                .opacity(canAdd ? 1 : 0.55)
                .padding(.top, 14)

                if medications.isEmpty {
                    Text("No medication saved yet.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                } else {
                    VStack(spacing: 8) {
                        ForEach(medications) { medication in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "pills.circle.fill")
                                    .foregroundStyle(Color.chillPrimary)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(medication.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.chillText)
                                    Text(medication.timingSummary)
                                        .font(.caption)
                                        .foregroundStyle(Color.chillSecondary)
                                }

                                Spacer()

                                Button {
                                    medications.removeAll { $0.id == medication.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(ChillPlainButtonStyle())
                                .foregroundStyle(Color.chillSecondary)
                            }
                            .padding(10)
                            .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .glassSurface(radius: 28, tint: .black.opacity(0.04), interactive: true)
    }
}
