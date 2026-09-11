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
        HelperSummary.text(
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
