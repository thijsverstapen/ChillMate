import Foundation
import SwiftData
import SwiftUI
import UIKit

struct ProfessionalHelperBridgeView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(ChillMateQueries.profile) private var profiles: [UserProfile]
    @Query(ChillMateQueries.recentEntries) private var entries: [NightEntry]
    @Query(ChillMateQueries.recentTimers) private var timers: [DrugDoseTimerRecord]
    @Query(ChillMateQueries.recentTests) private var stiTests: [STDTestRecord]
    @Query(ChillMateQueries.recentRiskChecks) private var riskChecks: [RiskCheckRecord]

    @State private var pdfURL: URL?

    private var summary: String {
        HelperSummaryBuilder.summary(
            profile: profiles.first,
            entries: entries,
            timers: timers,
            stiTests: stiTests,
            riskChecks: riskChecks
        )
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Helper summary"),
                            subtitle: String(localized: "Prepare private talking points for a GP, sexual-health service, therapist, addiction-care worker, or trusted professional. You decide whether to share it."),
                            symbol: "doc.text.magnifyingglass",
                            tint: Color.chillMint
                        )

                        ClinicalReviewNoticeCard()

                        Text(summary)
                            .font(.callout.monospaced())
                            .foregroundStyle(Color.chillText)
                            .textSelection(.enabled)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassSurface(radius: 26, tint: .black.opacity(0.04))

                        ShareLink(item: summary) {
                            Label("Share private summary", systemImage: "square.and.arrow.up.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ChillPillButtonStyle(prominent: true))

                        if let pdfURL {
                            ShareLink(item: pdfURL) {
                                Label("Export as PDF", systemImage: "doc.richtext.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChillPillButtonStyle(prominent: false))
                        }

                        EvidenceSourcesSection(title: String(localized: "Helpful professional routes"), sources: EvidenceLibrary.netherlandsSupport)
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(Text(verbatim: ""))
            .task(id: summary) {
                pdfURL = HealthSummaryPDF.render(
                    title: String(localized: "ChillMate private summary"),
                    summary: summary
                )
            }
        }
    }
}

enum HealthSummaryPDF {
    /// Paginate arbitrary-length summary text into a shareable PDF (A4).
    /// `UIPrintPageRenderer` + `UISimpleTextPrintFormatter` handles pagination.
    @MainActor
    static func render(title: String, summary: String) -> URL? {
        let body = title + "\n\n" + summary
        let formatter = UISimpleTextPrintFormatter(text: body)
        formatter.font = UIFont.systemFont(ofSize: 12)
        formatter.color = .black

        let pageRenderer = UIPrintPageRenderer()
        pageRenderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        let pageSize = CGSize(width: 595.2, height: 841.8) // A4 @ 72dpi
        let margin: CGFloat = 40
        let paperRect = CGRect(origin: .zero, size: pageSize)
        let printableRect = paperRect.insetBy(dx: margin, dy: margin)
        pageRenderer.setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
        pageRenderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, paperRect, nil)
        let pageCount = max(1, pageRenderer.numberOfPages)
        pageRenderer.prepare(forDrawingPages: NSRange(location: 0, length: pageCount))
        for page in 0..<pageCount {
            UIGraphicsBeginPDFPage()
            pageRenderer.drawPage(at: page, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ChillMate-summary.pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}

private enum HelperSummaryBuilder {
    static func summary(
        profile: UserProfile?,
        entries: [NightEntry],
        timers: [DrugDoseTimerRecord],
        stiTests: [STDTestRecord],
        riskChecks: [RiskCheckRecord],
        now: Date = .now
    ) -> String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? .distantPast
        let recentEntries = entries.filter { $0.date >= cutoff }
        let recentTimers = timers.filter { $0.startedAt >= cutoff }
        let risky = recentEntries.filter { !$0.skippedNight && $0.hadSex && !$0.substances.isEmpty }
        let memoryGaps = recentEntries.filter(\.reportedMemoryGap)
        // Windowed like every other figure under the "Past 90 days" heading. These
        // two were counted over the whole array, so they reported an all-time total
        // under a 90 day label, and the array itself is a limited fetch, so the
        // number silently stopped moving once the user passed that many tests.
        // A clinician reads this sheet and has no way to see either problem.
        let recentTests = stiTests.filter { $0.testDate >= cutoff }
        let positiveTests = recentTests.filter(\.hasPositiveResult)
        let substances = ChillInsightCalculator.substanceCounts(entries: recentEntries).prefix(6).map { "\($0.label) (\($0.count))" }.joined(separator: ", ")
        let triggers = ChillInsightCalculator.triggerCounts(entries: recentEntries).prefix(6).map { "\($0.label) (\($0.count))" }.joined(separator: ", ")
        let medication = profile?.medications.map { "\($0.name) \($0.timingSummary)" }.joined(separator: "; ") ?? "Not set"

        return """
        ChillMate private helper summary
        Generated: \(now.formatted(date: .abbreviated, time: .shortened))

        Profile
        Name: \(profile?.name.isEmpty == false ? profile!.name : String(localized: "Not set"))
        Age: \(profile?.calculatedAge.description ?? "Not set")
        Sex: \(profile?.sex ?? "Not set")
        PrEP: \(profile?.isOnPrEP == true ? "Yes, \(profile?.prepSchedule ?? "")" : "No / not set")
        Medication: \(medication.isEmpty ? "Not set" : medication)

        Past 90 days
        Chills logged: \(recentEntries.filter { !$0.skippedNight }.count)
        Logs with sex + substances: \(risky.count)
        Check-in records: \(recentTimers.count)
        Continued-after-pause records: \(recentTimers.filter { $0.redoseDecision == RedoseDecision.redosed.rawValue }.count)
        Memory gaps reported: \(memoryGaps.count)
        STI tests saved: \(recentTests.count)
        Positive STI tests: \(positiveTests.count)

        Patterns
        Substances: \(substances.isEmpty ? "Not enough data" : substances)
        Triggers: \(triggers.isEmpty ? "Not enough data" : triggers)

        Talking points
        - I want help understanding my patterns without judgment.
        - I want to discuss sleep, substances, sex, consent, medication interactions, PrEP/PEP/STI care, or recovery goals.
        - I understand this export is self-reported app data and not a diagnosis.
        """
    }
}
