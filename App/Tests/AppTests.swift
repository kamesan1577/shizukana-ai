import XCTest
import QuietCore
import SwiftData
@testable import QuietApp

final class AppTests: XCTestCase {
    func testResetAndNoCloudFallback() async throws {
        let store = InMemoryStore()
        let runtime = await CreatureRuntime(store: store, model: UnavailableModel())
        await runtime.wake(allowDream: false)
        let before = try await store.snapshot()
        XCTAssertTrue(before.utterances.isEmpty)
        await runtime.erase()
        let after = try await store.snapshot()
        XCTAssertTrue(after.fragments.isEmpty)
        XCTAssertNil(after.budget)
    }

    func testGroundedWakeThenThreeHourSilence() async throws {
        let store = InMemoryStore()
        let today = BudgetPolicy.day(for: Date())
        try await store.update {
            $0.budget = DailyBudget(day: today, limit: 2)
            $0.fragments = [MemoryFragment(text: "昔の海", tags: ["海", "夏", "昼"],
                origin: .prenatal, bornAt: Date().addingTimeInterval(-86400),
                provenance: [SourceRef(.photo, "fixture")])]
        }
        let runtime = await CreatureRuntime(store: store, model: FixedModel(), senses: [FixtureSense()])
        await runtime.wake(allowDream: false)
        await runtime.wake(allowDream: false)
        let snapshot = try await store.snapshot()
        XCTAssertEqual(snapshot.utterances.count, 1)
        XCTAssertEqual(snapshot.utterances[0].text, "海、まだあった")
        XCTAssertEqual(snapshot.utterances[0].sourceIDs.count, 2)
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
