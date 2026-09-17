import Foundation
import ChillMateCore

/// Which published curve a logged route corresponds to.
///
/// `AdministrationRoute` is stored on a SwiftData model and lives with the rest
/// of the care models, so it stays in the app while `SubstanceReference.Route`
/// moved into `ChillMateCore`. This is the one line that joins them, and the app
/// is the right side of the boundary for it: the domain has no business knowing
/// how this particular app happens to record a route.
extension AdministrationRoute {

    /// The reference route this logged route corresponds to, where one exists.
    ///
    /// Injection has no counterpart: nothing in `SubstanceReference` carries
    /// intravenous figures, and mapping it onto the oral row would attach the
    /// wrong curve to the fastest route there is.
    public var referenceRoute: SubstanceReference.Route? {
        switch self {
        case .sniffed: .insufflated
        case .swallowed: .oral
        case .smoked: .smoked
        case .injected: nil
        }
    }
}
