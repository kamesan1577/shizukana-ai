import Foundation
import Testing
@testable import QuietCore

@Test func retentionAndPurge() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let photo = SourceRef(.photo, "asset-1")
    let id = UUID()
    var state = MemorySnapshot()
    state.observations = [SenseObservation(source: photo, observedAt: now.addingTimeInterval(-73 * 3600), text: "old", tags: []),
                          SenseObservation(source: photo, observedAt: now, text: "new", tags: [])]
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
    let observation = SenseObservation(source: SourceRef(.time, "today"), observedAt: now,
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
    guard case .silence(.assistantLike) = SpeechGate.assess("明日の会議を確認して", association: association,
        recent: [], budget: budget, now: now) else {
        Issue.record("reminders must be silenced"); return
    }
    guard case .silence(.futureState) = SpeechGate.assess("今日は静かだったね", association: association,
        recent: [], budget: budget, now: now, dream: true) else {
        Issue.record("a queued dream cannot claim delivery-time state"); return
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

@Test func prenatalSamplingIsBoundedAndReproducible() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let assets = (0..<100).map {
        PhotoCandidate(id: "\($0)", createdAt: now.addingTimeInterval(Double(-$0) * 86400), favorite: $0.isMultiple(of: 9))
    }
    var a = SeededNoise(seed: 123)
    var b = SeededNoise(seed: 123)
    let first = PrenatalSampler.sample(assets, now: now, random: &a)
    let second = PrenatalSampler.sample(assets, now: now, random: &b)
    #expect(first.count == 48)
    #expect(first.map(\.id) == second.map(\.id))
    #expect(Set(first.map(\.id)).count == 48)
    let observations = first.map { SenseObservation(source: SourceRef(.photo, $0.id), observedAt: now,
                                                text: "空と水", tags: ["空", "水", "夏"]) }
    let memories = PrenatalSampler.compress(observations, at: now)
    #expect((12...20).contains(memories.count))
    #expect(Set(memories.flatMap(\.provenance).map(\.id)).count == 48)
}

@Test func consolidationRetainsEverySourceForPurge() {
    let now = Date(timeIntervalSince1970: 10_000_000)
    var state = MemorySnapshot()
    state.fragments = (0..<3).map { i in
        MemoryFragment(text: "夏の海", tags: ["夏", "海", "昼"], origin: .lived,
            bornAt: now.addingTimeInterval(-90 * 86400), provenance: [SourceRef(.photo, "\(i)")])
    }
    MemoryPolicy.consolidate(&state, now: now)
    #expect(state.fragments.count == 1)
    #expect(state.fragments[0].provenance.count == 3)
    MemoryPolicy.purge(&state) { $0 == SourceRef(.photo, "1") }
    #expect(state.fragments.isEmpty)
}

@Test func purgingOneSourceCancelsQueuedDream() {
    let now = Date(timeIntervalSince1970: 10_000_000)
    let photo = SourceRef(.photo, "deleted")
    let memory = MemoryFragment(text: "海", tags: ["海", "昼", "夏"], origin: .prenatal,
                                bornAt: now, provenance: [photo])
    var state = MemorySnapshot()
    state.fragments = [memory]
    state.dream = DreamUtterance(utterance: Utterance(text: "海、また", createdAt: now,
                                                     sourceIDs: [memory.id]), scheduledAt: now)
    MemoryPolicy.purge(&state) { $0 == photo }
    #expect(state.dream == nil)
}

@Test func consolidationKeepsUtteranceAndDreamProvenancePurgeable() {
    let now = Date(timeIntervalSince1970: 10_000_000)
    var state = MemorySnapshot()
    state.fragments = (0..<3).map { index in
        MemoryFragment(text: "夏の海", tags: ["夏", "海", "昼"], origin: .lived,
            bornAt: now.addingTimeInterval(-90 * 86400),
            provenance: [SourceRef(.photo, "photo-\(index)")])
    }
    let originalIDs = state.fragments.map(\.id)
    state.utterances = [Utterance(text: "海、また", createdAt: now, sourceIDs: originalIDs)]
    state.dream = DreamUtterance(utterance: Utterance(text: "海、まだ", createdAt: now,
                                                     sourceIDs: [originalIDs[0], originalIDs[1]]),
                                  scheduledAt: now.addingTimeInterval(4 * 3600))

    MemoryPolicy.consolidate(&state, now: now)
    let mergedID = state.fragments[0].id
    #expect(state.utterances[0].sourceIDs == [mergedID])
    #expect(state.dream?.utterance.sourceIDs == [mergedID])

    MemoryPolicy.purge(&state) { $0 == SourceRef(.photo, "photo-0") }
    #expect(state.fragments.isEmpty)
    #expect(state.utterances[0].text == "海、また")
    #expect(state.utterances[0].sourceIDs.isEmpty)
    #expect(state.dream == nil)
}

@Test func capacityEvictionDetachesHistoryAndCancelsAffectedDream() {
    let now = Date(timeIntervalSince1970: 10_000_000)
    let evicted = MemoryFragment(text: "薄い海", tags: ["海"], origin: .lived,
        bornAt: now, salience: 0, provenance: [SourceRef(.photo, "evicted")])
    var state = MemorySnapshot()
    state.fragments = [evicted] + (0..<1500).map { index in
        MemoryFragment(text: "残る記憶", tags: ["時刻"], origin: .lived,
            bornAt: now, salience: 1, provenance: [SourceRef(.time, "day-\(index)")])
    }
    let keptID = state.fragments[1].id
    state.utterances = [Utterance(text: "海、また", createdAt: now,
                                 sourceIDs: [evicted.id, keptID])]
    state.dream = DreamUtterance(utterance: Utterance(text: "海、まだ", createdAt: now,
                                                     sourceIDs: [evicted.id, keptID]),
                                  scheduledAt: now.addingTimeInterval(4 * 3600))

    MemoryPolicy.maintain(&state, now: now)
    #expect(state.fragments.count == 1500)
    #expect(!state.fragments.contains { $0.id == evicted.id })
    #expect(state.utterances[0].sourceIDs == [keptID])
    #expect(state.dream == nil)
}

@Test func capacityEvictionPreservesUnrelatedDream() {
    let now = Date(timeIntervalSince1970: 10_000_000)
    var state = MemorySnapshot()
    state.fragments = (0..<1501).map { index in
        MemoryFragment(text: "記憶", tags: ["時刻"], origin: .lived, bornAt: now,
            salience: index == 0 ? 0 : 1, provenance: [SourceRef(.time, "day-\(index)")])
    }
    let keptID = state.fragments[1].id
    let dream = DreamUtterance(utterance: Utterance(text: "夜、まだ", createdAt: now,
                                                  sourceIDs: [keptID]),
                               scheduledAt: now.addingTimeInterval(4 * 3600))
    state.dream = dream
    MemoryPolicy.maintain(&state, now: now)
    #expect(state.dream?.id == dream.id)
    #expect(state.dream?.utterance.sourceIDs == [keptID])
}

@Test func prenatalDraftExpiresByAcquisitionTimeAndCanResume() {
    let now = Date(timeIntervalSince1970: 10_000_000)
    let draft = SenseObservation(source: SourceRef(.photo, "draft-photo"),
        observedAt: now.addingTimeInterval(-365 * 86400), text: "昔の写真", tags: ["写真"])
    var state = MemorySnapshot()
    state.prenatalDraft = [draft]
    state.prenatalSelectedIDs = ["draft-photo", "not-yet-read"]
    state.prenatalProcessedIDs = ["draft-photo"]
    state.prenatalDraftStartedAt = now

    MemoryPolicy.maintain(&state, now: now)
    #expect(state.prenatalDraft.count == 1) // Historical capture time is not draft retention time.
    MemoryPolicy.maintain(&state, now: now.addingTimeInterval(73 * 3600))
    #expect(state.prenatalDraft.isEmpty)
    #expect(state.prenatalProcessedIDs.isEmpty)
    #expect(state.prenatalSelectedIDs == ["draft-photo", "not-yet-read"])
    #expect(state.prenatalDraftStartedAt == nil)
}

@Test func legacyDraftWithoutAcquisitionTimeIsDiscarded() throws {
    let now = Date(timeIntervalSince1970: 10_000_000)
    var state = MemorySnapshot()
    state.prenatalDraft = [SenseObservation(source: SourceRef(.photo, "legacy-photo"),
        observedAt: now, text: "昔の写真", tags: ["写真"])]
    state.prenatalProcessedIDs = ["legacy-photo"]
    let data = try JSONEncoder().encode(state)
    var fields = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    fields.removeValue(forKey: "prenatalDraftStartedAt")
    var decoded = try JSONDecoder().decode(MemorySnapshot.self,
        from: JSONSerialization.data(withJSONObject: fields))
    #expect(decoded.prenatalDraftStartedAt == nil)
    MemoryPolicy.maintain(&decoded, now: now)
    #expect(decoded.prenatalDraft.isEmpty)
    #expect(decoded.prenatalProcessedIDs.isEmpty)
}

@Test func discardingRebuiltFragmentsDetachesHistoryAndCancelsDream() {
    let now = Date(timeIntervalSince1970: 10_000_000)
    let prenatal = MemoryFragment(text: "昔の海", tags: ["海"], origin: .prenatal,
        bornAt: now, provenance: [SourceRef(.photo, "prenatal")])
    let lived = MemoryFragment(text: "夜の気配", tags: ["夜"], origin: .lived,
        bornAt: now, provenance: [SourceRef(.time, "today")])
    var state = MemorySnapshot()
    state.fragments = [prenatal, lived]
    state.prenatalDraft = [SenseObservation(source: SourceRef(.photo, "prenatal"),
        observedAt: now, text: "昔の海", tags: ["海"])]
    state.prenatalSelectedIDs = ["prenatal"]
    state.prenatalProcessedIDs = ["prenatal"]
    state.utterances = [Utterance(text: "海、まだ", createdAt: now, sourceIDs: [prenatal.id, lived.id])]
    state.dream = DreamUtterance(utterance: Utterance(text: "海、また", createdAt: now,
                                                     sourceIDs: [prenatal.id]), scheduledAt: now)

    MemoryPolicy.discardFragments(&state, ids: [prenatal.id])
    #expect(state.fragments.map(\.id) == [lived.id])
    #expect(state.utterances[0].sourceIDs == [lived.id])
    #expect(state.dream == nil)
    #expect(state.prenatalDraft.count == 1)
    #expect(state.prenatalSelectedIDs == ["prenatal"])
    #expect(state.prenatalProcessedIDs == ["prenatal"])
}

@Test func maintenanceRepairsLegacyOrphanedEvidence() {
    let now = Date(timeIntervalSince1970: 10_000_000)
    let orphan = UUID()
    let specimen = Utterance(text: "海、また", createdAt: now, sourceIDs: [orphan])
    var state = MemorySnapshot()
    state.utterances = [specimen]
    state.dream = DreamUtterance(utterance: specimen, scheduledAt: now.addingTimeInterval(3600))
    MemoryPolicy.maintain(&state, now: now)
    #expect(state.utterances.first?.text == specimen.text)
    #expect(state.utterances.first?.sourceIDs.isEmpty == true)
    #expect(state.dream == nil)
}
