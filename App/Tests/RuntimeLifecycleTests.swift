import XCTest
import QuietCore
@testable import QuietApp

final class RuntimeLifecycleTests: XCTestCase {
    @MainActor private func noon() -> Date {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0,
                              of: Date(timeIntervalSince1970: 1_790_000_000))!
    }

    @MainActor private func seededStore(at date: Date) async throws -> InMemoryStore {
        let store = InMemoryStore()
        try await store.update {
            $0.budget = DailyBudget(day: BudgetPolicy.day(for: date), limit: 3)
            $0.fragments = [MemoryFragment(text: "昔の海", tags: ["海", "夏", "昼"],
                origin: .prenatal, bornAt: date.addingTimeInterval(-86400),
                provenance: [SourceRef(.photo, "synthetic-photo")])]
        }
        return store
    }

    @MainActor func testEraseDuringInferenceDoesNotRestoreTheIndividual() async throws {
        let now = noon()
        let store = try await seededStore(at: now)
        let model = SuspendedModel()
        let notifications = LifecycleNotifications()
        let runtime = CreatureRuntime(store: store, model: model, senses: [LifecycleSense()],
                                      notifications: notifications, clock: { now })
        let wake = Task { await runtime.wake(allowDream: false) }
        await model.waitUntilRequested()
        await runtime.erase()
        await model.finish()
        await wake.value

        let state = try await store.snapshot()
        XCTAssertTrue(state.fragments.isEmpty)
        XCTAssertTrue(state.observations.isEmpty)
        XCTAssertTrue(state.utterances.isEmpty)
        XCTAssertNil(state.budget)
        XCTAssertNil(state.dream)
        XCTAssertTrue(runtime.traces.isEmpty)
        XCTAssertTrue(notifications.scheduled.isEmpty)
    }

    @MainActor func testCancelledInferenceCannotSpeak() async throws {
        let now = noon()
        let store = try await seededStore(at: now)
        let model = SuspendedModel()
        let notifications = LifecycleNotifications()
        let runtime = CreatureRuntime(store: store, model: model, senses: [LifecycleSense()],
                                      notifications: notifications, clock: { now })
        let wake = Task { await runtime.wake(allowDream: false) }
        await model.waitUntilRequested()
        wake.cancel()
        await model.finish()
        await wake.value

        let state = try await store.snapshot()
        XCTAssertTrue(state.utterances.isEmpty)
        XCTAssertEqual(state.budget?.used, 0)
        XCTAssertTrue(notifications.scheduled.isEmpty)
    }

    @MainActor func testPurgeDuringInferenceRejectsStalePhotoContext() async throws {
        let now = noon()
        let store = try await seededStore(at: now)
        let model = SuspendedModel()
        let notifications = LifecycleNotifications()
        let runtime = CreatureRuntime(store: store, model: model, senses: [LifecycleSense()],
                                      notifications: notifications, clock: { now })
        let wake = Task { await runtime.wake(allowDream: false) }
        await model.waitUntilRequested()
        await runtime.purgeSources { $0.kind == .photo }
        await model.finish()
        await wake.value

        let state = try await store.snapshot()
        XCTAssertFalse(state.fragments.contains { $0.provenance.contains { $0.kind == .photo } })
        XCTAssertTrue(state.utterances.isEmpty)
        XCTAssertTrue(runtime.traces.isEmpty)
        XCTAssertTrue(notifications.scheduled.isEmpty)
    }

    @MainActor func testPersistenceFailureCannotScheduleAnUnrecordedUtterance() async throws {
        let now = noon()
        let store = RejectingSpeechStore(day: BudgetPolicy.day(for: now))
        let notifications = LifecycleNotifications()
        let runtime = CreatureRuntime(store: store, model: LifecycleModel(), senses: [LifecycleSense()],
                                      notifications: notifications, clock: { now })
        await runtime.wake(allowDream: false)
        let state = try await store.snapshot()
        XCTAssertTrue(state.utterances.isEmpty)
        XCTAssertEqual(state.budget?.used, 0)
        XCTAssertTrue(notifications.scheduled.isEmpty)
    }

    @MainActor func testDreamReconciliationUsesClockAndRecordsOnce() async throws {
        let now = noon()
        let clock = LifecycleClock(now)
        let store = InMemoryStore()
        let notifications = LifecycleNotifications()
        let delivery = now.addingTimeInterval(3600)
        let utterance = Utterance(text: "海、また", createdAt: delivery, sourceIDs: [])
        try await store.update { $0.dream = DreamUtterance(utterance: utterance, scheduledAt: delivery) }
        let runtime = CreatureRuntime(store: store, notifications: notifications, clock: { clock.date })

        await runtime.reconcileNotifications()
        XCTAssertEqual(notifications.scheduled.count, 1)
        clock.date = delivery.addingTimeInterval(1)
        async let first: Void = runtime.reconcileNotifications()
        async let second: Void = runtime.reconcileNotifications()
        _ = await (first, second)
        await runtime.reconcileNotifications()

        let state = try await store.snapshot()
        XCTAssertEqual(state.utterances.map(\.id), [utterance.id])
        XCTAssertNil(state.dream)
        XCTAssertTrue(notifications.pending.isEmpty)
    }

    @MainActor func testOrphanDreamReservationIsRemoved() async {
        let notifications = LifecycleNotifications()
        notifications.pending = ["quiet-ai-dream"]
        let runtime = CreatureRuntime(store: InMemoryStore(), notifications: notifications)
        await runtime.reconcileNotifications()
        XCTAssertTrue(notifications.pending.isEmpty)
    }

    @MainActor func testChangedQuietHoursCancelExistingDream() async throws {
        let now = noon()
        let store = InMemoryStore()
        let notifications = LifecycleNotifications()
        let delivery = Calendar.current.date(bySettingHour: 23, minute: 30, second: 0, of: now)!
        let utterance = Utterance(text: "海、また", createdAt: delivery, sourceIDs: [])
        try await store.update { $0.dream = DreamUtterance(utterance: utterance, scheduledAt: delivery) }
        notifications.pending = ["quiet-ai-dream"]
        let runtime = CreatureRuntime(store: store, notifications: notifications, clock: { now })
        runtime.quietStart = 23; runtime.quietEnd = 7
        await runtime.reconcileNotifications()
        let state = try await store.snapshot()
        XCTAssertNil(state.dream)
        XCTAssertTrue(notifications.pending.isEmpty)
        XCTAssertTrue(notifications.scheduled.isEmpty)
    }

    @MainActor func testRepeatedForegroundOpportunitiesGatherFreshObservations() async throws {
        let now = noon()
        let clock = LifecycleClock(now)
        let store = InMemoryStore()
        let runtime = CreatureRuntime(store: store, model: LifecycleSilentModel(),
                                      senses: [LifecycleSense()], notifications: LifecycleNotifications(),
                                      clock: { clock.date })
        await runtime.activate()
        clock.date = now.addingTimeInterval(4 * 3600)
        await runtime.activate()
        let state = try await store.snapshot()
        XCTAssertEqual(state.observations.map(\.observedAt), [now, clock.date])
    }
    @MainActor func testPurgeCancelsPendingAwakeNotification() async throws {
        let now = noon()
        let store = try await seededStore(at: now)
        let source = try await store.snapshot().fragments[0].id
        let utterance = Utterance(text: "海、まだ", createdAt: now, sourceIDs: [source])
        try await store.update { $0.utterances = [utterance] }
        let notifications = LifecycleNotifications()
        notifications.pending = [utterance.id.uuidString]
        let runtime = CreatureRuntime(store: store, notifications: notifications, clock: { now })
        await runtime.purgeSources { $0.kind == .photo }
        let state = try await store.snapshot()
        XCTAssertTrue(notifications.pending.isEmpty)
        XCTAssertEqual(state.utterances.first?.text, utterance.text)
        XCTAssertTrue(state.utterances.first?.sourceIDs.isEmpty == true)
    }

    @MainActor func testKnownSourcesDoNotStarveNewPhotosOrDuplicateAcrossDays() async throws {
        let now = noon()
        let clock = LifecycleClock(now)
        let store = InMemoryStore()
        let runtime = CreatureRuntime(store: store, model: LifecycleSilentModel(),
                                      senses: [DailyPhotoFixture()], notifications: LifecycleNotifications(),
                                      clock: { clock.date })
        await runtime.wake(allowDream: false)
        await runtime.wake(allowDream: false)
        clock.date = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        await runtime.wake(allowDream: false)
        let state = try await store.snapshot()
        let photos = state.fragments.filter { $0.provenance.contains { $0.kind == .photo } }
        XCTAssertEqual(photos.count, 4)
        XCTAssertEqual(Set(photos.flatMap(\.provenance).map(\.id)), Set((0..<4).map { "photo-\($0)" }))
        XCTAssertLessThanOrEqual(state.fragments.filter { BudgetPolicy.day(for: $0.bornAt) == BudgetPolicy.day(for: now) }.count, 4)
    }

    @MainActor func testPurgeCleansUpNotificationThatFinishesSchedulingLate() async throws {
        let now = noon()
        let store = try await seededStore(at: now)
        let memoryID = try await store.snapshot().fragments[0].id
        let delivery = now.addingTimeInterval(3600)
        let utterance = Utterance(text: "海、まだ", createdAt: delivery, sourceIDs: [memoryID])
        try await store.update { $0.dream = DreamUtterance(utterance: utterance, scheduledAt: delivery) }
        let notifications = SuspendedNotifications()
        let runtime = CreatureRuntime(store: store, notifications: notifications, clock: { now })
        let reconciliation = Task { await runtime.reconcileNotifications() }
        await notifications.waitUntilScheduling()
        await runtime.purgeSources { $0.kind == .photo }
        notifications.finishScheduling()
        await reconciliation.value
        let state = try await store.snapshot()
        XCTAssertNil(state.dream)
        XCTAssertTrue(notifications.pending.isEmpty)
    }

    @MainActor func testDeactivationCancelsSuspendedForegroundCognition() async throws {
        let now = noon()
        let store = InMemoryStore()
        try await store.update { $0.budget = DailyBudget(day: BudgetPolicy.day(for: now), limit: 3) }
        let model = SuspendedModel()
        let notifications = LifecycleNotifications()
        let runtime = CreatureRuntime(store: store, model: model, senses: [LifecycleSense()],
                                      notifications: notifications, clock: { now })
        let activation = Task { await runtime.activate() }
        await model.waitUntilRequested()
        // A second activation queues while the first is suspended, then is withdrawn.
        await runtime.activate()
        runtime.deactivate()
        await model.finish()
        await activation.value
        let state = try await store.snapshot()
        XCTAssertTrue(state.utterances.isEmpty)
        XCTAssertTrue(notifications.scheduled.isEmpty)
        XCTAssertEqual(state.observations.count, 1)
    }

    @MainActor func testResetDuringBackgroundReconciliationCannotRecreateMemory() async throws {
        let now = noon()
        let store = SnapshotBarrierStore()
        let runtime = CreatureRuntime(store: store, model: LifecycleSilentModel(),
                                      senses: [LifecycleSense()], notifications: LifecycleNotifications(),
                                      clock: { now })
        let wake = Task { await runtime.wake(backgroundOnly: true) }
        await store.waitUntilSnapshot()
        let erased = await runtime.erase()
        XCTAssertTrue(erased)
        await store.releaseSnapshot()
        await wake.value
        let state = try await store.snapshot()
        XCTAssertTrue(state.observations.isEmpty)
        XCTAssertTrue(state.fragments.isEmpty)
        XCTAssertNil(state.budget)
    }

    @MainActor func testDeactivationDuringInitialReconciliationStopsForegroundWork() async throws {
        let now = noon()
        let store = SnapshotBarrierStore()
        let runtime = CreatureRuntime(store: store, model: LifecycleSilentModel(),
                                      senses: [LifecycleSense()], notifications: LifecycleNotifications(),
                                      clock: { now })
        let activation = Task { await runtime.activate() }
        await store.waitUntilSnapshot()
        runtime.deactivate()
        await store.releaseSnapshot()
        await activation.value
        let state = try await store.snapshot()
        XCTAssertTrue(state.observations.isEmpty)
        XCTAssertTrue(state.fragments.isEmpty)
    }

}

@MainActor private final class LifecycleClock {
    var date: Date
    init(_ date: Date) { self.date = date }
}

private struct LifecycleSense: SenseSource {
    let kind: SenseKind = .time
    func observe(at date: Date) async -> [SenseObservation] {
        [SenseObservation(source: SourceRef(.time, BudgetPolicy.day(for: date)), observedAt: date,
                          text: "夏の昼", tags: ["海", "夏", "昼"])]
    }
}

private struct LifecycleModel: LanguageModelAdapter {
    var available: Bool { get async { true } }
    func respond(to prompt: String) async throws -> String { "海、まだあった" }
}

private struct LifecycleSilentModel: LanguageModelAdapter {
    var available: Bool { get async { false } }
    func respond(to prompt: String) async throws -> String { XCTFail("Unavailable model"); return "SILENCE" }
}

private actor SuspendedModel: LanguageModelAdapter {
    private var response: CheckedContinuation<String, Never>?
    private var requestWaiter: CheckedContinuation<Void, Never>?
    var available: Bool { get async { true } }
    func respond(to prompt: String) async throws -> String {
        await withCheckedContinuation { continuation in
            response = continuation
            requestWaiter?.resume()
            requestWaiter = nil
        }
    }
    func waitUntilRequested() async {
        if response != nil { return }
        await withCheckedContinuation { requestWaiter = $0 }
    }
    func finish() {
        response?.resume(returning: "海、まだあった")
        response = nil
    }
}

@MainActor private final class LifecycleNotifications: NotificationScheduling {
    var scheduled: [Utterance] = []
    var pending: Set<String> = []
    func schedule(_ utterance: Utterance, at date: Date, identifier: String) async {
        scheduled.append(utterance)
        pending.insert(identifier)
    }
    func pendingIDs() async -> Set<String> { pending }
    func removePending(_ identifiers: [String]) { pending.subtract(identifiers) }
    func removeAll() { pending.removeAll(); scheduled.removeAll() }
}

private actor RejectingSpeechStore: MemoryStore {
    private var state: MemorySnapshot
    init(day: String) {
        var initial = MemorySnapshot()
        initial.budget = DailyBudget(day: day, limit: 3)
        state = initial
    }
    func snapshot() -> MemorySnapshot { state }
    func update(_ body: @Sendable (inout MemorySnapshot) -> Void) throws {
        var draft = state
        body(&draft)
        if !draft.utterances.isEmpty || draft.dream != nil { throw CocoaError(.fileWriteUnknown) }
        state = draft
    }
    func reset() { state = MemorySnapshot() }
}

private struct DailyPhotoFixture: SenseSource {
    let kind: SenseKind = .photo
    func observe(at date: Date) async -> [SenseObservation] {
        [SenseObservation(source: SourceRef(.time, BudgetPolicy.day(for: date)), observedAt: date,
                          text: "昼", tags: ["昼", "時刻", "夏"])] + (0..<4).map {
            SenseObservation(source: SourceRef(.photo, "photo-\($0)"), observedAt: date,
                             text: "海の写真", tags: ["海", "空", "水"])
        }
    }
}

@MainActor private final class SuspendedNotifications: NotificationScheduling {
    var pending: Set<String> = []
    private var scheduling: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?
    func schedule(_ utterance: Utterance, at date: Date, identifier: String) async {
        await withCheckedContinuation { continuation in
            scheduling = continuation
            started?.resume()
            started = nil
        }
        pending.insert(identifier)
    }
    func waitUntilScheduling() async {
        if scheduling != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func finishScheduling() { scheduling?.resume(); scheduling = nil }
    func pendingIDs() async -> Set<String> { pending }
    func removePending(_ identifiers: [String]) { pending.subtract(identifiers) }
    func removeAll() { pending.removeAll() }
}

private actor SnapshotBarrierStore: MemoryStore {
    private var state = MemorySnapshot()
    private var pauseNextSnapshot = true
    private var snapshotContinuation: CheckedContinuation<Void, Never>?
    private var enteredContinuation: CheckedContinuation<Void, Never>?
    func snapshot() async -> MemorySnapshot {
        if pauseNextSnapshot {
            pauseNextSnapshot = false
            await withCheckedContinuation { continuation in
                snapshotContinuation = continuation
                enteredContinuation?.resume()
                enteredContinuation = nil
            }
        }
        return state
    }
    func waitUntilSnapshot() async {
        if snapshotContinuation != nil { return }
        await withCheckedContinuation { enteredContinuation = $0 }
    }
    func releaseSnapshot() { snapshotContinuation?.resume(); snapshotContinuation = nil }
    func update(_ body: @Sendable (inout MemorySnapshot) -> Void) { body(&state) }
    func reset() { state = MemorySnapshot() }
}
