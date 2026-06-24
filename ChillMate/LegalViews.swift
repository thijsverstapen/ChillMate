import Foundation
import SwiftUI

// Legal/policy text views extracted from CareToolsView.swift.

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        PageHeader(
                            title: String(localized: "Privacy Policy"),
                            subtitle: String(localized: "Plain-language privacy summary."),
                            symbol: "hand.raised.square.fill",
                            tint: Color.chillIconTeal
                        )

                        LegalInfoCard(
                            title: String(localized: "What ChillMate can save"),
                            symbol: "tray.full.fill",
                            rows: [
                                String(localized: "Your profile, photo, medication notes, trusted contact, home address, settings, and preferences."),
                                String(localized: "Private logs, sleep notes, STI test records, plans, journal entries, risk checks, check-ins, and emergency-card details."),
                                String(localized: "Optional information you choose to add from Apple Health, Contacts, Photos, or Location Services.")
                            ]
                        )

                        LegalInfoCard(
                            title: String(localized: "How it is used"),
                            symbol: "lock.shield.fill",
                            rows: [
                                String(localized: "To show your private overview, reminders, aftercare prompts, STI follow-ups, emergency shortcuts, and wellbeing reflections."),
                                String(localized: "To sync with Apple Health only for categories you approve in iOS settings."),
                                String(localized: "To create encrypted backups only when backup features are enabled.")
                            ]
                        )

                        LegalInfoCard(
                            title: String(localized: "What ChillMate does not do"),
                            symbol: "eye.slash.fill",
                            rows: [
                                String(localized: "No ads, no selling personal information, and no sharing health or sexual-health details for marketing."),
                                String(localized: "No medical diagnosis, treatment decisions, dosage advice, or confirmation that a substance, amount, or combination is safe."),
                                String(localized: "Messages to contacts are created only when you choose to send them.")
                            ]
                        )

                        LegalInfoCard(
                            title: String(localized: "Control and deletion"),
                            symbol: "trash.fill",
                            rows: [
                                String(localized: "You can delete logs, plans, STI tests, timers, risk checks, journal entries, and account data inside the app."),
                                String(localized: "iOS permission controls remain available in Settings for Health, Location, Notifications, Contacts, and Photos."),
                                String(localized: "If you need urgent help, do not wait for the app. Call local emergency services.")
                            ]
                        )
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
        }
    }
}

struct TermsOfUseView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        PageHeader(
                            title: String(localized: "Terms"),
                            subtitle: String(localized: "Use ChillMate as a private wellbeing and reflection tool."),
                            symbol: "doc.text.fill",
                            tint: Color.chillIconPurple
                        )

                        MedicalSafetyDisclaimerCard()

                        LegalInfoCard(
                            title: String(localized: "Age and app use"),
                            symbol: "18.circle.fill",
                            rows: [
                                String(localized: "ChillMate is intended for adults only."),
                                String(localized: "ChillMate is for adults only. You are responsible for the information you save and who you share it with."),
                                String(localized: "You are responsible for deciding what information you save and who you share it with.")
                            ]
                        )

                        LegalInfoCard(
                            title: String(localized: "Safety boundaries"),
                            symbol: "exclamationmark.triangle.fill",
                            rows: [
                                String(localized: "ChillMate does not encourage substance use, sex, or mixing substances."),
                                String(localized: "ChillMate does not provide dosing, medical, legal, or emergency-services advice."),
                                String(localized: "Emergency guidance is intentionally simple: if there is immediate danger, call local emergency services.")
                            ]
                        )

                        LegalInfoCard(
                            title: String(localized: "Professional support"),
                            symbol: "person.text.rectangle.fill",
                            rows: [
                                String(localized: "Use Support for Dutch sexual-health, crisis, addiction-care, and practical support resources."),
                                String(localized: "For STI, PrEP, PEP, medication, mental-health, or substance concerns, contact a GP, GGD, pharmacist, clinician, counselor, or other qualified professional."),
                                String(localized: "The app can help organize notes for a conversation, but it cannot replace that conversation.")
                            ]
                        )

                        LegalInfoCard(
                            title: String(localized: "Information & sources"),
                            symbol: "checkmark.seal.fill",
                            rows: [
                                String(localized: "All wellbeing and harm-reduction information in ChillMate is compiled from verified, official public-health sources."),
                                String(localized: "It is reviewed and updated from time to time as those sources change or new information becomes available."),
                                String(localized: "ChillMate and its maker are not liable in any way for any decision, action, or outcome based on the app. Always confirm anything important with a qualified professional or official service.")
                            ]
                        )
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
        }
    }
}

private struct LegalInfoCard: View {
    let title: String
    let symbol: String
    let rows: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(Color.chillText)

            ForEach(rows, id: \.self) { row in
                Label(row, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glassSurface(radius: 26, tint: .black.opacity(0.04), interactive: true)
    }
}
