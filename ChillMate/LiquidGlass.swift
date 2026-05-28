import ImageIO
import SwiftUI
import UIKit

enum ChillBackgroundStyle: String, CaseIterable, Identifiable {
    case score = "Adaptive"
    case liquidPurple = "Liquid purple"
    case dusk = "Dusk"
    case mint = "Mint glass"
    case sunrise = "Sunrise"
    case photo = "Photo"

    var id: String { rawValue }

    var colors: [Color] {
        switch self {
        case .score:
            []
        case .liquidPurple:
            [.chillDarkBackground, .chillPrimary, .chillMint, .white]
        case .dusk:
            [.chillDarkBackground, .chillSurfaceDark, .chillSecondaryBlue, .white]
        case .mint:
            [.chillDarkBackground, .chillMint, .chillAccentTeal, .white]
        case .sunrise:
            [.chillPrimary, .chillSecondaryBlue, .chillMint, .white]
        case .photo:
            []
        }
    }
}

struct DashboardBackdrop: View {
    @AppStorage("appBackgroundStyle") private var appBackgroundStyle = ChillBackgroundStyle.score.rawValue
    @AppStorage("appBackgroundPhotoData") private var appBackgroundPhotoData = ""
    @AppStorage("lastDailyRecoveryScore") private var lastDailyRecoveryScore = 42
    @AppStorage("highContrastMode") private var highContrastMode = false
    @State private var decodedBackgroundImage: UIImage?
    var score: Int? = nil

    private var palette: DailyScorePalette {
        DailyScorePalette(score: score ?? lastDailyRecoveryScore)
    }

    private var style: ChillBackgroundStyle {
        ChillBackgroundStyle(rawValue: appBackgroundStyle) ?? .score
    }

    private var backgroundImageIdentifier: String {
        "\(appBackgroundStyle)-\(appBackgroundPhotoData.count)-\(appBackgroundPhotoData.prefix(32))"
    }

    var body: some View {
        ZStack {
            if style == .photo, let backgroundImage = decodedBackgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .overlay(.white.opacity(0.38))
                    .overlay(
                        LinearGradient(
                            colors: [.black.opacity(0.22), .white.opacity(0.56)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                LinearGradient(
                    colors: style == .score ? [
                        palette.top,
                        palette.middle,
                        palette.lower,
                        .white
                    ] : style.colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            if highContrastMode {
                LinearGradient(
                    colors: [.white.opacity(0.28), .white.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .task(id: backgroundImageIdentifier) {
            guard style == .photo, let data = Data(base64Encoded: appBackgroundPhotoData) else {
                decodedBackgroundImage = nil
                return
            }

            let cacheKey = "\(backgroundImageIdentifier)-1400"
            if let cachedImage = ChillBackgroundImageCache.image(for: cacheKey) {
                decodedBackgroundImage = cachedImage
                return
            }

            let optimizedData = await Task.detached(priority: .utility) {
                ChillImageOptimizer.downsampledJPEGData(from: data, maxPixelSize: 1400)
            }.value

            guard let image = UIImage(data: optimizedData) else {
                decodedBackgroundImage = nil
                return
            }

            ChillBackgroundImageCache.store(image, for: cacheKey)
            decodedBackgroundImage = image
        }
    }
}

@MainActor
private enum ChillBackgroundImageCache {
    private static var images: [String: UIImage] = [:]

    static func image(for key: String) -> UIImage? {
        images[key]
    }

    static func store(_ image: UIImage, for key: String) {
        if images.count > 4, let firstKey = images.keys.first {
            images.removeValue(forKey: firstKey)
        }
        images[key] = image
    }
}

enum ChillImageOptimizer {
    static func image(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [
            kCGImageSourceShouldCache: false
        ] as CFDictionary) else {
            return UIImage(data: data)
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)
        }

        return UIImage(cgImage: image)
    }

    static func downsampledJPEGData(from data: Data, maxPixelSize: CGFloat, compressionQuality: CGFloat = 0.82) -> Data {
        guard let image = image(from: data, maxPixelSize: maxPixelSize) else {
            return data
        }

        return image.jpegData(compressionQuality: compressionQuality) ?? data
    }
}

struct DailyScorePalette {
    let score: Int

    private var progress: Double {
        Double(min(max(score, 0), 100)) / 100
    }

    var top: Color {
        color(from: RGB(0.06, 0.07, 0.09), to: RGB(0.98, 0.78, 0.12))
    }

    var middle: Color {
        color(from: RGB(0.11, 0.12, 0.17), to: RGB(1.00, 0.90, 0.38))
    }

    var lower: Color {
        color(from: RGB(0.39, 0.40, 0.95), to: RGB(1.00, 0.98, 0.78))
    }

    var heroText: Color {
        score >= 72 ? .chillText : .white
    }

    var heroSecondary: Color {
        score >= 72 ? .chillSecondary : .white.opacity(0.78)
    }

    private func color(from: RGB, to: RGB) -> Color {
        Color(
            red: from.red + (to.red - from.red) * progress,
            green: from.green + (to.green - from.green) * progress,
            blue: from.blue + (to.blue - from.blue) * progress
        )
    }

    private struct RGB {
        let red: Double
        let green: Double
        let blue: Double

        init(_ red: Double, _ green: Double, _ blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }
    }
}

struct TestingOnlyNoticeCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.chillVisibleOrange)
                .frame(width: 30, height: 30)
                .glassSurface(radius: 15, tint: Color.chillVisibleOrange.opacity(0.12))

            VStack(alignment: .leading, spacing: 4) {
                Text("Beta notice")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.chillText)

                Text("This Beta app has not been reviewed by harm-reduction, sexual-health, or privacy/security professionals. For real support, open Support from More.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chillSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassSurface(radius: 22, tint: Color.chillVisibleOrange.opacity(0.08), interactive: true)
    }
}

struct LiquidGlassGroup<Content: View>: View {
    var spacing: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

struct GlassSurfaceModifier: ViewModifier {
    let radius: CGFloat
    let tint: Color
    let interactive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if interactive {
                content
                    .glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: radius))
                    .glassOutline(radius: radius)
            } else {
                content
                    .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: radius))
                    .glassOutline(radius: radius)
            }
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .glassOutline(radius: radius)
        }
    }
}

extension View {
    func glassSurface(
        radius: CGFloat = 28,
        tint: Color = .white.opacity(0.24),
        interactive: Bool = false
    ) -> some View {
        modifier(GlassSurfaceModifier(radius: radius, tint: tint, interactive: interactive))
    }

    func glassOutline(radius: CGFloat) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(.black.opacity(0.07), lineWidth: 1)
        }
    }
}

extension Color {
    static let chillPrimary = Color(red: 99 / 255, green: 102 / 255, blue: 241 / 255)
    static let chillSecondaryBlue = Color(red: 96 / 255, green: 165 / 255, blue: 250 / 255)
    static let chillMint = Color(red: 126 / 255, green: 231 / 255, blue: 199 / 255)
    static let chillAccentTeal = Color(red: 167 / 255, green: 243 / 255, blue: 208 / 255)
    static let chillVisibleMint = Color(red: 5 / 255, green: 118 / 255, blue: 95 / 255)
    static let chillVisibleBlue = Color(red: 49 / 255, green: 70 / 255, blue: 190 / 255)
    static let chillVisibleOrange = Color(red: 181 / 255, green: 76 / 255, blue: 0 / 255)
    static let chillVisiblePurple = Color(red: 112 / 255, green: 43 / 255, blue: 196 / 255)
    static let chillVisiblePink = Color(red: 185 / 255, green: 28 / 255, blue: 96 / 255)
    static let chillVisibleTeal = Color(red: 0 / 255, green: 104 / 255, blue: 132 / 255)
    static let chillVisibleAmber = Color(red: 146 / 255, green: 64 / 255, blue: 14 / 255)
    static let chillDarkBackground = Color(red: 15 / 255, green: 17 / 255, blue: 23 / 255)
    static let chillSurfaceDark = Color(red: 28 / 255, green: 31 / 255, blue: 43 / 255)
    static let chillText = Color(red: 15 / 255, green: 17 / 255, blue: 23 / 255)
    static let chillSecondary = Color(red: 0.28, green: 0.31, blue: 0.39)
    static let chillTertiary = Color(red: 0.48, green: 0.52, blue: 0.60)
}

struct GlassActionButton<Label: View>: View {
    let prominent: Bool
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        if #available(iOS 26.0, *) {
            if prominent {
                Button(action: action) {
                    label()
                }
                .buttonStyle(.glassProminent)
            } else {
                Button(action: action) {
                    label()
                }
                .buttonStyle(.glass)
            }
        } else {
            if prominent {
                Button(action: action) {
                    label()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: action) {
                    label()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct BackChevronButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.headline.weight(.bold))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.chillText)
        .glassSurface(radius: 18, tint: .white.opacity(0.28), interactive: true)
        .accessibilityLabel("Go back")
    }
}

struct DiscardChangesDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let discard: () -> Void

    func body(content: Content) -> some View {
        content.liquidGlassAlert(
            isPresented: $isPresented,
            title: "Discard changes?",
            message: "You have entered information that has not been saved.",
            primaryTitle: "Discard changes",
            primaryIsDestructive: true,
            primaryAction: discard,
            secondaryTitle: "Keep editing"
        )
    }
}

struct LiquidGlassAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let primaryTitle: String
    let primaryIsDestructive: Bool
    let primaryAction: () -> Void
    let secondaryTitle: String

    private var primaryTint: Color {
        primaryIsDestructive ? .red : .chillPrimary
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    ZStack {
                        Color.black.opacity(0.28)
                            .ignoresSafeArea()
                            .onTapGesture {
                                isPresented = false
                            }

                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: primaryIsDestructive ? "exclamationmark.triangle.fill" : "questionmark.circle.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(primaryTint)
                                    .frame(width: 52, height: 52)
                                    .glassSurface(radius: 26, tint: primaryTint.opacity(0.14))

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(title)
                                        .font(.title3.bold())
                                        .foregroundStyle(Color.chillText)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text(message)
                                        .font(.callout)
                                        .lineSpacing(2)
                                        .foregroundStyle(Color.chillSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            VStack(spacing: 10) {
                                GlassActionButton(prominent: true) {
                                    isPresented = false
                                    primaryAction()
                                } label: {
                                    Text(primaryTitle)
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                }
                                .tint(primaryTint)

                                GlassActionButton(prominent: false) {
                                    isPresented = false
                                } label: {
                                    Text(secondaryTitle)
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                }
                                .tint(.chillPrimary)
                            }
                        }
                        .padding(22)
                        .frame(maxWidth: 340)
                        .glassSurface(radius: 34, tint: .white.opacity(0.34), interactive: true)
                        .shadow(color: .black.opacity(0.20), radius: 28, y: 16)
                        .padding(.horizontal, 24)
                    }
                    .zIndex(50)
                }
            }
    }
}

extension View {
    func discardChangesDialog(isPresented: Binding<Bool>, discard: @escaping () -> Void) -> some View {
        modifier(DiscardChangesDialogModifier(isPresented: isPresented, discard: discard))
    }

    func liquidGlassAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        primaryTitle: String,
        primaryIsDestructive: Bool = false,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String = "Cancel"
    ) -> some View {
        modifier(
            LiquidGlassAlertModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                primaryTitle: primaryTitle,
                primaryIsDestructive: primaryIsDestructive,
                primaryAction: primaryAction,
                secondaryTitle: secondaryTitle
            )
        )
    }
}
extension UIApplication {
    static func chillmateDismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

private struct EndEditingOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture().onEnded {
                    UIApplication.chillmateDismissKeyboard()
                }
            )
    }
}

private struct EdgeSwipeDismissModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onEnded { value in
                        let isFromLeftEdge = value.startLocation.x < 24
                        let isRightSwipe = value.translation.width > 80 && abs(value.translation.height) < 60
                        if isFromLeftEdge && isRightSwipe {
                            dismiss()
                        }
                    }
            )
    }
}

private struct EdgeSwipeActionModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onEnded { value in
                        let isFromLeftEdge = value.startLocation.x < 24
                        let isRightSwipe = value.translation.width > 80 && abs(value.translation.height) < 60
                        if isFromLeftEdge && isRightSwipe {
                            action()
                        }
                    }
            )
    }
}

extension View {
    func endEditingOnTap() -> some View { modifier(EndEditingOnTapModifier()) }
    func edgeSwipeToDismiss() -> some View { modifier(EdgeSwipeDismissModifier()) }
    func edgeSwipeBack(_ action: @escaping () -> Void) -> some View { modifier(EdgeSwipeActionModifier(action: action)) }
}
