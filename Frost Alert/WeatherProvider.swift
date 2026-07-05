import CoreLocation
import Foundation
import WeatherKit

protocol WeatherProviding {
    func forecast(for location: GrowingLocation) async throws -> LocationForecast
}

enum WeatherProviderError: LocalizedError {
    case unavailable
    case missingCoordinate
    case invalidResponse
    case noHourlyForecast

    var errorDescription: String? {
        switch self {
        case .unavailable: "Forecast data is temporarily unavailable."
        case .missingCoordinate: "This location needs coordinates before a forecast can be loaded."
        case .invalidResponse: "Forecast data could not be read."
        case .noHourlyForecast: "No hourly forecast is available for this location."
        }
    }
}

struct FallbackWeatherProvider: WeatherProviding {
    var primary: WeatherProviding
    var fallback: WeatherProviding

    func forecast(for location: GrowingLocation) async throws -> LocationForecast {
        do {
            return try await primary.forecast(for: location)
        } catch {
            return try await fallback.forecast(for: location)
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

struct OpenMeteoWeatherProvider: WeatherProviding {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func forecast(for location: GrowingLocation) async throws -> LocationForecast {
        guard let coordinate = location.coordinate else {
            throw WeatherProviderError.missingCoordinate
        }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "hourly", value: [
                "temperature_2m",
                "apparent_temperature",
                "relative_humidity_2m",
                "dew_point_2m",
                "wind_speed_10m",
                "cloud_cover",
                "precipitation_probability"
            ].joined(separator: ",")),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "4"),
            URLQueryItem(name: "timeformat", value: "unixtime")
        ]

        guard let url = components?.url else {
            throw WeatherProviderError.invalidResponse
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw WeatherProviderError.unavailable
        }

        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        let count = [
            decoded.hourly.time.count,
            decoded.hourly.temperature2m.count,
            decoded.hourly.apparentTemperature.count,
            decoded.hourly.relativeHumidity2m.count,
            decoded.hourly.dewPoint2m.count,
            decoded.hourly.windSpeed10m.count,
            decoded.hourly.cloudCover.count,
            decoded.hourly.precipitationProbability.count
        ].min() ?? 0

        let hours = (0..<count).map { index in
            HourlyForecast(
                date: Date(timeIntervalSince1970: TimeInterval(decoded.hourly.time[index])),
                temperatureCelsius: decoded.hourly.temperature2m[index],
                feelsLikeCelsius: decoded.hourly.apparentTemperature[index],
                humidity: decoded.hourly.relativeHumidity2m[index],
                dewPointCelsius: decoded.hourly.dewPoint2m[index],
                windKph: decoded.hourly.windSpeed10m[index],
                cloudCover: decoded.hourly.cloudCover[index],
                precipitationProbability: decoded.hourly.precipitationProbability[index]
            )
        }

        guard !hours.isEmpty else {
            throw WeatherProviderError.noHourlyForecast
        }

        return LocationForecast(locationID: location.id, generatedAt: Date(), hourly: hours)
    }
}

private struct OpenMeteoResponse: Decodable {
    var hourly: Hourly

    struct Hourly: Decodable {
        var time: [Int]
        var temperature2m: [Double]
        var apparentTemperature: [Double]
        var relativeHumidity2m: [Double]
        var dewPoint2m: [Double]
        var windSpeed10m: [Double]
        var cloudCover: [Double]
        var precipitationProbability: [Double]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case relativeHumidity2m = "relative_humidity_2m"
            case dewPoint2m = "dew_point_2m"
            case windSpeed10m = "wind_speed_10m"
            case cloudCover = "cloud_cover"
            case precipitationProbability = "precipitation_probability"
        }
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
