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

    func scheduleAlerts(for assessments: [ScheduledLocationAssessment]) async {
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: assessments.flatMap { assessment in
            [
                "evening-\(assessment.id)",
                "morning-\(assessment.id)"
            ]
        })

        for assessment in assessments where assessment.assessment.level.sortOrder >= FrostRiskLevel.watch.sortOrder {
            await scheduleEveningWarning(for: assessment)
            if assessment.assessment.level.sortOrder >= FrostRiskLevel.frostLikely.sortOrder {
                await scheduleMorningWarning(for: assessment)
            }
        }
    }

    func cancelAlerts(for locationID: UUID) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.contains(locationID.uuidString) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    private func scheduleEveningWarning(for assessment: ScheduledLocationAssessment) async {
        guard let trigger = notificationTrigger(for: assessment.nightStart, hour: 18, minute: 0) else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(assessment.location.name): \(assessment.assessment.level.rawValue)"
        content.body = "Frost risk is possible \(nightLabel(for: assessment.nightStart)). \(assessment.assessment.summary)"
        content.sound = .default

        let request = UNNotificationRequest(identifier: "evening-\(assessment.id)", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func scheduleMorningWarning(for assessment: ScheduledLocationAssessment) async {
        guard let trigger = notificationTrigger(for: assessment.nightStart, dayOffset: 1, hour: 5, minute: 30) else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(assessment.location.name): frost risk active"
        content.body = "Check protection before sunrise. Forecast low: \(assessment.assessment.minimumTemperatureCelsius.formatted(.number.precision(.fractionLength(0...1)))) C."
        content.sound = .default

        let request = UNNotificationRequest(identifier: "morning-\(assessment.id)", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func notificationTrigger(for date: Date, dayOffset: Int = 0, hour: Int, minute: Int) -> UNCalendarNotificationTrigger? {
        let calendar = Calendar.current
        guard let day = calendar.date(byAdding: .day, value: dayOffset, to: date),
              let target = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
              target > Date()
        else { return nil }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: target)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    private func nightLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "tonight"
        }
        if Calendar.current.isDateInTomorrow(date) {
            return "tomorrow night"
        }
        return "in the next few nights"
    }
}
