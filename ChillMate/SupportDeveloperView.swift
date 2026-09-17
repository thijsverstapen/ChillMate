import StoreKit
import SwiftUI

/// The tip jar.
///
/// One consumable product, no subscription, no feature behind it. Split out of
/// `ProfileSetupView.swift` unchanged.

// MARK: - Support the developer (tip jar via In-App Purchase)

/// Tips use StoreKit In-App Purchase. Apple requires IAP for developer tips,
/// so external links, Apple Pay, and Revolut are not allowed. Create these as
/// **Consumable** products in App Store Connect with matching identifiers and
/// your chosen prices; they then load and display automatically. Arbitrary
/// "custom" amounts are not possible with IAP, so we offer fixed tiers.
private enum TipProduct {
    static let coffee = "com.BIJTHIJS.ChillMate.tip.coffee"
    static let pizza = "com.BIJTHIJS.ChillMate.tip.pizza"
    static let generous = "com.BIJTHIJS.ChillMate.tip.generous"
    static let all = [coffee, pizza, generous]
}

private struct TipOption: Identifiable {
    let id: String          // StoreKit product identifier
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let fallbackPrice: String
}

struct SupportDeveloperView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = TipStore()

    private let options: [TipOption] = [
        TipOption(id: TipProduct.coffee, title: String(localized: "Buy me a coffee"), detail: String(localized: "A little caffeine for late-night coding"), symbol: "cup.and.saucer.fill", tint: Color.chillIconAmber, fallbackPrice: "€3"),
        TipOption(id: TipProduct.pizza, title: String(localized: "Treat me to a pizza"), detail: String(localized: "Fuel for a whole new feature"), symbol: "fork.knife", tint: Color.chillIconOrange, fallbackPrice: "€10"),
        TipOption(id: TipProduct.generous, title: String(localized: "Sponsor a feature"), detail: String(localized: "Wow, thank you so much"), symbol: "sparkles", tint: Color.chillIconPink, fallbackPrice: "€25")
    ]

    @State private var selectedID = TipProduct.coffee
    @State private var isPurchasing = false
    @State private var alertTitle = String(localized: "Thank you 💜")
    @State private var alertMessage: String?

    private func priceText(for option: TipOption) -> String {
        store.products.first { $0.id == option.id }?.displayPrice ?? option.fallbackPrice
    }

    private var selectedOption: TipOption? {
        options.first { $0.id == selectedID }
    }

    var body: some View {
        Group {
            ZStack {
                DashboardBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeader(
                            title: String(localized: "Support the developer"),
                            subtitle: String(localized: "ChillMate is free for everyone. A tip is a small, completely optional way to say thanks."),
                            symbol: "heart.fill",
                            tint: Color.chillIconPink
                        )

                        storyCard

                        VStack(alignment: .leading, spacing: 10) {
                            Label("Choose a tip", systemImage: "gift.fill")
                                .font(.headline)
                                .foregroundStyle(Color.chillText)

                            ForEach(options) { tipRow($0) }
                        }

                        payButton

                        Text("Tips are a voluntary gift to the developer through the App Store. They don't unlock any features or content, everything in ChillMate stays free. Thank you for being here. 💜")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.chillSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(Text(verbatim: ""))
            .task { await store.loadProducts() }
            .alert(alertTitle, isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("Close", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private var storyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hey, thank you for using ChillMate 👋")
                .font(.headline)
                .foregroundStyle(Color.chillText)

            Text("I build ChillMate on my own, on late nights and weekends, because I wanted a calm, private place to look after yourself, with no judgment. It's completely free: no ads, nothing locked behind a paywall, and it will stay that way.")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("If ChillMate has helped you feel a little safer or more in control, a small tip is a lovely way to say thanks. Every bit goes straight back into keeping the app running, updated, and free for everyone.")
                .font(.callout)
                .foregroundStyle(Color.chillSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Thijs 💜")
                .font(.headline.weight(.heavy))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.chillPrimary, Color.chillSecondaryBlue, Color.chillMint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassSurface(radius: 26, tint: Color.chillIconPink.opacity(0.10), interactive: true)
    }

    private func tipRow(_ tip: TipOption) -> some View {
        let isSelected = selectedID == tip.id
        return Button {
            withAnimation(.snappy) { selectedID = tip.id }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tip.symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tip.tint)
                    .frame(width: 40, height: 40)
                    .background(tip.tint.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(tip.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.chillText)
                    Text(tip.detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chillSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(priceText(for: tip))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.chillText)

                selectionDot(isSelected)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .glassSurface(radius: 20, tint: tip.tint.opacity(isSelected ? 0.16 : 0.06), interactive: true)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(tip.tint.opacity(isSelected ? 0.7 : 0), lineWidth: 1.5)
            }
        }
        .buttonStyle(ChillPlainButtonStyle())
    }

    private func selectionDot(_ isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(isSelected ? Color.chillMint : Color.chillSecondary.opacity(0.5))
    }

    @ViewBuilder
    private var payButton: some View {
        let priceLabel = selectedOption.map { priceText(for: $0) } ?? ""
        let isLoadingProducts = store.loadState == .loading
        let loadFailed = store.loadState == .failed || (store.loadState == .loaded && store.products.isEmpty)
        let isBlocked = isPurchasing || isLoadingProducts

        if loadFailed {
            Button {
                Task { await store.retryLoad() }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "arrow.clockwise")
                        .font(.headline)
                    Text("Retry")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.chillSecondary.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(ChillPlainButtonStyle())
        } else {
            Button(action: purchase) {
                HStack(spacing: 9) {
                    if isBlocked {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "heart.fill")
                            .font(.headline)
                    }
                    Text(isPurchasing ? String(localized: "Processing…") :
                         isLoadingProducts ? String(localized: "Loading…") :
                         String(localized: "Leave a \(priceLabel) tip"))
                        .font(.headline.weight(.bold))
                        .sensoryFeedback(trigger: isPurchasing) { _, purchasing in purchasing ? .impact(weight: .medium) : nil }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Color.chillPrimary, Color.chillSecondaryBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .buttonStyle(ChillPlainButtonStyle())
            .opacity(isBlocked ? 0.6 : 1)
            .allowsHitTesting(!isBlocked)
        }
    }

    private func purchase() {
        if store.loadState == .loading {
            return
        }
        guard let product = store.products.first(where: { $0.id == selectedID }) else {
            alertTitle = String(localized: "Tips unavailable")
            alertMessage = String(localized: "Tipping isn't available right now. Make sure you're signed in to the App Store, then try again.")
            return
        }

        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            switch await store.purchase(product) {
            case .success:
                alertTitle = String(localized: "Thank you 💜")
                alertMessage = String(localized: "Your tip means the world and helps keep ChillMate free and updated.")
            case .cancelled:
                break
            case .failed(let message):
                alertTitle = String(localized: "Something went wrong")
                alertMessage = message ?? "The tip could not be completed. Please try again."
            }
        }
    }
}

/// Loads and purchases the tip In-App Purchases via StoreKit 2.
@MainActor
@Observable
final class TipStore {
    enum Outcome { case success, cancelled, failed(String?) }
    enum LoadState { case idle, loading, loaded, failed }

    private(set) var products: [Product] = []
    private(set) var loadState: LoadState = .idle

    func loadProducts() async {
        guard products.isEmpty else { return }
        loadState = .loading
        do {
            let fetched = try await Product.products(for: TipProduct.all)
            products = fetched.sorted { $0.price < $1.price }
            loadState = .loaded
        } catch {
            products = []
            loadState = .failed
        }
    }

    func retryLoad() async {
        loadState = .idle
        products = []
        await loadProducts()
    }

    func purchase(_ product: Product) async -> Outcome {
        do {
            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return .success
                case .unverified:
                    return .failed("Your purchase could not be verified.")
                }
            case .userCancelled:
                return .cancelled
            case .pending:
                return .failed("Your purchase is pending approval.")
            @unknown default:
                return .failed(nil)
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
