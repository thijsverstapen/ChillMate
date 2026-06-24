import Testing
@testable import ChillMate

struct SubstanceTests {

    @Test("Default timer is the midpoint of the effect window", arguments: Substance.allCases)
    func defaultTimerIsWindowMidpoint(substance: Substance) {
        let expected = (substance.effectWindow.lowerBound + substance.effectWindow.upperBound) / 2
        #expect(abs(substance.defaultTimerHours - expected) < 1e-9)
    }

    @Test("Adjusted timer stays clamped inside the effect window for any body size",
          arguments: Substance.allCases)
    func adjustedTimerStaysInWindow(substance: Substance) {
        // Deliberately out-of-range inputs to exercise the weight/height clamps (boundary test).
        for (weight, height) in [(20.0, 100.0), (300.0, 260.0), (75.0, 175.0)] {
            let hours = substance.adjustedTimerHours(weightKg: weight, heightCm: height)
            #expect(hours >= substance.effectWindow.lowerBound - 1e-9,
                    "\(substance) at \(weight)kg/\(height)cm fell below its window")
            #expect(hours <= substance.effectWindow.upperBound + 1e-9,
                    "\(substance) at \(weight)kg/\(height)cm exceeded its window")
        }
    }
}
