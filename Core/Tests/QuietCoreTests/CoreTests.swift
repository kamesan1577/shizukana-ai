import Foundation
import Testing
@testable import QuietCore

@Test func retentionAndPurge() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let photo = SourceRef(.photo, "asset-1")
    let id = UUID()
    var state = MemorySnapshot()
    state.observations = [Observation(source: photo, observedAt: now.addingTimeInterval(-73 * 3600), text: "old", tags: []),
                          Observation(source: photo, observedAt: now, text: "new", tags: [])]
    state.fragments = (0..<1501).map { index in
        MemoryFragment(id: index == 0 ? id : UUID(), text: "海", tags: ["海", "昼", "夏"],
                       origin: .prenatal, bornAt: now, salience: index == 0 ? 1 : 0.5,
                       provenance: index == 0 ? [photo] : [SourceRef(.time, "day")])
    }
    state.utterances = [Utterance(text: "海、また", createdAt: now, sourceIDs: [id])]
    MemoryPolicy.maintain(&state, now: now)
    #expect(state.observations.count == 1)
    #expect(state.fragments.count == 1500)
    MemoryPolicy.purge(&state) { $0 == photo }
    #expect(!state.fragments.contains { $0.id == id })
    #expect(state.observations.isEmpty)
    #expect(state.utterances.first?.text == "海、また")
    #expect(state.utterances.first?.sourceIDs.isEmpty == true)
}

@Test func recallIsSeededAndIncludesNoise() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let memories = (0..<12).map { i in
        MemoryFragment(text: "断片\(i)", tags: ["海", "昼", "夏"], origin: .lived,
                       bornAt: now.addingTimeInterval(Double(-i) * 86400),
                       salience: 0.5, provenance: [SourceRef(.time, "day")])
    }
    let observation = Observation(source: SourceRef(.time, "today"), observedAt: now,
                                  text: "昼", tags: ["昼"])
    var first = SeededNoise(seed: 42)
    var second = SeededNoise(seed: 42)
    let a = RecallEngine.recall(memories, observation: observation, at: now, random: &first)
    let b = RecallEngine.recall(memories, observation: observation, at: now, random: &second)
    #expect(a.selected.count == 5)
    #expect(a.selected.map(\.id) == b.selected.map(\.id))
    #expect(Set(a.selected.map(\.id)).count == 5)
    #expect(a.candidates.contains { $0.noise > 0 })
}

@Test func gateAcceptsOrSilences() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let memory = MemoryFragment(text: "海", tags: ["海", "昼", "夏"], origin: .lived,
                                bornAt: now, provenance: [SourceRef(.photo, "1")])
    let association = AssociationMaker.make([memory], observation: nil, dream: true)
    let budget = DailyBudget(day: "day", limit: 1)
    guard case .accepted(let utterance) = SpeechGate.assess("海、まだあった", association: association,
                                                        recent: [], budget: budget, now: now) else {
        Issue.record("grounded one-liner must pass"); return
    }
    #expect(utterance.sourceIDs == [memory.id])
    guard case .silence(.interval) = SpeechGate.assess("海、また", association: association,
                                                      recent: [utterance], budget: budget, now: now) else {
        Issue.record("three-hour interval must hold"); return
    }
    guard case .silence(.budget) = SpeechGate.assess("海、また", association: association,
                                                   recent: [], budget: DailyBudget(day: "day", limit: 0), now: now) else {
        Issue.record("silent days must be normal"); return
    }
}

@Test func resetRemovesEntireIndividual() async throws {
    let store = InMemoryStore()
    try await store.update { $0.budget = DailyBudget(day: "day", limit: 2) }
    try await store.reset()
    let state = try await store.snapshot()
    #expect(state.budget == nil)
    #expect(state.fragments.isEmpty)
    #expect(state.utterances.isEmpty)
}
