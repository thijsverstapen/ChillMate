import Foundation
import SwiftUI

// Support directory views extracted from CareToolsView.swift as part of splitting that file.

struct NetherlandsSupportDirectoryView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("country") private var country = "Netherlands"
    @State private var query = ""

    private var filteredResources: [SupportResource] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SupportResource.resources(for: country)
        }
        return SupportResource.resources(for: country).filter {
            $0.title.localizedCaseInsensitiveContains(trimmed) ||
            $0.detail.localizedCaseInsensitiveContains(trimmed) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PageHeader(
                            title: String(localized: "Support"),
                            subtitle: String(localized: "Search offline support options for crisis help, sexual health, drugs, LGBTQ+ support, and practical care."),
                            symbol: "list.bullet.clipboard.fill",
                            tint: Color.chillSecondaryBlue
                        )

                        TextField("Search support", text: $query)
                            .textFieldStyle(.plain)
                            .foregroundStyle(Color.chillText)
                            .padding(14)
                            .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                        LazyVStack(spacing: 12) {
                            ForEach(filteredResources) { resource in
                                SupportResourceCard(resource: resource)
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
            .endEditingOnTap()
        }
    }
}

struct SupportResource: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let action: String
    let url: URL?
    let tags: [String]

    static let netherlands: [SupportResource] = [
        SupportResource(title: String(localized: "112 emergency"), detail: String(localized: "Immediate danger, unconsciousness, seizure, blue lips, chest pain, severe overheating, or cannot be woken."), action: String(localized: "Call 112"), url: URL(string: "tel://112"), tags: ["crisis", "emergency", "panic"]),
        SupportResource(title: String(localized: "113 Zelfmoordpreventie"), detail: String(localized: "If you might hurt yourself or cannot stay safe. Call 113 or 0800-0113 in the Netherlands."), action: String(localized: "Open 113.nl"), url: URL(string: "https://www.113.nl"), tags: ["crisis", "mental health", "suicide"]),
        SupportResource(title: String(localized: "GGD sexual health"), detail: String(localized: "STI testing, PrEP, PEP questions, vaccination, and sexual health support."), action: String(localized: "Open ggd.nl"), url: URL(string: "https://www.ggd.nl"), tags: ["sti", "pep", "prep", "ggd"]),
        SupportResource(title: String(localized: "Huisarts / GP"), detail: String(localized: "Medication interactions, sleep, mental health, substance use, referrals, and urgent medical questions."), action: String(localized: "Call your GP"), url: nil, tags: ["doctor", "huisarts", "medication"]),
        SupportResource(title: String(localized: "Drugs Infolijn"), detail: String(localized: "Dutch drug information and harm-reduction support from Trimbos."), action: String(localized: "Open drugsinfo.nl"), url: URL(string: "https://www.drugsinfo.nl"), tags: ["drugs", "harm reduction", "trimbos"]),
        SupportResource(title: String(localized: "Centrum Seksueel Geweld"), detail: String(localized: "Support after sexual assault, coercion, or a consent concern."), action: String(localized: "Open centrumseksueelgeweld.nl"), url: URL(string: "https://centrumseksueelgeweld.nl"), tags: ["consent", "assault", "help"]),
        SupportResource(title: String(localized: "Jellinek"), detail: String(localized: "Dutch addiction care and information about alcohol, drugs, and chemsex patterns."), action: String(localized: "Open jellinek.nl"), url: URL(string: "https://www.jellinek.nl"), tags: ["addiction", "chemsex", "drugs"]),
        SupportResource(title: String(localized: "Switchboard LGBT+"), detail: String(localized: "LGBTQ+ listening ear, information, and referral support."), action: String(localized: "Open switchboard.nl"), url: URL(string: "https://switchboard.nl"), tags: ["lgbtq", "queer", "support"])
    ]

    // Generic, country-neutral fallback shown when the chosen country is not the Netherlands.
    static let international: [SupportResource] = [
        SupportResource(title: String(localized: "Emergency services"), detail: String(localized: "Immediate danger, unconsciousness, or someone who cannot be woken. Call your local emergency number now."), action: String(localized: "Call 112"), url: URL(string: "tel://112"), tags: ["crisis", "emergency", "panic"]),
        SupportResource(title: String(localized: "Crisis & suicide support"), detail: String(localized: "Free, confidential support if you might hurt yourself or cannot stay safe."), action: String(localized: "Open findahelpline.com"), url: URL(string: "https://findahelpline.com"), tags: ["crisis", "mental health", "suicide"]),
        SupportResource(title: String(localized: "Sexual health & STI testing"), detail: String(localized: "Find local STI testing, PrEP, PEP, and sexual health services."), action: String(localized: "Find a clinic"), url: nil, tags: ["sti", "pep", "prep"]),
        SupportResource(title: String(localized: "Drug information & harm reduction"), detail: String(localized: "Trusted, non-judgmental drug information and harm-reduction support."), action: String(localized: "Open tripsit.me"), url: URL(string: "https://tripsit.me"), tags: ["drugs", "harm reduction"]),
        SupportResource(title: String(localized: "GP or family doctor"), detail: String(localized: "Medication interactions, sleep, mental health, substance use, referrals, and urgent medical questions."), action: String(localized: "Call your GP"), url: nil, tags: ["doctor", "medication"]),
        SupportResource(title: String(localized: "LGBTQ+ support"), detail: String(localized: "LGBTQ+ listening ear, information, and referral support."), action: String(localized: "Find LGBTQ+ support"), url: nil, tags: ["lgbtq", "queer", "support"])
    ]

    // Shared, country-neutral descriptions reused across countries so only the
    // org name, number, and URL change per country (no extra strings to translate).
    private static var genericEmergencyDetail: String { String(localized: "Immediate danger, unconsciousness, or someone who cannot be woken. Call your local emergency number now.") }
    private static var genericCrisisDetail: String { String(localized: "Free, confidential support if you might hurt yourself or cannot stay safe.") }
    private static var genericSTIDetail: String { String(localized: "Find local STI testing, PrEP, PEP, and sexual health services.") }
    private static var genericDrugsDetail: String { String(localized: "Trusted, non-judgmental drug information and harm-reduction support.") }
    private static var genericGPDetail: String { String(localized: "Medication interactions, sleep, mental health, substance use, referrals, and urgent medical questions.") }
    private static var genericLGBTQDetail: String { String(localized: "LGBTQ+ listening ear, information, and referral support.") }
    private static var genericAssaultDetail: String { String(localized: "Support after sexual assault, coercion, or a consent concern.") }
    private static var gpTitle: String { String(localized: "GP or family doctor") }
    private static var gpAction: String { String(localized: "Call your GP") }

    static let belgium: [SupportResource] = [
        SupportResource(title: "112", detail: genericEmergencyDetail, action: "Call 112", url: URL(string: "tel://112"), tags: ["crisis", "emergency", "panic"]),
        SupportResource(title: "Zelfmoordlijn 1813", detail: genericCrisisDetail, action: "Call 1813", url: URL(string: "tel://1813"), tags: ["crisis", "mental health", "suicide"]),
        SupportResource(title: "Sensoa", detail: genericSTIDetail, action: "Open sensoa.be", url: URL(string: "https://www.sensoa.be"), tags: ["sti", "pep", "prep"]),
        SupportResource(title: gpTitle, detail: genericGPDetail, action: gpAction, url: nil, tags: ["doctor", "medication"]),
        SupportResource(title: "De DrugLijn", detail: genericDrugsDetail, action: "Open druglijn.be", url: URL(string: "https://www.druglijn.be"), tags: ["drugs", "harm reduction"]),
        SupportResource(title: "Zorgcentra na Seksueel Geweld", detail: genericAssaultDetail, action: "Open seksueelgeweld.be", url: URL(string: "https://www.seksueelgeweld.be"), tags: ["consent", "assault", "help"]),
        SupportResource(title: "Lumi", detail: genericLGBTQDetail, action: "Open lumi.be", url: URL(string: "https://lumi.be"), tags: ["lgbtq", "queer", "support"])
    ]

    static let germany: [SupportResource] = [
        SupportResource(title: "112", detail: genericEmergencyDetail, action: "Call 112", url: URL(string: "tel://112"), tags: ["crisis", "emergency", "panic"]),
        SupportResource(title: "TelefonSeelsorge", detail: genericCrisisDetail, action: "Call 0800 111 0 111", url: URL(string: "tel://08001110111"), tags: ["crisis", "mental health", "suicide"]),
        SupportResource(title: "Deutsche Aidshilfe", detail: genericSTIDetail, action: "Open aidshilfe.de", url: URL(string: "https://www.aidshilfe.de"), tags: ["sti", "pep", "prep"]),
        SupportResource(title: gpTitle, detail: genericGPDetail, action: gpAction, url: nil, tags: ["doctor", "medication"]),
        SupportResource(title: "drugcom.de", detail: genericDrugsDetail, action: "Open drugcom.de", url: URL(string: "https://www.drugcom.de"), tags: ["drugs", "harm reduction"]),
        SupportResource(title: "Hilfetelefon", detail: genericAssaultDetail, action: "Call 116 016", url: URL(string: "tel://116016"), tags: ["consent", "assault", "help"]),
        SupportResource(title: "LSVD+", detail: genericLGBTQDetail, action: "Open lsvd.de", url: URL(string: "https://www.lsvd.de"), tags: ["lgbtq", "queer", "support"])
    ]

    static let unitedKingdom: [SupportResource] = [
        SupportResource(title: "999", detail: genericEmergencyDetail, action: "Call 999", url: URL(string: "tel://999"), tags: ["crisis", "emergency", "panic"]),
        SupportResource(title: "Samaritans", detail: genericCrisisDetail, action: "Call 116 123", url: URL(string: "tel://116123"), tags: ["crisis", "mental health", "suicide"]),
        SupportResource(title: "NHS sexual health", detail: genericSTIDetail, action: "Open nhs.uk", url: URL(string: "https://www.nhs.uk/live-well/sexual-health/"), tags: ["sti", "pep", "prep"]),
        SupportResource(title: gpTitle, detail: genericGPDetail, action: gpAction, url: nil, tags: ["doctor", "medication"]),
        SupportResource(title: "FRANK", detail: genericDrugsDetail, action: "Open talktofrank.com", url: URL(string: "https://www.talktofrank.com"), tags: ["drugs", "harm reduction"]),
        SupportResource(title: "Rape Crisis", detail: genericAssaultDetail, action: "Open rapecrisis.org.uk", url: URL(string: "https://rapecrisis.org.uk"), tags: ["consent", "assault", "help"]),
        SupportResource(title: "Switchboard LGBTQ+", detail: genericLGBTQDetail, action: "Open switchboard.lgbt", url: URL(string: "https://switchboard.lgbt"), tags: ["lgbtq", "queer", "support"])
    ]

    static let france: [SupportResource] = [
        SupportResource(title: "112", detail: genericEmergencyDetail, action: "Call 112", url: URL(string: "tel://112"), tags: ["crisis", "emergency", "panic"]),
        SupportResource(title: "3114", detail: genericCrisisDetail, action: "Call 3114", url: URL(string: "tel://3114"), tags: ["crisis", "mental health", "suicide"]),
        SupportResource(title: "Sida Info Service", detail: genericSTIDetail, action: "Open sida-info-service.org", url: URL(string: "https://www.sida-info-service.org"), tags: ["sti", "pep", "prep"]),
        SupportResource(title: gpTitle, detail: genericGPDetail, action: gpAction, url: nil, tags: ["doctor", "medication"]),
        SupportResource(title: "Drogues Info Service", detail: genericDrugsDetail, action: "Open drogues-info-service.fr", url: URL(string: "https://www.drogues-info-service.fr"), tags: ["drugs", "harm reduction"]),
        SupportResource(title: "Viols Femmes Informations", detail: genericAssaultDetail, action: "Call 0800 05 95 95", url: URL(string: "tel://0800059595"), tags: ["consent", "assault", "help"]),
        SupportResource(title: "SOS homophobie", detail: genericLGBTQDetail, action: "Open sos-homophobie.org", url: URL(string: "https://www.sos-homophobie.org"), tags: ["lgbtq", "queer", "support"])
    ]

    static let spain: [SupportResource] = [
        SupportResource(title: "112", detail: genericEmergencyDetail, action: "Call 112", url: URL(string: "tel://112"), tags: ["crisis", "emergency", "panic"]),
        SupportResource(title: "024", detail: genericCrisisDetail, action: "Call 024", url: URL(string: "tel://024"), tags: ["crisis", "mental health", "suicide"]),
        SupportResource(title: "Sanidad (salud sexual)", detail: genericSTIDetail, action: "Open sanidad.gob.es", url: URL(string: "https://www.sanidad.gob.es"), tags: ["sti", "pep", "prep"]),
        SupportResource(title: gpTitle, detail: genericGPDetail, action: gpAction, url: nil, tags: ["doctor", "medication"]),
        SupportResource(title: "Energy Control", detail: genericDrugsDetail, action: "Open energycontrol.org", url: URL(string: "https://energycontrol.org"), tags: ["drugs", "harm reduction"]),
        SupportResource(title: "016 (violencia sexual)", detail: genericAssaultDetail, action: "Call 016", url: URL(string: "tel://016"), tags: ["consent", "assault", "help"]),
        SupportResource(title: "FELGTBI+", detail: genericLGBTQDetail, action: "Open felgtbi.org", url: URL(string: "https://felgtbi.org"), tags: ["lgbtq", "queer", "support"])
    ]

    static let unitedStates: [SupportResource] = [
        SupportResource(title: "911", detail: genericEmergencyDetail, action: "Call 911", url: URL(string: "tel://911"), tags: ["crisis", "emergency", "panic"]),
        SupportResource(title: "988 Suicide & Crisis Lifeline", detail: genericCrisisDetail, action: "Call 988", url: URL(string: "tel://988"), tags: ["crisis", "mental health", "suicide"]),
        SupportResource(title: "CDC GetTested", detail: genericSTIDetail, action: "Open gettested.cdc.gov", url: URL(string: "https://gettested.cdc.gov"), tags: ["sti", "pep", "prep"]),
        SupportResource(title: gpTitle, detail: genericGPDetail, action: gpAction, url: nil, tags: ["doctor", "medication"]),
        SupportResource(title: "DanceSafe", detail: genericDrugsDetail, action: "Open dancesafe.org", url: URL(string: "https://dancesafe.org"), tags: ["drugs", "harm reduction"]),
        SupportResource(title: "RAINN", detail: genericAssaultDetail, action: "Open rainn.org", url: URL(string: "https://www.rainn.org"), tags: ["consent", "assault", "help"]),
        SupportResource(title: "The Trevor Project", detail: genericLGBTQDetail, action: "Open thetrevorproject.org", url: URL(string: "https://www.thetrevorproject.org"), tags: ["lgbtq", "queer", "support"])
    ]

    static let ireland: [SupportResource] = [
        SupportResource(title: "112", detail: genericEmergencyDetail, action: "Call 112", url: URL(string: "tel://112"), tags: ["crisis", "emergency", "panic"]),
        SupportResource(title: "Samaritans", detail: genericCrisisDetail, action: "Call 116 123", url: URL(string: "tel://116123"), tags: ["crisis", "mental health", "suicide"]),
        SupportResource(title: "Sexual Wellbeing (HSE)", detail: genericSTIDetail, action: "Open sexualwellbeing.ie", url: URL(string: "https://www.sexualwellbeing.ie"), tags: ["sti", "pep", "prep"]),
        SupportResource(title: gpTitle, detail: genericGPDetail, action: gpAction, url: nil, tags: ["doctor", "medication"]),
        SupportResource(title: "Drugs.ie", detail: genericDrugsDetail, action: "Open drugs.ie", url: URL(string: "https://www.drugs.ie"), tags: ["drugs", "harm reduction"]),
        SupportResource(title: "Dublin Rape Crisis Centre", detail: genericAssaultDetail, action: "Open drcc.ie", url: URL(string: "https://www.drcc.ie"), tags: ["consent", "assault", "help"]),
        SupportResource(title: "LGBT Ireland", detail: genericLGBTQDetail, action: "Open lgbt.ie", url: URL(string: "https://lgbt.ie"), tags: ["lgbtq", "queer", "support"])
    ]

    static let australia: [SupportResource] = [
        SupportResource(title: "000", detail: genericEmergencyDetail, action: "Call 000", url: URL(string: "tel://000"), tags: ["crisis", "emergency", "panic"]),
        SupportResource(title: "Lifeline", detail: genericCrisisDetail, action: "Call 13 11 14", url: URL(string: "tel://131114"), tags: ["crisis", "mental health", "suicide"]),
        SupportResource(title: "Healthdirect sexual health", detail: genericSTIDetail, action: "Open healthdirect.gov.au", url: URL(string: "https://www.healthdirect.gov.au/sexual-health"), tags: ["sti", "pep", "prep"]),
        SupportResource(title: gpTitle, detail: genericGPDetail, action: gpAction, url: nil, tags: ["doctor", "medication"]),
        SupportResource(title: "Alcohol and Drug Foundation", detail: genericDrugsDetail, action: "Open adf.org.au", url: URL(string: "https://adf.org.au"), tags: ["drugs", "harm reduction"]),
        SupportResource(title: "1800RESPECT", detail: genericAssaultDetail, action: "Call 1800 737 732", url: URL(string: "tel://1800737732"), tags: ["consent", "assault", "help"]),
        SupportResource(title: "QLife", detail: genericLGBTQDetail, action: "Open qlife.org.au", url: URL(string: "https://qlife.org.au"), tags: ["lgbtq", "queer", "support"])
    ]

    static func resources(for country: String) -> [SupportResource] {
        switch country {
        case "Belgium": return belgium
        case "Germany": return germany
        case "United Kingdom": return unitedKingdom
        case "France": return france
        case "Spain": return spain
        case "United States": return unitedStates
        case "Ireland": return ireland
        case "Australia": return australia
        // Netherlands and "Other" both use the Dutch resources.
        case "Netherlands", "Other": return netherlands
        default: return international
        }
    }

    /// Primary emergency number for the country (112 across the EU, 999 UK, 911 US, 000 AU).
    /// Delegates to `EmergencyContactInfo` so there is exactly one such table in the app.
    static func emergencyNumber(for country: String) -> String {
        EmergencyContactInfo.number(forCountry: country)
    }

    /// Fallback label for the non-urgent sexual-health contact when the user has
    /// not set their own.
    static func healthcareLabel(for country: String) -> String {
        (country == "Netherlands" || country == "Other") ? "GP, huisarts, or GGD" : "GP or sexual-health clinic"
    }
}

private struct SupportResourceCard: View {
    let resource: SupportResource

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(resource.title)
                .font(.headline)
                .foregroundStyle(Color.chillText)
            Text(resource.detail)
                .font(.caption)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let url = resource.url {
                Link(destination: url) {
                    Label(resource.action, systemImage: resource.url?.scheme == "tel" ? "phone.fill" : "arrow.up.right.square.fill")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(ChillPillButtonStyle(prominent: false, tint: .chillSecondaryBlue))
            } else {
                Text(resource.action)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.chillSecondaryBlue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassSurface(radius: 24, tint: Color.chillSecondaryBlue.opacity(0.08), interactive: true)
    }
}
