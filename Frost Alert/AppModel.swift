import Foundation

enum DashboardState: Equatable {
    case loading
    case empty
    case loaded([LocationAssessment])
    case failed(String)
}

@MainActor
final class AppModel: ObservableObject {
    @Published var locations: [GrowingLocation] = []
    @Published private(set) var state: DashboardState = .loading

    let notifications = NotificationService()

    private let calculator = FrostRiskCalculator()
    private let storageKey = "savedGrowingLocations"

    init() {
        locations = loadSavedLocations()
    }

    func load() async {
        guard !locations.isEmpty else {
            state = .empty
            return
        }

        state = .loading
        do {
            let provider = FallbackWeatherProvider(
                primary: WeatherKitProvider(),
                fallback: OpenMeteoWeatherProvider()
            )
            var assessments: [LocationAssessment] = []
            for location in locations {
                let forecast = try await provider.forecast(for: location)
                let assessment = calculator.assess(location: location, forecast: forecast)
                assessments.append(LocationAssessment(location: location, assessment: assessment))
            }
            state = .loaded(assessments.sorted { $0.assessment.level.sortOrder > $1.assessment.level.sortOrder })
            await notifications.refreshAuthorizationStatus()
            await notifications.scheduleAlerts(for: assessments)
        } catch {
            state = .failed(userFacingForecastError(error))
        }
    }

    func addLocation(name: String, crop: String, sensitivity: PlantSensitivity, searchResult: LocationSearchResult) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCrop = crop.trimmingCharacters(in: .whitespacesAndNewlines)
        locations.append(
            GrowingLocation(
                name: cleanName.isEmpty ? searchResult.name : cleanName,
                subtitle: searchResult.subtitle,
                crop: cleanCrop.isEmpty ? "Sensitive plants" : cleanCrop,
                sensitivity: sensitivity,
                coordinate: searchResult.coordinate
            )
        )
        saveLocations()
    }

    private func loadSavedLocations() -> [GrowingLocation] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([GrowingLocation].self, from: data)) ?? []
    }

    private func saveLocations() {
        guard let data = try? JSONEncoder().encode(locations) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func userFacingForecastError(_ error: Error) -> String {
        let message = error.localizedDescription
        if message.contains("WeatherDaemon") || message.contains("WDSJWTAuthenticator") {
            return "Apple Weather is not ready to provide forecasts yet. Try again in a few minutes."
        }
        return message
    }
}
