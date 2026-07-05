import XCTest
@testable import Frost_Alert

final class FrostRiskCalculatorTests: XCTestCase {
    func testSevereRiskWhenVeryColdClearCalmAndHumid() {
        let location = GrowingLocation(name: "Test Vineyard", subtitle: "Block A", crop: "Grapes", sensitivity: .sensitive)
        let forecast = forecast(locationID: location.id, low: -3, wind: 2, cloud: 8, humidity: 94)

        let assessment = FrostRiskCalculator().assess(location: location, forecast: forecast, now: Date.fixedNoon)

        XCTAssertEqual(assessment.level, .severe)
        XCTAssertNotNil(assessment.likelyStart)
        XCTAssertTrue(assessment.actions.contains { $0.localizedCaseInsensitiveContains("Protect") })
    }

    func testWatchRiskWhenLowIsNearThreshold() {
        let location = GrowingLocation(name: "Kitchen Garden", subtitle: "Beds", crop: "Tomatoes", sensitivity: .verySensitive)
        let forecast = forecast(locationID: location.id, low: 4, wind: 14, cloud: 70, humidity: 70)

        let assessment = FrostRiskCalculator().assess(location: location, forecast: forecast, now: Date.fixedNoon)

        XCTAssertEqual(assessment.level, .watch)
        XCTAssertTrue(assessment.minimumTemperatureCelsius <= 4)
    }

    func testSafeRiskWhenWarmCloudyAndWindy() {
        let location = GrowingLocation(name: "Orchard", subtitle: "Upper block", crop: "Citrus", sensitivity: .sensitive)
        let forecast = forecast(locationID: location.id, low: 8, wind: 20, cloud: 95, humidity: 60)

        let assessment = FrostRiskCalculator().assess(location: location, forecast: forecast, now: Date.fixedNoon)

        XCTAssertEqual(assessment.level, .safe)
        XCTAssertNil(assessment.likelyStart)
    }

    private func forecast(locationID: UUID, low: Double, wind: Double, cloud: Double, humidity: Double) -> LocationForecast {
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Date.fixedNoon)!
        let hours = (0..<14).map { offset in
            let date = calendar.date(byAdding: .hour, value: offset, to: start)!
            let curve = abs(Double(offset) - 10) / 10
            let temperature = low + curve * 3
            return HourlyForecast(
                date: date,
                temperatureCelsius: temperature,
                feelsLikeCelsius: temperature - 0.2,
                humidity: humidity,
                dewPointCelsius: temperature - 1,
                windKph: wind,
                cloudCover: cloud,
                precipitationProbability: 10
            )
        }
        return LocationForecast(locationID: locationID, generatedAt: Date.fixedNoon, hourly: hours)
    }
}

private extension Date {
    static var fixedNoon: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 6
        components.hour = 12
        return Calendar.current.date(from: components)!
    }
}
