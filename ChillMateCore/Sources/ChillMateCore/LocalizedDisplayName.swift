import Foundation

public extension RawRepresentable where RawValue == String {
    /// Localized display text for a String-backed enum, resolved from the String Catalog
    /// by rawValue. The rawValue stays the stable storage key; this is display-only.
    var localizedDisplayName: String {
        Bundle.main.localizedString(forKey: rawValue, value: rawValue, table: nil)
    }
}
