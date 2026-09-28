import CoreLocation
import MapKit
import ChillMateCore

// Looking up where you are, for a night log or a message being sent.

struct LoggedLocation: Equatable, Sendable {
    let name: String
    let latitude: Double
    let longitude: Double

    var coordinateSummary: String {
        let latitudeText = latitude.formatted(.number.precision(.fractionLength(4)))
        let longitudeText = longitude.formatted(.number.precision(.fractionLength(4)))
        return "\(latitudeText), \(longitudeText)"
    }

    var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Current location" : trimmedName
    }
}

@MainActor
final class LocationLookupService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationLookupService()

    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    @MainActor
    func currentLoggedLocation() async throws -> LoggedLocation {
        let location = try await currentLocation()
        let name = await placeName(for: location)

        return LoggedLocation(
            name: name,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    @MainActor
    private func currentLocation() async throws -> CLLocation {
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationLookupError.servicesDisabled
        }

        if manager.authorizationStatus == .notDetermined {
            try await requestAuthorization()
        }

        guard manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways else {
            throw LocationLookupError.permissionDenied
        }

        guard locationContinuation == nil else {
            throw LocationLookupError.requestInProgress
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    @MainActor
    private func requestAuthorization() async throws {
        guard authorizationContinuation == nil else {
            throw LocationLookupError.requestInProgress
        }

        try await withCheckedThrowingContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func placeName(for location: CLLocation) async -> String {
        if #available(iOS 26.0, *), let request = MKReverseGeocodingRequest(location: location) {
            return await withCheckedContinuation { continuation in
                request.getMapItems { mapItems, _ in
                    let mapItem = mapItems?.first
                    var namedParts = [
                        mapItem?.name,
                        mapItem?.address?.shortAddress
                    ]
                    .compactMap { part -> String? in
                        let trimmed = part?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        return trimmed.isEmpty ? nil : trimmed
                    }

                    if namedParts.isEmpty, let fullAddress = mapItem?.address?.fullAddress {
                        namedParts = [fullAddress]
                    }

                    continuation.resume(returning: Self.displayName(from: namedParts))
                }
            }
        }

        return String(localized: "Current location")
    }

    private static func displayName(from namedParts: [String]) -> String {
        guard !namedParts.isEmpty else {
            return String(localized: "Current location")
        }

        let uniqueParts = Array(NSOrderedSet(array: namedParts)) as? [String] ?? namedParts
        return uniqueParts.prefix(2).joined(separator: ", ")
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // CLLocationManager delivers callbacks on the thread its manager was created on.
        // The manager is created in this @MainActor type's init, so callbacks arrive on main.
        // Read the Sendable status here so the non-Sendable manager isn't captured into the hop.
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            guard let continuation = authorizationContinuation else {
                return
            }

            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                authorizationContinuation = nil
                continuation.resume()
            case .denied, .restricted:
                authorizationContinuation = nil
                continuation.resume(throwing: LocationLookupError.permissionDenied)
            case .notDetermined:
                break
            @unknown default:
                authorizationContinuation = nil
                continuation.resume(throwing: LocationLookupError.permissionDenied)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            guard let continuation = locationContinuation else {
                return
            }

            locationContinuation = nil

            if let location = locations.last {
                continuation.resume(returning: location)
            } else {
                continuation.resume(throwing: LocationLookupError.locationUnavailable)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            guard let continuation = locationContinuation else {
                return
            }

            locationContinuation = nil
            continuation.resume(throwing: error)
        }
    }
}

enum LocationLookupError: LocalizedError {
    case servicesDisabled
    case permissionDenied
    case locationUnavailable
    case requestInProgress

    var errorDescription: String? {
        switch self {
        case .servicesDisabled:
            String(localized: "Location services are turned off for this device.")
        case .permissionDenied:
            String(localized: "Location permission is needed to attach your current location.")
        case .locationUnavailable:
            String(localized: "ChillMate could not find your current location.")
        case .requestInProgress:
            String(localized: "ChillMate is already checking your location.")
        }
    }
}

/// Conformance declared here rather than beside the protocol: `LocationLookup`
/// inherits `Sendable`, and Swift treats a Sendable conformance in another
/// file as retroactive — a warning today and an error in a future language
/// mode.
extension LocationLookupService: LocationLookup {}
