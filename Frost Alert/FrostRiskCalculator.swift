import Foundation

struct FrostRiskCalculator {
    func assess(location: GrowingLocation, forecast: LocationForecast, now: Date = Date()) -> FrostRiskAssessment {
        let hours = overnightHours(from: forecast.hourly, now: now)
        let relevantHours = hours.isEmpty ? forecast.hourly : hours
        guard !relevantHours.isEmpty else {
            return FrostRiskAssessment(
                level: .safe,
                score: 0,
                minimumTemperatureCelsius: 0,
                likelyStart: nil,
                likelyEnd: nil,
                summary: "No overnight forecast is available yet.",
                drivers: ["Forecast data unavailable"],
                actions: ["Check again later before making frost-protection decisions."]
            )
        }

        let threshold = location.sensitivity.thresholdCelsius
        let minimumHour = relevantHours.min { effectiveTemperature($0) < effectiveTemperature($1) }!
        let minimumTemperature = effectiveTemperature(minimumHour)
        let riskyHours = relevantHours.filter { hour in
            let temperatureRisk = effectiveTemperature(hour) <= threshold + 1.5
            let frostWeather = hour.windKph <= 12 && hour.cloudCover <= 65
            return temperatureRisk && frostWeather
        }

        var score = 0
        if minimumTemperature <= threshold - 2 { score += 45 }
        else if minimumTemperature <= threshold { score += 34 }
        else if minimumTemperature <= threshold + 2 { score += 22 }
        else if minimumTemperature <= threshold + 4 { score += 10 }

        let calmHours = relevantHours.filter { $0.windKph <= 8 }.count
        let clearHours = relevantHours.filter { $0.cloudCover <= 35 }.count
        let humidHours = relevantHours.filter { $0.humidity >= 82 || dewSpread($0) <= 2.5 }.count
        let dryPrecipHours = relevantHours.filter { $0.precipitationProbability <= 30 }.count

        score += min(18, calmHours * 3)
        score += min(14, clearHours * 2)
        score += min(12, humidHours * 2)
        score += min(8, dryPrecipHours)
        if !riskyHours.isEmpty { score += 12 }
        score = min(score, 100)
        if riskyHours.isEmpty {
            score = min(score, 49)
        }

        let level: FrostRiskLevel
        switch score {
        case 0..<26: level = .safe
        case 26..<50: level = .watch
        case 50..<75: level = .frostLikely
        default: level = .severe
        }

        return FrostRiskAssessment(
            level: level,
            score: score,
            minimumTemperatureCelsius: minimumTemperature,
            likelyStart: riskyHours.first?.date,
            likelyEnd: riskyHours.last?.date,
            summary: summary(for: level, location: location, minimumTemperature: minimumTemperature, threshold: threshold),
            drivers: drivers(for: relevantHours, minimumTemperature: minimumTemperature, threshold: threshold),
            actions: actions(for: level, sensitivity: location.sensitivity)
        )
    }

    private func overnightHours(from hourly: [HourlyForecast], now: Date) -> [HourlyForecast] {
        let calendar = Calendar.current
        return hourly.filter { hour in
            guard hour.date >= now else { return false }
            let hourOfDay = calendar.component(.hour, from: hour.date)
            return hourOfDay >= 18 || hourOfDay <= 9
        }
        .prefix(18)
        .map { $0 }
    }

    private func effectiveTemperature(_ hour: HourlyForecast) -> Double {
        min(hour.temperatureCelsius, hour.feelsLikeCelsius ?? hour.temperatureCelsius)
    }

    private func dewSpread(_ hour: HourlyForecast) -> Double {
        guard let dewPoint = hour.dewPointCelsius else { return 100 }
        return hour.temperatureCelsius - dewPoint
    }

    private func summary(for level: FrostRiskLevel, location: GrowingLocation, minimumTemperature: Double, threshold: Double) -> String {
        let low = minimumTemperature.formatted(.number.precision(.fractionLength(0...1)))
        let thresholdText = threshold.formatted(.number.precision(.fractionLength(0...1)))
        switch level {
        case .safe:
            return "Frost is not forecast for \(location.crop.lowercased()). The expected low is \(low) C, above your \(thresholdText) C threshold."
        case .watch:
            return "Frost is not forecast, but conditions may become marginal. The expected low is \(low) C, near your \(thresholdText) C threshold."
        case .frostLikely:
            return "Frost is forecast overnight. Protect \(location.crop.lowercased()) before temperatures reach the expected low of \(low) C."
        case .severe:
            return "Severe frost risk is forecast. Damaging conditions are possible near \(low) C unless protection is in place."
        }
    }

    private func drivers(for hours: [HourlyForecast], minimumTemperature: Double, threshold: Double) -> [String] {
        var drivers: [String] = []
        if minimumTemperature <= threshold {
            drivers.append("Forecast low is at or below your plant threshold")
        } else if minimumTemperature <= threshold + 2 {
            drivers.append("Forecast low is close to your plant threshold")
        }
        if hours.contains(where: { $0.windKph <= 8 }) {
            drivers.append("Light wind may allow cold air to settle")
        }
        if hours.contains(where: { $0.cloudCover <= 35 }) {
            drivers.append("Clear sky increases overnight cooling")
        }
        if hours.contains(where: { $0.humidity >= 82 || dewSpread($0) <= 2.5 }) {
            drivers.append("Moist air may support frost formation")
        }
        return drivers.isEmpty ? ["No strong frost-forming signals in the overnight forecast period"] : drivers
    }

    private func actions(for level: FrostRiskLevel, sensitivity: PlantSensitivity) -> [String] {
        switch level {
        case .safe:
            return ["No frost protection is needed for the current forecast.", "Check again if the forecast changes."]
        case .watch:
            return ["Check frost-sensitive plants such as seedlings, citrus, tomatoes, chillies, and young vines.", "Prepare frost cloth or covers before evening if conditions cool further."]
        case .frostLikely:
            return ["Cover sensitive plants before evening temperatures drop.", "Move pots inside or under shelter.", "Check irrigation, frost cloth, or frost fans."]
        case .severe:
            return ["Protect seedlings and high-value crops now.", "Use frost cloth, irrigation, heaters, or fans where appropriate.", "Use local sensors or professional frost systems for high-value crops."]
        }
    }
}
