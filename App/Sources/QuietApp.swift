import SwiftUI
import SwiftData
import BackgroundTasks
import UserNotifications
import QuietCore

@main
@MainActor struct QuietApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var runtime: CreatureRuntime
    @State private var notificationRouter: NotificationRouter
    private nonisolated static let refreshID = "org.kamesan.shizukana-ai.refresh"

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Individual", isDirectory: true)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        let configuration = ModelConfiguration("individual", schema: Schema([StoredIndividual.self]),
            url: directory.appendingPathComponent("individual.store"), allowsSave: true,
            cloudKitDatabase: .none)
        let container = try! ModelContainer(for: StoredIndividual.self, configurations: configuration)
        let instance = CreatureRuntime(store: SwiftDataMemoryStore(container: container))
        let router = NotificationRouter()
        _runtime = State(initialValue: instance)
        _notificationRouter = State(initialValue: router)
        UNUserNotificationCenter.current().delegate = router
        instance.places.onVisit = { [weak instance] in
            Task { await instance?.wake(backgroundOnly: true) }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(runtime: runtime, notificationRouter: notificationRouter)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { runtime.deactivate() }
                }
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    await runtime.activate()
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
