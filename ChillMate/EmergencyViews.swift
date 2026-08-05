import Foundation
import SwiftData
import SwiftUI

struct EmergencyNetherlandsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @AppStorage(DefaultsKey.trustedContactName) private var trustedContactName = ""
    @AppStorage(DefaultsKey.trustedContactPhone) private var trustedContactPhone = ""
    @AppStorage(DefaultsKey.trustedContactMessage) private var trustedContactMessage = "Please come get me, I’m not okay at this moment."
    @AppStorage(DefaultsKey.localEmergencyNumber) private var localEmergencyNumber = ""
    @AppStorage(DefaultsKey.localHealthcareContact) private var localHealthcareContact = ""
    @AppStorage(DefaultsKey.country) private var country = "Netherlands"

    @State private var isFetchingLocation = false
    @State private var locationMessage: String?
    @State private var isEditingEmergencyInfo = false

    private var emergencyNumber: String {
        let trimmed = localEmergencyNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? SupportResource.emergencyNumber(for: country) : trimmed
    }

    private var healthcareContactLabel: String {
        let trimmed = localHealthcareContact.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? SupportResource.healthcareLabel(for: country) : trimmed
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Emergency Information"),
                            subtitle: String(localized: "Fast emergency support. Set your local emergency number and healthcare contact in the edit menu."),
                            symbol: "sos.circle.fill",
                            tint: .red
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Call \(emergencyNumber) for immediate danger, urgent medical help, fire, or a crime in progress. Say where you are and what happened.")
                                .font(.callout)
                                .foregroundStyle(Color.chillText)
                                .fixedSize(horizontal: false, vertical: true)

                            Button(role: .destructive) {
                                call(emergencyNumber)
                            } label: {
                                Label("Call \(emergencyNumber)", systemImage: "phone.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChillPillButtonStyle(prominent: true, tint: .red))

                            Button {
                                isEditingEmergencyInfo = true
                            } label: {
                                Label("Change emergency number", systemImage: "pencil")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChillPillButtonStyle(prominent: false, tint: .red))
                        }
                        .padding(16)
                        .glassSurface(radius: 28, tint: .red.opacity(0.10), interactive: true)
                        .sheet(isPresented: $isEditingEmergencyInfo) {
                            EmergencyContactEditSheet(
                                emergencyNumber: $localEmergencyNumber,
                                healthcareContact: $localHealthcareContact
                            )
                            .presentationDetents([.medium])
                        }

                        EmergencyRedFlagCard()

                        emergencyNetherlandsViewContinued
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .endEditingOnTap()
        }
    }

    /// Second half of `EmergencyNetherlandsView`'s body, which ran to 132 lines.
    ///
    /// Split purely for readability: these are the same views in the same
    /// order, still direct children of the same container.
    @ViewBuilder
    private var emergencyNetherlandsViewContinued: some View {
            VStack(alignment: .leading, spacing: 14) {
                CareSectionTitle(title: String(localized: "Trusted contact"), symbol: "person.crop.circle.badge.checkmark")

                TextField("Name", text: $trustedContactName)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.chillText)
                    .padding(14)
                    .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                TextField("Phone number", text: $trustedContactPhone)
                    .keyboardType(.phonePad)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.chillText)
                    .padding(14)
                    .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                Button {
                    call(trustedContactPhone)
                } label: {
                    Label(trustedContactName.isEmpty ? "Call trusted contact" : "Call \(trustedContactName)", systemImage: "phone.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChillPillButtonStyle(prominent: true))
                .disabled(cleanedPhone(trustedContactPhone).isEmpty)

                TextField("Message", text: $trustedContactMessage, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.chillText)
                    .padding(14)
                    .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                Button {
                    sendLocationMessage()
                } label: {
                    HStack {
                        if isFetchingLocation {
                            ProgressView()
                        }
                        Label("Send current location", systemImage: "message.fill")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChillPillButtonStyle(prominent: true))
                .disabled(cleanedPhone(trustedContactPhone).isEmpty || isFetchingLocation)

                if let locationMessage {
                    Text(locationMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .glassSurface(radius: 28, tint: Color.chillMint.opacity(0.10), interactive: true)

            VStack(alignment: .leading, spacing: 10) {
                CareSectionTitle(title: String(localized: "Non-urgent sexual health"), symbol: "cross.case.fill")
                Text("For STI testing, sexual health questions, or treatment that is not an emergency, contact \(healthcareContactLabel).")
                    .font(.callout)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .glassSurface(radius: 28, tint: .black.opacity(0.04))

            CountrySupportLinksCard(country: country)
    }

    private func call(_ number: String) {
        guard let url = URL(string: "tel://\(cleanedPhone(number))") else {
            return
        }
        openURL(url)
    }

    private func cleanedPhone(_ number: String) -> String {
        number.filter { $0.isNumber || $0 == "+" }
    }

    private func sendLocationMessage() {
        guard !isFetchingLocation else {
            return
        }

        isFetchingLocation = true
        locationMessage = nil

        Task {
            do {
                let location = try await LocationLookupService.shared.currentLoggedLocation()
                await MainActor.run {
                    openMessageComposer(location: location)
                    locationMessage = "Prepared iMessage with your current location."
                    isFetchingLocation = false
                }
            } catch {
                await MainActor.run {
                    locationMessage = error.localizedDescription
                    isFetchingLocation = false
                }
            }
        }
    }

    private func openMessageComposer(location: LoggedLocation) {
        var components = URLComponents()
        components.scheme = "sms"
        components.path = cleanedPhone(trustedContactPhone)
        components.queryItems = [
            URLQueryItem(name: String(localized: "body"), value: emergencyMessage(location: location))
        ]

        guard let url = components.url else {
            return
        }

        openURL(url)
    }

    private func emergencyMessage(location: LoggedLocation) -> String {
        let trimmed = trustedContactMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseMessage = trimmed.isEmpty ? "Please come get me, I’m not okay at this moment." : trimmed
        return "\(baseMessage)\nMy location: https://maps.apple.com/?ll=\(location.latitude),\(location.longitude)"
    }
}

private struct CountrySupportLinksCard: View {
    let country: String

    private var links: [SupportResource] {
        SupportResource.resources(for: country).filter {
            $0.url != nil && $0.url?.scheme != "tel"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CareSectionTitle(title: String(localized: "Support links"), symbol: "mappin.and.ellipse")

            Text("Use these for non-urgent sexual health, substance information, and harm-reduction support. For immediate danger, call your local emergency number.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(links) { link in
                if let url = link.url {
                    Link(destination: url) {
                        HStack(spacing: 10) {
                            Image(systemName: "link.circle.fill")
                                .foregroundStyle(Color.chillSecondaryBlue)
                            Text(link.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.chillText)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.chillSecondary)
                        }
                        .padding(12)
                        .glassSurface(radius: 18, tint: Color.chillSecondaryBlue.opacity(0.06), interactive: true)
                    }
                }
            }
        }
        .padding(16)
        .glassSurface(radius: 28, tint: Color.chillSecondaryBlue.opacity(0.08))
    }
}

private struct EmergencyContactEditSheet: View {
    @Binding var emergencyNumber: String
    @Binding var healthcareContact: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.opacity(0.86).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Emergency contacts")
                        .font(.title2.bold())
                        .foregroundStyle(Color.chillText)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Emergency number", systemImage: "phone.fill")
                            .font(.headline)
                            .foregroundStyle(Color.chillText)
                        Text("Leave blank to use your country default (112 across the EU, 999 in the UK), or enter your local emergency number.")
                            .font(.caption)
                            .foregroundStyle(Color.chillSecondary)
                        TextField("e.g. 911 or 999", text: $emergencyNumber)
                            .keyboardType(.phonePad)
                            .textFieldStyle(.plain)
                            .foregroundStyle(Color.chillText)
                            .padding(14)
                            .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Healthcare contact", systemImage: "cross.case.fill")
                            .font(.headline)
                            .foregroundStyle(Color.chillText)
                        Text("Shown in the non-urgent sexual health section. Examples: local STI clinic, GP, PrEP provider.")
                            .font(.caption)
                            .foregroundStyle(Color.chillSecondary)
                        TextField("e.g. local STI clinic or GP", text: $healthcareContact)
                            .textFieldStyle(.plain)
                            .foregroundStyle(Color.chillText)
                            .padding(14)
                            .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)
                    }

                    Button("Done") { dismiss() }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(ChillPillButtonStyle(prominent: true))
                }
                .padding(20)
            }
        }
    }
}

struct EmergencyCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(ChillMateQueries.profile) private var profiles: [UserProfile]
    @Query(ChillMateQueries.recentTimers) private var timers: [DrugDoseTimerRecord]
    @Query(ChillMateQueries.recentEntries) private var entries: [NightEntry]
    @AppStorage(DefaultsKey.trustedContactName) private var trustedContactName = ""
    @AppStorage(DefaultsKey.trustedContactPhone) private var trustedContactPhone = ""
    @AppStorage(DefaultsKey.emergencyAllergies) private var emergencyAllergies = ""
    @AppStorage(DefaultsKey.emergencyInstructions) private var emergencyInstructions = "If I seem confused, overheated, unconscious, or cannot be woken, call 112."

    private var profile: UserProfile? { profiles.first }

    private var activeSubstances: [String] {
        let now = Date.now
        let timerNames = timers
            .filter { $0.endsAt > now }
            .map {
                let route = AdministrationRoute(rawValue: $0.administrationRoute)?.displayName ?? "Saved route"
                return "\($0.substanceName) (\(route))"
            }
        if !timerNames.isEmpty {
            return Array(timerNames.prefix(5))
        }
        return Array((entries.first?.substances ?? []).prefix(5))
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PageHeader(
                            title: String(localized: "Emergency card"),
                            subtitle: String(localized: "A simple card for urgent moments. Keep it readable and only include what you are comfortable showing."),
                            symbol: "staroflife.fill",
                            tint: .red
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            EmergencyCardLine(title: String(localized: "Name"), value: profile?.name ?? "Not set", symbol: "person.fill")
                            EmergencyCardLine(title: String(localized: "Medication"), value: medicationText, symbol: "pills.fill")
                            EmergencyCardLine(title: String(localized: "Current substances"), value: activeSubstances.isEmpty ? "None currently tracked" : activeSubstances.joined(separator: ", "), symbol: "timer")
                            EmergencyCardLine(title: String(localized: "Trusted contact"), value: trustedContactText, symbol: "phone.fill")

                            VStack(alignment: .leading, spacing: 8) {
                                Label("Allergies", systemImage: "allergens.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.chillSecondary)
                                TextField("Known allergies", text: $emergencyAllergies, axis: .vertical)
                                    .lineLimit(2...4)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(Color.chillText)
                                    .padding(12)
                                    .glassSurface(radius: 16, tint: .black.opacity(0.04), interactive: true)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Label("Emergency instructions", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.chillSecondary)
                                TextField("Emergency instructions", text: $emergencyInstructions, axis: .vertical)
                                    .lineLimit(3...6)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(Color.chillText)
                                    .padding(12)
                                    .glassSurface(radius: 16, tint: .black.opacity(0.04), interactive: true)
                            }
                        }
                        .padding(18)
                        .glassSurface(radius: 30, tint: .black.opacity(0.04), interactive: true)

                        HStack(spacing: 10) {
                            Link(destination: EmergencyContactInfo.dialURL ?? EmergencyContactInfo.fallbackDialURL) {
                                Label("Call \(EmergencyContactInfo.number)", systemImage: "phone.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChillPillButtonStyle(prominent: true, tint: .red))

                            if let url = trustedContactCallURL {
                                Link(destination: url) {
                                    Label("Trusted contact", systemImage: "person.crop.circle.badge.checkmark")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(ChillPillButtonStyle(prominent: false, tint: .chillSecondaryBlue))
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(Text(verbatim: ""))
            .endEditingOnTap()
        }
    }

    private var medicationText: String {
        guard let profile, !profile.medications.isEmpty else {
            return String(localized: "No medication saved")
        }
        return profile.medications.prefix(4).map { "\($0.name) \($0.dosage)" }.joined(separator: ", ")
    }

    private var trustedContactText: String {
        let name = trustedContactName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = trustedContactPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty && phone.isEmpty { return String(localized: "Not set") }
        if phone.isEmpty { return name }
        return name.isEmpty ? phone : "\(name), \(phone)"
    }

    private var trustedContactCallURL: URL? {
        let phone = trustedContactPhone.filter { $0.isNumber || $0 == "+" }
        guard !phone.isEmpty else { return nil }
        return URL(string: "tel://\(phone)")
    }
}

private struct EmergencyCardLine: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.chillText)
                .frame(width: 34, height: 34)
                .glassSurface(radius: 17, tint: .black.opacity(0.08))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondary)
                Text(value)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.chillText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
