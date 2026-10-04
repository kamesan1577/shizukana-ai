import Foundation

public enum SenseKind: String, Codable, CaseIterable, Sendable {
    case photo, time, weather, location, activity, calendar, touch
}

public struct SourceRef: Codable, Hashable, Sendable {
    public var kind: SenseKind
    public var id: String
    public init(_ kind: SenseKind, _ id: String) { self.kind = kind; self.id = id }
}

public struct SenseObservation: Codable, Identifiable, Sendable {
    public var id: UUID
    public var source: SourceRef
    public var observedAt: Date
    public var text: String
    public var tags: [String]
    public var timeHint: String?
    public var placeKey: String?
    public init(id: UUID = UUID(), source: SourceRef, observedAt: Date, text: String,
                tags: [String], timeHint: String? = nil, placeKey: String? = nil) {
        self.id = id; self.source = source; self.observedAt = observedAt
        self.text = text; self.tags = tags; self.timeHint = timeHint; self.placeKey = placeKey
    }
}

public enum MemoryOrigin: String, Codable, Sendable { case prenatal, lived, consolidated }
public enum MemoryTruth: String, Codable, Sendable { case observed, inferred }

public struct MemoryFragment: Codable, Identifiable, Sendable {
    public var id: UUID
    public var text: String
    public var tags: [String]
    public var origin: MemoryOrigin
    public var bornAt: Date
    public var timeHint: String?
    public var placeKey: String?
    public var salience: Double
    public var strength: Double
    public var lastRecalledAt: Date?
    public var recallCount: Int
    public var truth: MemoryTruth
    public var provenance: [SourceRef]

    public init(id: UUID = UUID(), text: String, tags: [String], origin: MemoryOrigin,
                bornAt: Date, timeHint: String? = nil, placeKey: String? = nil,
                salience: Double = 0.5, strength: Double = 0.5,
                lastRecalledAt: Date? = nil, recallCount: Int = 0,
                truth: MemoryTruth = .observed, provenance: [SourceRef]) {
        self.id = id; self.text = String(text.prefix(64)); self.tags = Array(tags.prefix(6))
        self.origin = origin; self.bornAt = bornAt; self.timeHint = timeHint
        self.placeKey = placeKey; self.salience = min(1, max(0, salience))
        self.strength = min(1, max(0, strength)); self.lastRecalledAt = lastRecalledAt
        self.recallCount = recallCount; self.truth = truth; self.provenance = provenance
    }
}

public struct Utterance: Codable, Identifiable, Sendable {
    public var id: UUID
    public var text: String
    public var createdAt: Date
    public var sourceIDs: [UUID]
    public init(id: UUID = UUID(), text: String, createdAt: Date, sourceIDs: [UUID]) {
        self.id = id; self.text = text; self.createdAt = createdAt; self.sourceIDs = sourceIDs
    }
}

public struct DreamUtterance: Codable, Identifiable, Sendable {
    public var id: UUID
    public var utterance: Utterance
    public var scheduledAt: Date
    public init(id: UUID = UUID(), utterance: Utterance, scheduledAt: Date) {
        self.id = id; self.utterance = utterance; self.scheduledAt = scheduledAt
    }
}

public struct DailyBudget: Codable, Sendable {
    public var day: String
    public var limit: Int
    public var used: Int
    public init(day: String, limit: Int, used: Int = 0) {
        self.day = day; self.limit = min(3, max(0, limit)); self.used = used
    }
}

public protocol SenseSource: Sendable {
    var kind: SenseKind { get }
    func observe(at date: Date) async -> [SenseObservation]
}

public protocol MemoryStore: Sendable {
    func snapshot() async throws -> MemorySnapshot
    func update(_ body: @Sendable (inout MemorySnapshot) -> Void) async throws
    func reset() async throws
}

public struct MemorySnapshot: Codable, Sendable {
    public var observations: [SenseObservation] = []
    public var fragments: [MemoryFragment] = []
    public var utterances: [Utterance] = []
    public var dream: DreamUtterance?
    public var budget: DailyBudget?
    public var prenatalSelectedIDs: [String] = []
    public var prenatalProcessedIDs: Set<String> = []
    public var prenatalDraft: [SenseObservation] = []
    public var prenatalDraftStartedAt: Date?
    public init() {}
}

public enum MemoryPolicy {
    public static func maintain(_ state: inout MemorySnapshot, now: Date) {
        state.observations.removeAll { $0.observedAt < now.addingTimeInterval(-72 * 3600) }
        let draftExpired = state.prenatalDraftStartedAt.map {
            $0 < now.addingTimeInterval(-72 * 3600)
        } ?? true
        if !state.prenatalDraft.isEmpty, draftExpired {
            // Old photos need an acquisition-time TTL, not their historical capture date.
            // Clear the checkpoint too so an interrupted bootstrap can reconstruct its draft.
            state.prenatalProcessedIDs.subtract(state.prenatalDraft.map { $0.source.id })
            state.prenatalDraft.removeAll()
        }
        if state.prenatalDraft.isEmpty { state.prenatalDraftStartedAt = nil }
        if state.fragments.count > 1500 {
            consolidate(&state, now: now)
            state.fragments.sort {
                let lhs = $0.salience * $0.strength / (1 + Double($0.recallCount) * 0.05)
                let rhs = $1.salience * $1.strength / (1 + Double($1.recallCount) * 0.05)
                return lhs > rhs
            }
            let evicted = Set(state.fragments.dropFirst(1500).map(\.id))
            discardFragments(&state, ids: evicted)
        }
        // Repair pre-fix snapshots whose references were orphaned by older compaction.
        let retained = Set(state.fragments.map(\.id))
        let references = state.utterances.flatMap(\.sourceIDs) + (state.dream?.utterance.sourceIDs ?? [])
        detachReferences(&state, to: Set(references).subtracting(retained))
    }

    // Called only under capacity pressure. Provenance is retained so deletion still purges the result.
    public static func consolidate(_ state: inout MemorySnapshot, now: Date) {
        let groups = Dictionary(grouping: state.fragments.filter {
            $0.bornAt < now.addingTimeInterval(-30 * 86400)
        }) { memory in
            "\(memory.tags.sorted().prefix(2).joined(separator: ","))|\(memory.placeKey ?? "")|\(memory.timeHint ?? "")"
        }
        guard let group = groups.values.filter({ $0.count >= 3 }).max(by: { $0.count < $1.count }) else { return }
        let ids = Set(group.map(\.id))
        let sources = Array(Set(group.flatMap(\.provenance))).sorted { $0.id < $1.id }
        let first = group.sorted { $0.bornAt < $1.bornAt }[0]
        let merged = MemoryFragment(text: first.text, tags: first.tags, origin: .consolidated,
                                    bornAt: first.bornAt, timeHint: first.timeHint,
                                    placeKey: first.placeKey,
                                    salience: group.map(\.salience).max() ?? 0.5,
                                    strength: group.map(\.strength).max() ?? 0.5,
                                    truth: .inferred, provenance: sources)
        state.fragments.removeAll { ids.contains($0.id) }
        state.fragments.append(merged)
        // References must follow the retained provenance; orphaned IDs cannot be purged later.
        func remap(_ references: [UUID]) -> [UUID] {
            var seen = Set<UUID>()
            return references.map { ids.contains($0) ? merged.id : $0 }
                .filter { seen.insert($0).inserted }
        }
        for index in state.utterances.indices {
            state.utterances[index].sourceIDs = remap(state.utterances[index].sourceIDs)
        }
        if var dream = state.dream {
            dream.utterance.sourceIDs = remap(dream.utterance.sourceIDs)
            state.dream = dream
        }
    }

    public static func purge(_ state: inout MemorySnapshot, matching source: (SourceRef) -> Bool) {
        let removed = Set(state.fragments.filter { $0.provenance.contains(where: source) }.map(\.id))
        discardFragments(&state, ids: removed)
        state.observations.removeAll { source($0.source) }
        state.prenatalProcessedIDs = state.prenatalProcessedIDs.filter { !source(SourceRef(.photo, $0)) }
        state.prenatalSelectedIDs.removeAll { source(SourceRef(.photo, $0)) }
        state.prenatalDraft.removeAll { source($0.source) }
        if state.prenatalDraft.isEmpty { state.prenatalDraftStartedAt = nil }
    }

    // Rebuilding a draft must retire its old evidence IDs without clearing source checkpoints.
    public static func discardFragments(_ state: inout MemorySnapshot, ids: Set<UUID>) {
        state.fragments.removeAll { ids.contains($0.id) }
        detachReferences(&state, to: ids)
    }

    private static func detachReferences(_ state: inout MemorySnapshot, to removed: Set<UUID>) {
        state.utterances = state.utterances.map { item in
            var copy = item; copy.sourceIDs.removeAll { removed.contains($0) }; return copy
        }
        if let dream = state.dream,
           dream.utterance.sourceIDs.contains(where: { removed.contains($0) }) {
            // A queued utterance cannot be re-grounded after losing evidence.
            state.dream = nil
        }
    }
}
