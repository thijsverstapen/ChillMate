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

/// The countries added in 5.0.0, and the property that has to hold for all of
/// them.
///
/// An emergency number is the one piece of content in this app where being wrong
/// is immediately dangerous, so every entry was checked against a published list
/// rather than written from memory, and the countries whose routing depends on
/// the service or the network were deliberately left out. They fall through to
/// 112 and to the manual override.
@Suite("Emergency numbers for every offered country")
struct EmergencyCountryCoverageTests {

    @Test("Every country in the picker resolves to a dialable number", .tags(.safety),
          arguments: EmergencyContactInfo.selectableCountries)
    func everyOfferedCountryResolves(country: String) {
        let number = EmergencyContactInfo.number(forCountry: country)
        #expect(number.isEmpty == false, "\(country) has no number")
        let digitsOnly = number.allSatisfy(\.isNumber)
        #expect(digitsOnly, "\(country) resolves to \"\(number)\", which is not dialable")

        let dialable = EmergencyContactInfo.dialDigits(number)
        #expect(dialable == number, "\(country) loses characters when dialled: \"\(dialable)\"")
    }

    @Test("The numbers added in 5.0.0 are the ones that were checked", .tags(.safety), arguments: [
        ("Austria", "112"), ("Switzerland", "112"), ("Luxembourg", "112"),
        ("Portugal", "112"), ("Italy", "112"), ("Sweden", "112"),
        ("Denmark", "112"), ("Norway", "112"), ("Poland", "112"),
        ("Canada", "911"), ("Mexico", "911"), ("Argentina", "911"),
    ])
    func newCountriesMatchTheSource(country: String, expected: String) {
        #expect(EmergencyContactInfo.number(forCountry: country) == expected)
    }

    /// The three that do not have one unambiguous number are not offered, and must
    /// not quietly acquire a guessed one.
    @Test("Countries with contested routing are not offered", .tags(.safety),
          arguments: ["Colombia", "Chile", "South Africa"])
    func contestedCountriesAreNotOffered(country: String) {
        #expect(EmergencyContactInfo.selectableCountries.contains(country) == false,
                "\(country) was added without resolving how it actually routes")
    }

    @Test("An unknown country still gives something that connects", .tags(.safety))
    func unknownCountryFallsBackTo112() {
        #expect(EmergencyContactInfo.number(forCountry: "Other") == "112")
        #expect(EmergencyContactInfo.number(forCountry: "Narnia") == "112")
    }

    @Test("No country is listed twice")
    func noDuplicates() {
        let countries = EmergencyContactInfo.selectableCountries
        #expect(Set(countries).count == countries.count)
    }
}
