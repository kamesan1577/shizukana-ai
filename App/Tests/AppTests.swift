import XCTest
import QuietCore
import SwiftData
@testable import QuietApp

final class AppTests: XCTestCase {
    func testBackgroundRefreshIdentifierIsAdvertised() {
        let identifiers = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String]
        XCTAssertTrue(identifiers?.contains("org.kamesan.shizukana-ai.refresh") == true)
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        XCTAssertTrue(modes?.contains("fetch") == true)
        XCTAssertNotNil(Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription"))
        XCTAssertNotNil(Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysAndWhenInUseUsageDescription"))
    }

    @MainActor func testQuietHoursSuppressAwakeSpeech() async throws {
        let store = InMemoryStore()
        let night = Calendar.current.date(bySettingHour: 1, minute: 0, second: 0, of: Date())!
        let clock = FixtureClock(date: night)
        try await store.update { $0.budget = DailyBudget(day: BudgetPolicy.day(for: night), limit: 3) }
        let runtime = CreatureRuntime(store: store, model: FixedModel(),
                                      senses: [FixtureSense()], notifications: StubNotifications(),
                                      clock: { clock.date })
        runtime.quietStart = 23; runtime.quietEnd = 7
        await runtime.wake(allowDream: false)
        let state = try await store.snapshot()
        XCTAssertTrue(state.utterances.isEmpty)
        XCTAssertEqual(state.budget?.used, 0)
        XCTAssertFalse(state.observations.isEmpty)
    }

    @MainActor func testSyntheticDaysRespectZeroThroughThreeBudgets() async throws {
        let store = InMemoryStore()
        let clock = FixtureClock(date: Date(timeIntervalSince1970: 1_767_268_800))
        let runtime = CreatureRuntime(store: store, model: CyclingModel(),
                                      senses: [FixtureSense()], notifications: StubNotifications(),
                                      clock: { clock.date })
        var expected = 0
        for limit in 0...3 {
            let day = Calendar.current.date(byAdding: .day, value: limit, to: Date(timeIntervalSince1970: 1_767_268_800))!
            try await store.update { $0.budget = DailyBudget(day: BudgetPolicy.day(for: day), limit: limit) }
            for opportunity in 0..<3 {
                clock.date = day.addingTimeInterval(Double(opportunity) * 4 * 3600)
                await runtime.wake(allowDream: false)
            }
            expected += limit
            let state = try await store.snapshot()
            XCTAssertEqual(state.utterances.count, expected)
            XCTAssertEqual(state.budget?.used, limit)
        }
    }

    func testResetAndNoCloudFallback() async throws {
        let store = InMemoryStore()
        let runtime = await CreatureRuntime(store: store, model: UnavailableModel(),
                                            notifications: StubNotifications())
        await runtime.wake(allowDream: false)
        let before = try await store.snapshot()
        XCTAssertTrue(before.utterances.isEmpty)
        await runtime.erase()
        let after = try await store.snapshot()
        XCTAssertTrue(after.fragments.isEmpty)
        XCTAssertNil(after.budget)
    }

    @MainActor func testGroundedWakeThenThreeHourSilence() async throws {
        let store = InMemoryStore()
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let clock = FixtureClock(date: noon)
        let today = BudgetPolicy.day(for: noon)
        try await store.update {
            $0.budget = DailyBudget(day: today, limit: 2)
            $0.fragments = [MemoryFragment(text: "昔の海", tags: ["海", "夏", "昼"],
                origin: .prenatal, bornAt: noon.addingTimeInterval(-86400),
                provenance: [SourceRef(.photo, "fixture")])]
        }
        let runtime = CreatureRuntime(store: store, model: FixedModel(),
                                      senses: [FixtureSense()], notifications: StubNotifications(),
                                      clock: { clock.date })
        await runtime.wake(allowDream: false)
        await runtime.wake(allowDream: false)
        let snapshot = try await store.snapshot()
        XCTAssertEqual(snapshot.utterances.count, 1)
        XCTAssertEqual(snapshot.utterances.first?.text, "海、まだあった")
        XCTAssertEqual(snapshot.utterances.first?.sourceIDs.count, 2)
        XCTAssertEqual(snapshot.budget?.used, 1)
    }

    func testSwiftDataRoundTripAndErase() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredIndividual.self, configurations: configuration)
        let store = await SwiftDataMemoryStore(container: container)
        try await store.update { $0.budget = DailyBudget(day: "fixture", limit: 3) }
        let before = try await store.snapshot()
        XCTAssertEqual(before.budget?.limit, 3)
        try await store.reset()
        let after = try await store.snapshot()
        XCTAssertNil(after.budget)
    }

    @MainActor func testDreamReconciliationReschedulesThenRecordsDeliveredSpecimen() async throws {
        let store = InMemoryStore()
        let notifications = RecordingNotifications()
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let clock = FixtureClock(date: noon)
        let future = noon.addingTimeInterval(3600)
        let utterance = Utterance(text: "海、また", createdAt: future, sourceIDs: [])
        try await store.update {
            $0.dream = DreamUtterance(utterance: utterance, scheduledAt: future)
        }
        let runtime = CreatureRuntime(store: store, model: UnavailableModel(), notifications: notifications,
                                      clock: { clock.date })

        await runtime.reconcileNotifications()
        let queued = await notifications.scheduled
        XCTAssertEqual(queued.count, 1)
        XCTAssertEqual(queued.first?.identifier, "quiet-ai-dream-\(utterance.id.uuidString)")
        XCTAssertEqual(queued.first?.text, utterance.text)
        let beforeDelivery = try await store.snapshot()
        XCTAssertEqual(beforeDelivery.dream?.utterance.id, utterance.id)

        clock.date = future.addingTimeInterval(1)
        await runtime.reconcileNotifications()
        let delivered = try await store.snapshot()
        XCTAssertNil(delivered.dream)
        XCTAssertEqual(delivered.utterances.map(\.id), [utterance.id])
        XCTAssertEqual(runtime.utterances.map(\.id), [utterance.id])
    }
}

@MainActor private final class FixtureClock {
    var date: Date
    init(date: Date) { self.date = date }
}

private actor CyclingModel: LanguageModelAdapter {
    private var count = 0
    var available: Bool { get async { true } }
    func respond(to prompt: String) async throws -> String {
        count += 1
        return "海、また見えた\(count)"
    }
}

private struct UnavailableModel: LanguageModelAdapter {
    var available: Bool { get async { false } }
    func respond(to prompt: String) async throws -> String { XCTFail("No inference when unavailable"); return "" }
}

private struct FixedModel: LanguageModelAdapter {
    var available: Bool { get async { true } }
    func respond(to prompt: String) async throws -> String {
        XCTAssertFalse(prompt.contains("fixture"))
        return "海、まだあった"
    }
}

private struct FixtureSense: SenseSource {
    let kind: SenseKind = .time
    func observe(at date: Date) async -> [SenseObservation] {
        [SenseObservation(source: SourceRef(.time, "fixture-day"), observedAt: date,
                          text: "夏の昼", tags: ["海", "夏", "昼"], timeHint: "昼")]
    }
}

private struct StubNotifications: NotificationScheduling {
    func schedule(_ utterance: Utterance, at date: Date, identifier: String) async {}
    func pendingIDs() async -> Set<String> { [] }
    func removePending(_ identifiers: [String]) {}
    func removeAll() {}
}

private actor RecordingNotifications: NotificationScheduling {
    struct Scheduled: Sendable {
        let identifier: String
        let text: String
    }
    private(set) var scheduled: [Scheduled] = []
    func schedule(_ utterance: Utterance, at date: Date, identifier: String) async {
        scheduled.append(Scheduled(identifier: identifier, text: utterance.text))
    }
    func pendingIDs() async -> Set<String> { [] }
    nonisolated func removePending(_ identifiers: [String]) {}
    nonisolated func removeAll() {}
}
