import Foundation

/// Turning a drink into the figure a national guideline is written in.
///
/// **This counts what went in the glass. It says nothing about how drunk anybody
/// is.** Blood alcohol depends on body water, food, time and liver function, none
/// of which this app can see, and a number presented as impairment would be acted
/// on by someone deciding whether to walk home or get in a car. So there is no
/// blood-alcohol estimate here and there should not be one.
///
/// What is here is arithmetic over published definitions:
///
/// * Ethanol's density is 0.789 g/ml, which is physics.
/// * A UK unit is 10 ml — about 8 g — of pure alcohol, and the NHS gives the
///   formula as `ABV × volume in ml ÷ 1000`.
/// * A standard glass across the Netherlands, France, Spain and most of Europe is
///   10 g of pure alcohol, set in the Dutch National Prevention Agreement for
///   international alignment and used by Trimbos and the Gezondheidsraad.
///
/// Sources fetched 11 September 2026: NHS "Calculating alcohol units", Trimbos
/// Expertisecentrum Alcohol.
enum AlcoholUnits {

    /// Grams of ethanol per millilitre.
    static let ethanolDensity = 0.789

    /// Grams of pure alcohol in one UK unit.
    static let gramsPerUKUnit = 8.0

    /// Grams of pure alcohol in one continental standard glass.
    static let gramsPerStandardGlass = 10.0

    /// Grams of pure alcohol in a drink.
    static func grams(volumeML: Double, abvPercent: Double) -> Double {
        guard volumeML > 0, abvPercent > 0 else { return 0 }
        return volumeML * (abvPercent / 100) * ethanolDensity
    }

    /// UK units, by the NHS formula.
    ///
    /// Deliberately the published formula rather than `grams / 8`: a UK unit is
    /// defined by volume of ethanol, not mass, and the two differ by a couple of
    /// percent. Matching the guideline someone is reading matters more than
    /// internal tidiness.
    static func ukUnits(volumeML: Double, abvPercent: Double) -> Double {
        guard volumeML > 0, abvPercent > 0 else { return 0 }
        return (abvPercent * volumeML) / 1000
    }

    /// Continental standard glasses of 10 g.
    static func standardGlasses(volumeML: Double, abvPercent: Double) -> Double {
        grams(volumeML: volumeML, abvPercent: abvPercent) / gramsPerStandardGlass
    }

    /// A drink someone would recognise, at the size and strength the standard-glass
    /// definitions use.
    ///
    /// These are the reference servings, not what anybody is actually poured. A
    /// large glass of wine in a bar is nearer 250 ml, and saying so is the point of
    /// having them on screen at all.
    struct Serving: Identifiable, Sendable {
        let id: String
        let name: String
        let volumeML: Double
        let abvPercent: Double

        var grams: Double { AlcoholUnits.grams(volumeML: volumeML, abvPercent: abvPercent) }
        var ukUnits: Double { AlcoholUnits.ukUnits(volumeML: volumeML, abvPercent: abvPercent) }
    }

    /// The reference servings, from the Dutch standard-glass definition: 250 ml of
    /// beer, 100 ml of wine, 35 ml of spirits, each about 10 g.
    static var referenceServings: [Serving] {
        [
            Serving(id: "beer", name: String(localized: "Beer, 250 ml at 5%"),
                    volumeML: 250, abvPercent: 5),
            Serving(id: "wine", name: String(localized: "Wine, 100 ml at 12%"),
                    volumeML: 100, abvPercent: 12),
            Serving(id: "spirit", name: String(localized: "Spirits, 35 ml at 35%"),
                    volumeML: 35, abvPercent: 35),
            Serving(id: "strongbeer", name: String(localized: "Strong beer, 330 ml at 8%"),
                    volumeML: 330, abvPercent: 8),
            Serving(id: "largewine", name: String(localized: "Large glass of wine, 250 ml at 13%"),
                    volumeML: 250, abvPercent: 13),
        ]
    }
}
