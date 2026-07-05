import CoreLocation
import Foundation

struct LocationSearchResult: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var subtitle: String
    var coordinate: LocationCoordinate
}

enum LocationSearchError: LocalizedError {
    case emptyQuery
    case noResults
    case currentLocationUnavailable
    case locationPermissionDenied

    var errorDescription: String? {
        switch self {
        case .emptyQuery: "Enter a town, address, orchard, vineyard, or growing area."
        case .noResults: "No matching location was found."
        case .currentLocationUnavailable: "Current location is unavailable. Check Location Services and try again."
        case .locationPermissionDenied: "Location permission is off. Enable it in Settings to use current location."
        }
    }
}

struct LocationSearchService {
    private let geocoder = CLGeocoder()

    func search(_ query: String) async throws -> [LocationSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { throw LocationSearchError.emptyQuery }

        let placemarks = try await geocoder.geocodeAddressString(trimmedQuery)
        let results = placemarks.compactMap { placemark -> LocationSearchResult? in
            guard let location = placemark.location else { return nil }
            return LocationSearchResult(
                name: placemark.name ?? placemark.locality ?? trimmedQuery,
                subtitle: [placemark.locality, placemark.administrativeArea, placemark.country]
                    .compactMap { $0 }
                    .removingDuplicates()
                    .joined(separator: ", "),
                coordinate: LocationCoordinate(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            )
        }

        guard !results.isEmpty else { throw LocationSearchError.noResults }
        return results
    }

    func result(for location: CLLocation) async throws -> LocationSearchResult {
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        let placemark = placemarks.first
        let subtitle = [placemark?.locality, placemark?.administrativeArea, placemark?.country]
            .compactMap { $0 }
            .removingDuplicates()
            .joined(separator: ", ")

        return LocationSearchResult(
            name: placemark?.name ?? placemark?.locality ?? "Current location",
            subtitle: subtitle.isEmpty ? "Current location" : subtitle,
            coordinate: LocationCoordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        )
    }
}

@MainActor
final class CurrentLocationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentLocation() async throws -> CLLocation {
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationSearchError.currentLocationUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                finish(with: .failure(LocationSearchError.locationPermissionDenied))
            @unknown default:
                finish(with: .failure(LocationSearchError.currentLocationUnavailable))
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            finish(with: .failure(LocationSearchError.locationPermissionDenied))
        case .notDetermined:
            break
        @unknown default:
            finish(with: .failure(LocationSearchError.currentLocationUnavailable))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else {
                finish(with: .failure(LocationSearchError.currentLocationUnavailable))
                return
            }
            finish(with: .success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            finish(with: .failure(error))
        }
    }

    private func finish(with result: Result<CLLocation, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        switch result {
        case .success(let location):
            continuation.resume(returning: location)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
