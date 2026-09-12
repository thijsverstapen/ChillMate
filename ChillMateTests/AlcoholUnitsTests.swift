import Testing
import ChillMateCore
@testable import ChillMate

/// The alcohol arithmetic, and the line it does not cross.
///
/// Everything here is conversion over published definitions. The important
/// property is stated in the type itself and enforced by what is absent: there is
/// no blood-alcohol estimate, because a number that looked like impairment would
/// be acted on by somebody deciding whether to drive.
@Suite("Alcohol units")
struct AlcoholUnitsTests {

    /// The three reference servings exist because each is defined as roughly one
    /// standard glass. If the arithmetic did not land near 10 g, the definitions
    /// would be wrong or the formula would be.
    @Test("Each reference serving is about one standard glass", arguments: ["beer", "wine", "spirit"])
    func referenceServingsAreOneGlass(id: String) throws {
        let serving = try #require(AlcoholUnits.referenceServings.first { $0.id == id })
        let glasses = AlcoholUnits.standardGlasses(
            volumeML: serving.volumeML, abvPercent: serving.abvPercent
        )
        #expect(abs(glasses - 1) < 0.06, "\(id) is \(glasses) standard glasses")
    }

    /// The NHS formula, checked against the worked example in its own guidance:
    /// 5% ABV, 568 ml pint, just under three units.
    @Test("A pint of 5% beer is the units the NHS says it is")
    func nhsFormulaMatchesItsOwnExample() {
        let units = AlcoholUnits.ukUnits(volumeML: 568, abvPercent: 5)
        #expect(abs(units - 2.84) < 0.01, "got \(units)")
    }

    @Test("A UK unit is 10 ml of ethanol, which is about 8 grams")
    func aUnitIsAboutEightGrams() {
        // One unit exactly: 10 ml of pure alcohol.
        let grams = AlcoholUnits.grams(volumeML: 10, abvPercent: 100)
        #expect(abs(grams - AlcoholUnits.gramsPerUKUnit) < 0.25, "got \(grams) g")
    }

    /// The point of showing the last two servings at all.
    @Test("A large glass of wine is more than two standard glasses")
    func aLargeWineIsNotOneDrink() throws {
        let serving = try #require(AlcoholUnits.referenceServings.first { $0.id == "largewine" })
        #expect(serving.grams > 20)
        #expect(AlcoholUnits.standardGlasses(volumeML: serving.volumeML, abvPercent: serving.abvPercent) > 2)
    }

    @Test("Nothing in the glass is nothing to count", arguments: [
        (0.0, 5.0), (250.0, 0.0), (0.0, 0.0), (-100.0, 5.0), (250.0, -5.0),
    ])
    func emptyOrNonsenseIsZero(volumeML: Double, abvPercent: Double) {
        #expect(AlcoholUnits.grams(volumeML: volumeML, abvPercent: abvPercent) == 0)
        #expect(AlcoholUnits.ukUnits(volumeML: volumeML, abvPercent: abvPercent) == 0)
        #expect(AlcoholUnits.standardGlasses(volumeML: volumeML, abvPercent: abvPercent) == 0)
    }

    @Test("Twice the drink is twice the alcohol")
    func scalesLinearly() {
        let single = AlcoholUnits.grams(volumeML: 250, abvPercent: 5)
        let double = AlcoholUnits.grams(volumeML: 500, abvPercent: 5)
        #expect(abs(double - single * 2) < 0.001)

        let stronger = AlcoholUnits.grams(volumeML: 250, abvPercent: 10)
        #expect(abs(stronger - single * 2) < 0.001)
    }

    @Test("Every reference serving is named and sane", arguments: AlcoholUnits.referenceServings)
    func servingsAreWellFormed(serving: AlcoholUnits.Serving) {
        #expect(serving.name.isEmpty == false)
        #expect(serving.volumeML > 0)
        #expect(serving.abvPercent > 0 && serving.abvPercent <= 100)
        #expect(serving.grams > 0)
    }

    @Test("Serving ids are unique, so the list can be drawn without an index")
    func servingIdsAreUnique() {
        let ids = AlcoholUnits.referenceServings.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
