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
    private let notificationPromptKey = "didRequestNotificationPermission"

    init() {
        locations = loadSavedLocations()
    }

    func load(requestNotificationPermission: Bool = true) async {
        if requestNotificationPermission {
            await requestNotificationPermissionIfNeeded()
        } else {
            await notifications.refreshAuthorizationStatus()
        }

        guard !locations.isEmpty else {
            state = .empty
            return
        }

        state = .loading
        do {
            let provider = WeatherKitProvider()
            var assessments: [LocationAssessment] = []
            var scheduledAssessments: [ScheduledLocationAssessment] = []
            for location in locations {
                let forecast = try await provider.forecast(for: location)
                let assessment = calculator.assess(location: location, forecast: forecast)
                let outlook = alertAssessments(location: location, forecast: forecast)
                assessments.append(LocationAssessment(location: location, assessment: assessment, outlook: outlook))
                scheduledAssessments.append(contentsOf: outlook)
            }
            state = .loaded(assessments.sorted { $0.assessment.level.sortOrder > $1.assessment.level.sortOrder })
            await notifications.refreshAuthorizationStatus()
            await notifications.scheduleAlerts(for: scheduledAssessments)
        } catch {
            state = .failed(userFacingForecastError(error))
        }
    }

    func requestNotificationPermission() async {
        await notifications.requestPermission()
        await scheduleNotificationsIfLoaded()
    }

    func refreshNotificationPermission() async {
        await notifications.refreshAuthorizationStatus()
        await scheduleNotificationsIfLoaded()
    }

    private func scheduleNotificationsIfLoaded() async {
        guard case .loaded(let assessments) = state else { return }
        await notifications.scheduleAlerts(for: assessments.flatMap(\.outlook))
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

    func updateLocation(id: UUID, name: String, crop: String, sensitivity: PlantSensitivity, searchResult: LocationSearchResult) {
        guard let index = locations.firstIndex(where: { $0.id == id }) else { return }

        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCrop = crop.trimmingCharacters(in: .whitespacesAndNewlines)
        locations[index].name = cleanName.isEmpty ? searchResult.name : cleanName
        locations[index].subtitle = searchResult.subtitle
        locations[index].crop = cleanCrop.isEmpty ? "Sensitive plants" : cleanCrop
        locations[index].sensitivity = sensitivity
        locations[index].coordinate = searchResult.coordinate
        saveLocations()
    }

    func deleteLocation(id: UUID) {
        locations.removeAll { $0.id == id }
        notifications.cancelAlerts(for: id)
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

    private func requestNotificationPermissionIfNeeded() async {
        await notifications.refreshAuthorizationStatus()
        guard notifications.authorizationStatus == .notDetermined else { return }
        guard !UserDefaults.standard.bool(forKey: notificationPromptKey) else { return }

        UserDefaults.standard.set(true, forKey: notificationPromptKey)
        await requestNotificationPermission()
    }

    private func alertAssessments(location: GrowingLocation, forecast: LocationForecast) -> [ScheduledLocationAssessment] {
        let calendar = Calendar.current
        let now = Date()

        return (0..<3).compactMap { dayOffset in
            guard let nightStart = calendar.date(byAdding: .day, value: dayOffset, to: now) else { return nil }
            let assessment = calculator.assess(location: location, forecast: forecast, now: nightStart)
            return ScheduledLocationAssessment(location: location, assessment: assessment, nightStart: nightStart)
        }
    }

    private func userFacingForecastError(_ error: Error) -> String {
        let message = error.localizedDescription
        if message.contains("WeatherDaemon") || message.contains("WDSJWTAuthenticator") {
            return "Apple Weather is not ready to provide forecasts yet. Try again in a few minutes."
        }
        return message
    }
}
