import SwiftUI
import SwiftData
import BackgroundTasks
import UserNotifications
import QuietCore

@main
@MainActor struct QuietApp: App {
    @State private var runtime: CreatureRuntime
    @State private var notificationRouter = NotificationRouter()
    private nonisolated static let refreshID = "org.kamesan.shizukana-ai.refresh"

    init() {
        let container = try! ModelContainer(for: StoredIndividual.self)
        let instance = CreatureRuntime(store: SwiftDataMemoryStore(container: container))
        _runtime = State(initialValue: instance)
        UNUserNotificationCenter.current().delegate = notificationRouter
        instance.places.onVisit = { [weak instance] in
            Task { await instance?.wake(backgroundOnly: true) }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(runtime: runtime, notificationRouter: notificationRouter)
                .task {
                    await runtime.refresh()
                    await runtime.reconcileSources()
                    await runtime.bootstrap()
                    await runtime.reconcileNotifications()
                    await runtime.wake()
                    await Self.scheduleRefresh()
                }
        }
        .backgroundTask(.appRefresh(Self.refreshID)) {
            await runtime.wake(allowDream: false, backgroundOnly: true)
            await Self.scheduleRefresh()
        }
    }

    private nonisolated static func scheduleRefresh() async {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshID)
        request.earliestBeginDate = Date().addingTimeInterval(4 * 3600)
        try? await BGTaskScheduler.shared.submitTaskRequest(request)
    }
}
