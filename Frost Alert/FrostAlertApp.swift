import BackgroundTasks
import SwiftUI

@main
struct FrostAlertApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appModel = AppModel()

    private let refreshTaskIdentifier = "com.nickcottier.frostalert.refresh"

    init() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.nickcottier.frostalert.refresh", using: nil) { task in
            handleAppRefresh(task: task)
        }
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(appModel)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .background else { return }
            scheduleAppRefresh()
        }
    }

    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

private func handleAppRefresh(task: BGTask) {
    scheduleNextAppRefresh()

    let refreshTask = Task { @MainActor in
        let model = AppModel()
        await model.load(requestNotificationPermission: false)
        task.setTaskCompleted(success: true)
    }

    task.expirationHandler = {
        refreshTask.cancel()
        task.setTaskCompleted(success: false)
    }
}

private func scheduleNextAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.nickcottier.frostalert.refresh")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)
    try? BGTaskScheduler.shared.submit(request)
}
