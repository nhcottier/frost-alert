import CoreLocation
import Foundation
import WeatherKit

protocol WeatherProviding {
    func forecast(for location: GrowingLocation) async throws -> LocationForecast
}

enum WeatherProviderError: LocalizedError {
    case unavailable
    case missingCoordinate

    var errorDescription: String? {
        switch self {
        case .unavailable: "Forecast data is temporarily unavailable."
        case .missingCoordinate: "This location needs coordinates before a forecast can be loaded."
        }
    }
}

struct WeatherKitProvider: WeatherProviding {
    private let service = WeatherService.shared

    func forecast(for location: GrowingLocation) async throws -> LocationForecast {
        guard let coordinate = location.coordinate else {
            throw WeatherProviderError.missingCoordinate
        }

        let hourly = try await service.weather(for: coordinate.clLocation, including: .hourly)
        let convertedHours = hourly.forecast.map { hour in
            HourlyForecast(
                date: hour.date,
                temperatureCelsius: hour.temperature.converted(to: .celsius).value,
                feelsLikeCelsius: hour.apparentTemperature.converted(to: .celsius).value,
                humidity: hour.humidity * 100,
                dewPointCelsius: hour.dewPoint.converted(to: .celsius).value,
                windKph: hour.wind.speed.converted(to: .kilometersPerHour).value,
                cloudCover: hour.cloudCover * 100,
                precipitationProbability: hour.precipitationChance * 100
            )
        }

        return LocationForecast(locationID: location.id, generatedAt: Date(), hourly: convertedHours)
    }
}

struct MockWeatherProvider: WeatherProviding {
    var scenario: Scenario = .mixed

    enum Scenario {
        case mixed
        case error
    }

    func forecast(for location: GrowingLocation) async throws -> LocationForecast {
        try await Task.sleep(for: .milliseconds(450))
        if scenario == .error {
            throw WeatherProviderError.unavailable
        }

        let now = Date()
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now
        let base = location.name.contains("Vineyard") ? -1.5 : location.name.contains("Glasshouse") ? 2.4 : 0.4

        let hours = (0..<18).compactMap { offset -> HourlyForecast? in
            guard let date = calendar.date(byAdding: .hour, value: offset, to: start) else { return nil }
            let hour = calendar.component(.hour, from: date)
            let coldCurve = cos(Double(offset - 11) / 11.0 * .pi)
            let temperature = base + coldCurve * 3.1 + (hour < 6 ? -0.6 : 0.4)
            let wind = max(1.5, 9 - Double(offset) * 0.35)
            let cloud = max(8, 58 - Double(offset) * 3.2)
            return HourlyForecast(
                date: date,
                temperatureCelsius: temperature,
                feelsLikeCelsius: temperature - (wind < 5 ? 0.4 : 0),
                humidity: min(96, 72 + Double(offset) * 1.4),
                dewPointCelsius: temperature - 1.8,
                windKph: wind,
                cloudCover: cloud,
                precipitationProbability: 8
            )
        }

        return LocationForecast(locationID: location.id, generatedAt: now, hourly: hours)
    }
}
