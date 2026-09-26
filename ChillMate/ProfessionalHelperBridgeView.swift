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
    /// Only read when the person asks for a draft; the counts above never use it.
    @Query(ChillMateQueries.recentJournalEntries) private var journals: [JournalEntry]

    @State private var pdfURL: URL?

    /// The drafted paragraph, once generated. Editable, because the point is that
    /// the words are the person's before a clinician reads them.
    @State private var ownWords = ""
    @State private var isDrafting = false
    @State private var includeOwnWords = false

    private var summary: String {
        let counts = HelperSummary.text(
            profile: profiles.first,
            entries: entries,
            timers: timers,
            stiTests: stiTests,
            riskChecks: riskChecks
        )
        let note = ownWords.trimmingCharacters(in: .whitespacesAndNewlines)
        guard includeOwnWords, !note.isEmpty else { return counts }
        // Under its own heading, so a clinician can see which part is a count and
        // which part is the person speaking. The two are not the same kind of
        // claim and should not read as one block.
        return counts + "\n\n" + String(localized: "In my own words") + "\n" + note
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

                        // Drafted from the person's own journal, on their phone,
                        // and editable before it goes anywhere. The summary above
                        // is counts; this is the one part that is somebody
                        // speaking, so it is opt-in and it is theirs to change.
                        if OnDeviceAffirmationService.isAvailable {
                            VStack(alignment: .leading, spacing: 10) {
                                CareSectionTitle(title: String(localized: "In my own words"), symbol: "quote.bubble")

                                if ownWords.isEmpty {
                                    Button {
                                        Task { await draftOwnWords() }
                                    } label: {
                                        Label(
                                            String(localized: "Draft this from my journal"),
                                            systemImage: isDrafting ? "hourglass" : "text.badge.plus"
                                        )
                                        .font(.subheadline.weight(.bold))
                                    }
                                    .buttonStyle(ChillPlainButtonStyle())
                                    .disabled(isDrafting)
                                } else {
                                    TextEditor(text: $ownWords)
                                        .frame(minHeight: 120)
                                        .font(.callout)
                                        .scrollContentBackground(.hidden)
                                        .padding(8)
                                        .glassSurface(radius: 16, tint: .black.opacity(0.04))

                                    Toggle(String(localized: "Include this in the summary"), isOn: $includeOwnWords)
                                        .font(.subheadline.weight(.semibold))
                                }

                                Text("Written on this device from what you wrote, then yours to change. Nobody has checked it, and it is not medical advice.")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.chillTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassSurface(radius: 24, tint: Color.chillMint.opacity(0.08))
                        }

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

    /// Reads the recent journal entries and drafts a paragraph, leaving it in the
    /// editor rather than in the summary.
    private func draftOwnWords() async {
        isDrafting = true
        defer { isDrafting = false }
        let texts = journals
            .sorted { $0.date > $1.date }
            .prefix(20)
            .map(\.searchableText)
            .filter { !$0.isEmpty }
        if let drafted = await OnDeviceAffirmationService.draftHelperNote(fromJournal: Array(texts)) {
            ownWords = drafted
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
