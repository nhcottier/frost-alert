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

    var errorDescription: String? {
        switch self {
        case .emptyQuery: "Enter a town, address, orchard, vineyard, or growing area."
        case .noResults: "No matching location was found."
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
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
