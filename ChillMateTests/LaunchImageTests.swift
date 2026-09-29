import Testing
import UIKit
@testable import ChillMate

/// The launch screen's image is compressed lossily in the asset catalog, which
/// took the compiled catalog from 4.1 MB to 2.3 MB together with an unused copy
/// that was removed. A launch image that failed to decode would be a blank first
/// second for everybody, and nothing else in the suite would notice.
@MainActor
@Suite("Launch image")
struct LaunchImageTests {

    @Test("The launch image decodes at its full size")
    func decodes() throws {
        let image = try #require(UIImage(named: "SplashScreen"))
        #expect(image.size.width * image.scale == 853)
        #expect(image.size.height * image.scale == 1844)
        #expect(image.cgImage != nil)
    }
}
