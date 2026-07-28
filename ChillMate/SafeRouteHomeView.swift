import Foundation
import MapKit
import SwiftData
import SwiftUI
import UIKit

struct SafeRouteHomeView: View {
    @Query(ChillMateQueries.profile) private var profiles: [UserProfile]
    @AppStorage(DefaultsKey.trustedContactPhone) private var trustedContactPhone = ""
    @AppStorage(DefaultsKey.trustedContactMessage) private var trustedContactMessage = "Please come get me, I’m not okay at this moment."
    @State private var destination = ""
    @State private var selectedRouteMode: RouteTransportMode = .transit
    @State private var routeSuggestions: [RouteSuggestion] = []
    @State private var selectedSuggestion: RouteSuggestion?
    @State private var routeSearchTask: Task<Void, Never>?
    @State private var currentLocation: LoggedLocation?
    @State private var message: String?
    @State private var isFetchingLocation = false

    private var savedHomeAddress: String {
        profiles.first?.homeAddress.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var body: some View {
        // No own NavigationStack: this is always pushed onto Home's stack (from the
        // "While you’re out" group), so wrapping it would nest stacks and blank out.
        ZStack {
                DashboardBackdrop()

                routeForm
            }
            .navigationTitle("")
            .endEditingOnTap()
            .onChange(of: destination) { _, newValue in
                searchDestinationSuggestions(for: newValue)
            }
    }

    private func searchDestinationSuggestions(for query: String) {
        selectedSuggestion = nil
        routeSearchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            routeSuggestions = []
            return
        }

        routeSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }

            let suggestions = await RouteSearchService.suggestions(for: trimmed)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                routeSuggestions = suggestions
            }
        }
    }

    private func openDirections() {
        if let selectedSuggestion {
            if selectedRouteMode == .cycling {
                let coordinate = selectedSuggestion.mapItem.location.coordinate
                openMapsURL(destination: "\(coordinate.latitude),\(coordinate.longitude)")
                return
            }

            selectedSuggestion.mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: selectedRouteMode.mapKitDirectionsMode
            ])
            return
        }

        let trimmedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDestination.isEmpty {
            guard !savedHomeAddress.isEmpty else {
                message = String(localized: "Add a home address in Profile first, or type a destination here.")
                return
            }
            destination = savedHomeAddress
            openMapsURL(destination: savedHomeAddress)
            return
        }

        openMapsURL(destination: trimmedDestination)
    }

    private func openMapsURL(destination: String) {
        let encoded = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "maps://?daddr=\(encoded)&dirflg=\(selectedRouteMode.urlDirectionFlag)") else { return }
        UIApplication.shared.open(url)
    }

    private func openUber() {
        if let url = staticURL("https://m.uber.com/ul/") { UIApplication.shared.open(url) }
    }

    private func openBolt() {
        if let url = staticURL("https://bolt.eu/") { UIApplication.shared.open(url) }
    }

    private func shareLocationNow() {
        isFetchingLocation = true
        message = nil

        Task {
            do {
                let location = try await LocationLookupService.shared.currentLoggedLocation()
                await MainActor.run {
                    currentLocation = location
                    isFetchingLocation = false
                    openSMS(body: "\(trustedContactMessage)\n\nMy location: https://maps.apple.com/?ll=\(location.latitude),\(location.longitude)")
                }
            } catch {
                await MainActor.run {
                    isFetchingLocation = false
                    message = error.localizedDescription
                }
            }
        }
    }

    private func getMeHomeEmergencyFlow() {
        guard !savedHomeAddress.isEmpty else {
            message = String(localized: "Add a home address in Profile first so Get me home knows where to navigate.")
            shareLocationNow()
            return
        }

        selectedSuggestion = nil
        routeSuggestions = []
        destination = savedHomeAddress
        shareLocationNow()
        openMapsURL(destination: savedHomeAddress)
    }

    private func openSMS(body: String) {
        let phone = trustedContactPhone.filter { $0.isNumber || $0 == "+" }
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "sms:\(phone)&body=\(encodedBody)") else { return }
        UIApplication.shared.open(url)
    }

    /// Scrolling content, split out of a 149-line body.
    @ViewBuilder
    private var routeForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: String(localized: "Safe route home"),
                    subtitle: String(localized: "Plan transport, share where you are, or open a get-me-home flow quickly. Search an address, choose transit, driving, or cycling, then open Maps or message your trusted contact."),
                    symbol: "location.fill",
                    tint: Color.chillMint
                )

                VStack(alignment: .leading, spacing: 12) {
                    CareSectionTitle(title: String(localized: "Destination"), symbol: "map.fill")

                    TextField("Where do you want to go?", text: $destination)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color.chillText)
                        .padding(14)
                        .glassSurface(radius: 18, tint: .black.opacity(0.04), interactive: true)

                    if !savedHomeAddress.isEmpty {
                        Button {
                            selectedSuggestion = nil
                            routeSuggestions = []
                            destination = savedHomeAddress
                        } label: {
                            Label("Use saved home address", systemImage: "house.fill")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ChillPillButtonStyle(prominent: false))
                    }

                    if !routeSuggestions.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(routeSuggestions) { suggestion in
                                Button {
                                    selectedSuggestion = suggestion
                                    destination = suggestion.title
                                    routeSuggestions = []
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundStyle(Color.chillMint)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(suggestion.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Color.chillText)
                                            if !suggestion.subtitle.isEmpty {
                                                Text(suggestion.subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(Color.chillSecondary)
                                                    .lineLimit(2)
                                            }
                                        }

                                        Spacer(minLength: 0)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .glassSurface(radius: 18, tint: Color.chillMint.opacity(0.07), interactive: true)
                                }
                                .buttonStyle(ChillPlainButtonStyle())
                            }
                        }
                    }

                    Picker("Route type", selection: $selectedRouteMode) {
                        ForEach(RouteTransportMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.symbolName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button(action: openDirections) {
                        Label("Start \(selectedRouteMode.title.lowercased())", systemImage: selectedRouteMode.symbolName)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChillPillButtonStyle(prominent: true))

                    HStack(spacing: 10) {
                        Button(action: openUber) {
                            Label("Uber", systemImage: "car.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ChillPillButtonStyle(prominent: false, tint: .chillText))

                        Button(action: openBolt) {
                            Label("Bolt", systemImage: "bolt.car.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ChillPillButtonStyle(prominent: false, tint: .chillText))
                    }
                    .font(.headline)
                }
                .padding(16)
                .glassSurface(radius: 28, tint: Color.chillMint.opacity(0.10), interactive: true)

                VStack(alignment: .leading, spacing: 12) {
                    CareSectionTitle(title: String(localized: "Share location"), symbol: "location.circle.fill")

                    if let currentLocation {
                        Text(currentLocation.locationMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.chillSecondary)
                    }

                    if let message {
                        Text(message)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.chillSecondary)
                    }

                    Button(action: shareLocationNow) {
                        Label(isFetchingLocation ? "Getting location" : "Send location to trusted contact", systemImage: "message.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChillPillButtonStyle(prominent: true))
                    .disabled(isFetchingLocation || trustedContactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(16)
                .glassSurface(radius: 28, tint: Color.chillPrimary.opacity(0.10), interactive: true)

                Button(role: .destructive, action: getMeHomeEmergencyFlow) {
                    Label("Get me home now", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChillPillButtonStyle(prominent: true, tint: .red))
            }
            .padding(20)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }
}

private enum RouteTransportMode: String, CaseIterable, Identifiable {
    case transit = "Transit"
    case driving = "Driving"
    case cycling = "Cycling"

    var id: String { rawValue }

    var title: String { rawValue }

    var symbolName: String {
        switch self {
        case .transit:
            "tram.fill"
        case .driving:
            "car.fill"
        case .cycling:
            "bicycle"
        }
    }

    var mapKitDirectionsMode: String {
        switch self {
        case .transit:
            MKLaunchOptionsDirectionsModeTransit
        case .driving:
            MKLaunchOptionsDirectionsModeDriving
        case .cycling:
            MKLaunchOptionsDirectionsModeDefault
        }
    }

    var urlDirectionFlag: String {
        switch self {
        case .transit:
            "r"
        case .driving:
            "d"
        case .cycling:
            "b"
        }
    }
}

private struct RouteSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let mapItem: MKMapItem
}

private enum RouteSearchService {
    @MainActor
    static func suggestions(for query: String) async -> [RouteSuggestion] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.prefix(5).map { item in
                RouteSuggestion(
                    title: item.name ?? query,
                    subtitle: item.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true) ?? item.address?.fullAddress ?? "",
                    mapItem: item
                )
            }
        } catch {
            return []
        }
    }
}

private extension LoggedLocation {
    var locationMessage: String {
        "\(name.isEmpty ? "Current location" : name) • \(coordinateSummary)"
    }
}
