import SwiftUI
import SwiftData
import BackgroundTasks
import UserNotifications
import QuietCore

@main
@MainActor struct QuietApp: App {
    @State private var runtime: CreatureRuntime
    private static let refreshID = "org.kamesan.shizukana-ai.refresh"

    init() {
        let container = try! ModelContainer(for: StoredIndividual.self)
        let instance = CreatureRuntime(store: SwiftDataMemoryStore(container: container))
        _runtime = State(initialValue: instance)
        instance.places.onVisit = { [weak instance] in
            Task { await instance?.wake() }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(runtime: runtime)
                .task {
                    await runtime.refresh()
                    await runtime.reconcileSources()
                    await runtime.reconcileNotifications()
                    await runtime.wake()
                    scheduleRefresh()
                }
        }
        .backgroundTask(.appRefresh(Self.refreshID)) {
            await runtime.wake(allowDream: false)
            scheduleRefresh()
        }
    }

    private func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshID)
        request.earliestBeginDate = Date().addingTimeInterval(4 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }
}
