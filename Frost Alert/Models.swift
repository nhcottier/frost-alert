import CoreLocation
import Foundation

struct GrowingLocation: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var subtitle: String
    var crop: String
    var sensitivity: PlantSensitivity
    var coordinate: LocationCoordinate?

    init(id: UUID = UUID(), name: String, subtitle: String, crop: String, sensitivity: PlantSensitivity, coordinate: LocationCoordinate? = nil) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.crop = crop
        self.sensitivity = sensitivity
        self.coordinate = coordinate
    }
}

struct LocationCoordinate: Codable, Equatable {
    var latitude: Double
    var longitude: Double

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

enum PlantSensitivity: Codable, Equatable {
    case hardy
    case sensitive
    case verySensitive
    case custom(Double)

    var name: String {
        switch self {
        case .hardy: "Hardy"
        case .sensitive: "Sensitive"
        case .verySensitive: "Very sensitive"
        case .custom: "Custom threshold"
        }
    }

    var thresholdCelsius: Double {
        switch self {
        case .hardy: -2
        case .sensitive: 1
        case .verySensitive: 3
        case .custom(let threshold): threshold
        }
    }
}

struct HourlyForecast: Identifiable, Equatable {
    let id = UUID()
    var date: Date
    var temperatureCelsius: Double
    var feelsLikeCelsius: Double?
    var humidity: Double
    var dewPointCelsius: Double?
    var windKph: Double
    var cloudCover: Double
    var precipitationProbability: Double
}

struct LocationForecast: Equatable {
    var locationID: UUID
    var generatedAt: Date
    var hourly: [HourlyForecast]
}

enum FrostRiskLevel: String, CaseIterable {
    case safe = "Safe"
    case watch = "Watch"
    case frostLikely = "Frost likely"
    case severe = "Severe frost risk"

    var sortOrder: Int {
        switch self {
        case .safe: 0
        case .watch: 1
        case .frostLikely: 2
        case .severe: 3
        }
    }
}

struct FrostRiskAssessment: Equatable {
    var level: FrostRiskLevel
    var score: Int
    var minimumTemperatureCelsius: Double
    var likelyStart: Date?
    var likelyEnd: Date?
    var summary: String
    var drivers: [String]
    var actions: [String]
    var hasForecastData: Bool = true
}

struct LocationAssessment: Identifiable, Equatable {
    var id: UUID { location.id }
    var location: GrowingLocation
    var assessment: FrostRiskAssessment
    var outlook: [ScheduledLocationAssessment] = []
}

struct ScheduledLocationAssessment: Identifiable, Equatable {
    var id: String {
        "\(location.id.uuidString)-\(nightStart.timeIntervalSince1970)"
    }

    var location: GrowingLocation
    var assessment: FrostRiskAssessment
    var nightStart: Date
}
