import XCTest
import QuietCore
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
}

private struct UnavailableModel: LanguageModelAdapter {
    var available: Bool { get async { false } }
    func respond(to prompt: String) async throws -> String { XCTFail("No inference when unavailable"); return "" }
}
