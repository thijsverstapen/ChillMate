import Foundation
import Testing
@testable import ChillMate

/// Regression tests for the bug where the Apple Watch dialled 112 for users in the
/// United States and Australia.
///
/// There were three separate country-to-number tables in the app and only the two
/// on the phone were correct; `WatchConnectivityService` had its own copy that
/// special-cased the United Kingdom and nothing else. 112 does not reach emergency
/// services in the US.
struct EmergencyContactInfoTests {

    @Test("Every supported country maps to its own emergency number", .tags(.safety), arguments: [
        ("Netherlands", "112"),
        ("Belgium", "112"),
        ("Germany", "112"),
        ("Ireland", "112"),
        ("France", "112"),
        ("Spain", "112"),
        ("United Kingdom", "999"),
        ("United States", "911"),
        ("Australia", "000"),
    ])
    func countryMapping(country: String, expected: String) {
        #expect(EmergencyContactInfo.number(forCountry: country) == expected)
    }

    @Test("An unknown country falls back to 112", .tags(.safety))
    func unknownCountryFallsBackTo112() {
        #expect(EmergencyContactInfo.number(forCountry: "Other") == "112")
        #expect(EmergencyContactInfo.number(forCountry: "") == "112")
        #expect(EmergencyContactInfo.number(forCountry: "Atlantis") == "112")
    }

    @Test("The support directory resolves through the same table", .tags(.safety), arguments: [
        "Netherlands", "Belgium", "Germany", "Ireland", "France",
        "Spain", "United Kingdom", "United States", "Australia", "Other",
    ])
    func supportDirectoryAgrees(country: String) {
        // Guards against a second table reappearing.
        #expect(SupportResource.emergencyNumber(for: country) == EmergencyContactInfo.number(forCountry: country))
    }

    @Test("A manual override wins over the country default", .tags(.safety))
    func overrideWins() {
        let defaults = Self.isolatedDefaults()
        defaults.set("United States", forKey: DefaultsKey.country)
        defaults.set("555", forKey: DefaultsKey.localEmergencyNumber)
        #expect(EmergencyContactInfo.resolvedNumber(in: defaults) == "555")
    }

    @Test("A blank or whitespace override is ignored", .tags(.safety))
    func blankOverrideIgnored() {
        let defaults = Self.isolatedDefaults()
        defaults.set("Australia", forKey: DefaultsKey.country)

        for blank in ["", "   ", "\n", "\t "] {
            defaults.set(blank, forKey: DefaultsKey.localEmergencyNumber)
            #expect(EmergencyContactInfo.resolvedNumber(in: defaults) == "000",
                    "Blank override \(blank.debugDescription) should fall back to the country number")
        }
    }

    @Test("With no country set at all, the number is still dialable", .tags(.safety))
    func unsetCountryStillResolves() {
        let defaults = Self.isolatedDefaults()
        #expect(EmergencyContactInfo.resolvedNumber(in: defaults) == "112")
    }

    @Test("Dial digits keep only what tel: accepts")
    func dialDigitsStripsFormatting() {
        #expect(EmergencyContactInfo.dialDigits("+31 (0)6 1234 5678") == "+310612345678")
        #expect(EmergencyContactInfo.dialDigits("112") == "112")
        #expect(EmergencyContactInfo.dialDigits("9-9-9") == "999")
    }

    @Test("The fallback dial URL is always well formed", .tags(.safety))
    func fallbackDialURLIsValid() {
        let url = EmergencyContactInfo.fallbackDialURL
        #expect(url.scheme == "tel", "Fallback must remain a tel: URL, got \(url)")
    }

    /// A throwaway suite, so these never read or write the real user defaults.
    private static func isolatedDefaults() -> UserDefaults {
        let name = "EmergencyContactInfoTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
