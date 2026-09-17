// swift-tools-version: 6.2
import PackageDescription

/// ChillMate's domain, as ordinary Swift that needs no app to compile.
///
/// What lives here is the part of ChillMate that would still be true with no
/// screen attached: what a substance is, what two of them do together, what the
/// published sources say about doses and durations, when a check-in should land,
/// and what the small hours are. None of it imports SwiftUI or SwiftData.
///
/// The boundary is the point. A type in here cannot reach for a view, a model
/// container or a `UserDefaults` key, because it cannot see them — which is a
/// stronger guarantee than a convention, and it is the reason a four-thousand
/// line view could accumulate risk-engine code in the first place.
///
/// **Localized text resolves from the app's bundle, deliberately.** Every
/// `String(localized:)` in here passes `bundle: .main`, so the five-language
/// catalog stays in one place and a domain string resolves exactly as it did
/// before it moved. A package-local catalog would have split the app's
/// translations across two files and given every moved string a second way to
/// fall back to English, which is the failure this project spends most of its
/// gate on.
let package = Package(
    name: "ChillMateCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .watchOS(.v26)],
    products: [
        .library(name: "ChillMateCore", targets: ["ChillMateCore"])
    ],
    targets: [
        .target(name: "ChillMateCore")
    ]
)
