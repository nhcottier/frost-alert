import Foundation

enum DashboardState: Equatable {
    case loading
    case empty
    case loaded([LocationAssessment])
    case failed(String)
}

@MainActor
final class AppModel: ObservableObject {
    @Published var locations: [GrowingLocation] = [
        GrowingLocation(name: "North Block Vineyard", subtitle: "Lower terrace", crop: "Pinot noir vines", sensitivity: .sensitive),
        GrowingLocation(name: "Kitchen Garden", subtitle: "Raised beds", crop: "Seedlings and tomatoes", sensitivity: .verySensitive),
        GrowingLocation(name: "Glasshouse Bench", subtitle: "Propagation area", crop: "Citrus and chillies", sensitivity: .custom(2))
    ]
    @Published private(set) var state: DashboardState = .loading

    let notifications = NotificationService()

    private let calculator = FrostRiskCalculator()

    func load() async {
        guard !locations.isEmpty else {
            state = .empty
            return
        }

        state = .loading
        do {
            let provider = MockWeatherProvider()
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
            state = .failed(error.localizedDescription)
        }
    }

    func addLocation(name: String, crop: String, sensitivity: PlantSensitivity) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCrop = crop.trimmingCharacters(in: .whitespacesAndNewlines)
        locations.append(
            GrowingLocation(
                name: cleanName.isEmpty ? "New growing area" : cleanName,
                subtitle: "Custom location",
                crop: cleanCrop.isEmpty ? "Sensitive plants" : cleanCrop,
                sensitivity: sensitivity
            )
        )
    }
}
