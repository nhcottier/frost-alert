import Foundation
import UserNotifications

@MainActor
final class NotificationService: ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
        } catch {
            await refreshAuthorizationStatus()
        }
    }

    func scheduleAlerts(for assessments: [LocationAssessment]) async {
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: assessments.flatMap { assessment in
            ["evening-\(assessment.id.uuidString)", "morning-\(assessment.id.uuidString)"]
        })

        for assessment in assessments where assessment.assessment.level.sortOrder >= FrostRiskLevel.watch.sortOrder {
            await scheduleEveningWarning(for: assessment)
            if assessment.assessment.level.sortOrder >= FrostRiskLevel.frostLikely.sortOrder {
                await scheduleMorningWarning(for: assessment)
            }
        }
    }

    func cancelAlerts(for locationID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "evening-\(locationID.uuidString)",
            "morning-\(locationID.uuidString)"
        ])
    }

    private func scheduleEveningWarning(for assessment: LocationAssessment) async {
        let content = UNMutableNotificationContent()
        content.title = "\(assessment.location.name): \(assessment.assessment.level.rawValue)"
        content.body = assessment.assessment.summary
        content.sound = .default

        let components = notificationComponents(hour: 18, minute: 0, preferTomorrowIfPassed: true)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "evening-\(assessment.id.uuidString)", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func scheduleMorningWarning(for assessment: LocationAssessment) async {
        let content = UNMutableNotificationContent()
        content.title = "\(assessment.location.name): frost risk active"
        content.body = "Check protection before sunrise. Forecast low: \(assessment.assessment.minimumTemperatureCelsius.formatted(.number.precision(.fractionLength(0...1)))) C."
        content.sound = .default

        let components = notificationComponents(hour: 5, minute: 30, preferTomorrowIfPassed: true)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "morning-\(assessment.id.uuidString)", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func notificationComponents(hour: Int, minute: Int, preferTomorrowIfPassed: Bool) -> DateComponents {
        let calendar = Calendar.current
        let now = Date()
        var target = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        if preferTomorrowIfPassed, target <= now {
            target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
        }
        return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: target)
    }
}
