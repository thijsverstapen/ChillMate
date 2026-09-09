import Foundation
import Testing
@testable import ChillMate

/// The support directory is a list of places to go when something has gone wrong,
/// so the properties worth asserting are that every entry is complete, that
/// nothing is silently empty, and that the country routing actually routes.
@Suite("Support directory")
struct SupportDirectoryTests {

    private static let countries = SupportedCountry.allCases.map(\.rawValue)

    /// Countries with a drug-checking service this project could verify.
    ///
    /// Ireland, France and Australia are deliberately absent: no national
    /// programme was confirmed, and a plausible link to a service that cannot
    /// test anything is worse than no entry.
    private static let withDrugChecking = [
        "Netherlands", "Belgium", "Germany", "United Kingdom", "Spain", "United States",
    ]

    @Test("Every country resolves to a non-empty list", .tags(.safety))
    func everyCountryResolves() {
        for country in Self.countries {
            let resources = SupportResource.resources(for: country)
            #expect(resources.isEmpty == false, "\(country) has no support resources at all")
        }
    }

    @Test("No resource ships blank", .tags(.safety))
    func resourcesAreComplete() {
        for country in Self.countries {
            for resource in SupportResource.resources(for: country) {
                #expect(resource.title.isEmpty == false, "\(country) has a resource with no title")
                #expect(resource.detail.isEmpty == false, "\(country): \(resource.title) has no detail")
                #expect(resource.action.isEmpty == false, "\(country): \(resource.title) has no action label")
            }
        }
    }

    @Test("Every link is a real, absolute URL", .tags(.safety))
    func linksAreWellFormed() {
        for country in Self.countries {
            for resource in SupportResource.resources(for: country) {
                guard let url = resource.url else { continue }
                #expect(url.scheme != nil, "\(country): \(resource.title) has a URL with no scheme")
                #expect(["http", "https", "tel"].contains(url.scheme ?? ""),
                        "\(country): \(resource.title) uses an unexpected scheme (\(url.scheme ?? "none"))")
                if url.scheme != "tel" {
                    #expect(url.host != nil, "\(country): \(resource.title) has no host")
                }
            }
        }
    }

    // MARK: Drug checking

    @Test("Countries with a verified testing service link to it", .tags(.safety))
    func drugCheckingIsPresentWhereItExists() {
        for country in Self.withDrugChecking {
            let resources = SupportResource.resources(for: country)
            #expect(resources.contains { $0.tags.contains("checking") },
                    "\(country) has a drug-checking service and does not link to it")
        }
    }

    @Test("Countries without a verified service do not invent one", .tags(.safety))
    func drugCheckingIsAbsentWhereUnverified() {
        for country in ["Ireland", "France", "Australia"] {
            let resources = SupportResource.resources(for: country)
            #expect(resources.contains { $0.tags.contains("checking") } == false,
                    "\(country) links to a testing service that was never verified")
        }
    }

    @Test("The drug-checking entry always carries a link", .tags(.safety))
    func drugCheckingAlwaysLinks() throws {
        for country in Self.withDrugChecking {
            let resources = SupportResource.resources(for: country)
            let checking = try #require(resources.first { $0.tags.contains("checking") })
            let url = try #require(checking.url, "\(country)'s testing entry has no link, which makes it useless")
            #expect(url.scheme == "https")
        }
    }

    // MARK: Routing

    @Test("An unknown country still gets the international list", .tags(.safety))
    func unknownCountryFallsBack() {
        let resources = SupportResource.resources(for: "Atlantis")
        #expect(resources.isEmpty == false)
        #expect(resources.contains { $0.tags.contains("emergency") },
                "The fallback list has no emergency entry")
    }

    @Test("Every country offers a route to emergency help", .tags(.safety))
    func emergencyIsAlwaysReachable() {
        for country in Self.countries + ["Atlantis"] {
            let resources = SupportResource.resources(for: country)
            #expect(resources.contains { $0.tags.contains("emergency") },
                    "\(country) offers no emergency entry")
        }
    }
}

/// The phone and the watch have to agree on the spelling of every setting they
/// exchange.
///
/// They used to be bare literals at both ends, in two targets that cannot see
/// each other, so renaming one side left both compiling and the watch silently
/// falling back to its defaults with no error anywhere.
@Suite("Watch settings transport")
struct WatchSettingsKeyTests {

    @Test("Every pushed setting key is registered and unique", .tags(.safety))
    func keysAreRegisteredAndUnique() {
        let keys = WidgetSharedKey.watchSettingKeys
        #expect(keys.isEmpty == false)
        #expect(Set(keys).count == keys.count, "A setting key is listed twice: \(keys)")
        for key in keys {
            #expect(key.isEmpty == false)
            #expect(key.hasPrefix("watch"), "\(key) does not look like a watch setting key")
        }
    }

    /// The registry is what the sender iterates, so anything absent from it is
    /// never transmitted. `watchStressAndTemperatureDetection` is absent on
    /// purpose: it is a Settings toggle with no consumer on either side, and
    /// adding it to transport would only make the dead end harder to see.
    @Test("The registry matches what the watch actually reads", .tags(.safety))
    func registryCoversTheWatchsReads() {
        let expected = Set([
            "watchHydrationReminders",
            "watchBreathingHaptics",
            "watchDiscreetCheckIns",
            "watchVisibleTimers",
            "watchHeartRateWarnings",
        ])
        #expect(Set(WidgetSharedKey.watchSettingKeys) == expected,
                "The pushed settings drifted from what the watch reads: \(WidgetSharedKey.watchSettingKeys)")
    }
}
