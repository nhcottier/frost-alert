import Foundation
import WidgetKit

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
    @Published private(set) var lastSuccessfulRefresh: Date?
    @Published private(set) var alertCoverageEnd: Date?

    let notifications = NotificationService()

    private let calculator = FrostRiskCalculator()
    private let storageKey = "savedGrowingLocations"
    private let notificationPromptKey = "didRequestNotificationPermission"

    init() {
        locations = loadSavedLocations()
        restoreForecastSnapshotMetadata()
    }

    func load(requestNotificationPermission: Bool = true) async {
        if requestNotificationPermission {
            await requestNotificationPermissionIfNeeded()
        } else {
            await notifications.refreshAuthorizationStatus()
        }

        guard !locations.isEmpty else {
            state = .empty
            clearForecastSnapshot()
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
            state = .loaded(assessments)
            saveForecastSnapshot(for: assessments, scheduledAssessments: scheduledAssessments)
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

    func moveLocation(id: UUID, offset: Int) {
        guard offset != 0,
              let currentIndex = locations.firstIndex(where: { $0.id == id })
        else { return }

        let newIndex = currentIndex + offset
        guard locations.indices.contains(newIndex) else { return }

        locations.swapAt(currentIndex, newIndex)
        if case .loaded(var assessments) = state,
           let currentAssessmentIndex = assessments.firstIndex(where: { $0.location.id == id }),
           assessments.indices.contains(currentAssessmentIndex + offset) {
            assessments.swapAt(currentAssessmentIndex, currentAssessmentIndex + offset)
            state = .loaded(assessments)
        }
        saveLocations()
    }

    func moveLocation(id: UUID, toTarget targetID: UUID) {
        guard id != targetID,
              let currentIndex = locations.firstIndex(where: { $0.id == id }),
              let targetIndex = locations.firstIndex(where: { $0.id == targetID })
        else { return }

        locations.moveItem(from: currentIndex, toTarget: targetIndex)
        if case .loaded(var assessments) = state,
           let currentAssessmentIndex = assessments.firstIndex(where: { $0.location.id == id }),
           let targetAssessmentIndex = assessments.firstIndex(where: { $0.location.id == targetID }) {
            assessments.moveItem(from: currentAssessmentIndex, toTarget: targetAssessmentIndex)
            state = .loaded(assessments)
        }
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

    private func restoreForecastSnapshotMetadata() {
        guard let snapshot = FrostWidgetStore.loadSnapshot(),
              snapshot.generatedAt != .distantPast else { return }
        lastSuccessfulRefresh = snapshot.generatedAt
        alertCoverageEnd = snapshot.coverageEnd
    }

    private func saveForecastSnapshot(for assessments: [LocationAssessment], scheduledAssessments: [ScheduledLocationAssessment]) {
        let generatedAt = Date()
        let coverageEnd = coverageEndDate(for: scheduledAssessments) ?? generatedAt
        lastSuccessfulRefresh = generatedAt
        alertCoverageEnd = coverageEnd

        let locations = assessments.map { assessment in
            FrostWidgetLocationSnapshot(
                id: assessment.location.id,
                name: assessment.location.name,
                crop: assessment.location.crop,
                risk: FrostWidgetRiskLevel(assessment.assessment.level),
                expectedLowCelsius: assessment.assessment.hasForecastData ? assessment.assessment.minimumTemperatureCelsius : nil,
                frostPeriod: frostPeriodText(for: assessment.assessment)
            )
        }
        let highestRisk = locations.map(\.risk).max { $0.sortOrder < $1.sortOrder } ?? .unavailable
        FrostWidgetStore.saveSnapshot(
            FrostWidgetSnapshot(
                generatedAt: generatedAt,
                coverageEnd: coverageEnd,
                highestRisk: highestRisk,
                locations: locations
            )
        )
        WidgetCenter.shared.reloadTimelines(ofKind: FrostWidgetStore.widgetKind)
    }

    private func clearForecastSnapshot() {
        lastSuccessfulRefresh = nil
        alertCoverageEnd = nil
        FrostWidgetStore.clearSnapshot()
        WidgetCenter.shared.reloadTimelines(ofKind: FrostWidgetStore.widgetKind)
    }

    private func coverageEndDate(for assessments: [ScheduledLocationAssessment]) -> Date? {
        guard let lastNight = assessments.map(\.nightStart).max() else { return nil }
        return Calendar.current.date(byAdding: .hour, value: 16, to: lastNight)
    }

    private func frostPeriodText(for assessment: FrostRiskAssessment) -> String {
        guard let start = assessment.likelyStart, let end = assessment.likelyEnd else {
            return "None"
        }
        return "\(start.formatted(date: .omitted, time: .shortened))-\(end.formatted(date: .omitted, time: .shortened))"
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
            guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let nightStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: targetDay)
            else { return nil }
            let assessmentStart = dayOffset == 0 ? now : nightStart
            let assessment = calculator.assess(location: location, forecast: forecast, now: assessmentStart)
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

private extension FrostWidgetRiskLevel {
    init(_ level: FrostRiskLevel) {
        switch level {
        case .safe: self = .safe
        case .watch: self = .watch
        case .frostLikely: self = .frostLikely
        case .severe: self = .severe
        }
    }
}

private extension Array {
    mutating func moveItem(from currentIndex: Index, toTarget targetIndex: Index) {
        guard currentIndex != targetIndex else { return }

        let item = remove(at: currentIndex)
        let insertionIndex = targetIndex > currentIndex ? targetIndex + 1 : targetIndex
        insert(item, at: Swift.min(insertionIndex, count))
    }
}
