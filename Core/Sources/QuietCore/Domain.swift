import Foundation

public enum SenseKind: String, Codable, CaseIterable, Sendable {
    case photo, time, weather, location, activity, calendar, touch
}

public struct SourceRef: Codable, Hashable, Sendable {
    public var kind: SenseKind
    public var id: String
    public init(_ kind: SenseKind, _ id: String) { self.kind = kind; self.id = id }
}

public struct Observation: Codable, Identifiable, Sendable {
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
    func observe(at date: Date) async -> [Observation]
}

public protocol MemoryStore: Sendable {
    func snapshot() async throws -> MemorySnapshot
    func update(_ body: @Sendable (inout MemorySnapshot) -> Void) async throws
    func reset() async throws
}

public struct MemorySnapshot: Codable, Sendable {
    public var observations: [Observation] = []
    public var fragments: [MemoryFragment] = []
    public var utterances: [Utterance] = []
    public var dream: DreamUtterance?
    public var budget: DailyBudget?
    public var prenatalProcessedIDs: Set<String> = []
    public init() {}
}

public enum MemoryPolicy {
    public static func maintain(_ state: inout MemorySnapshot, now: Date) {
        state.observations.removeAll { $0.observedAt < now.addingTimeInterval(-72 * 3600) }
        if state.fragments.count > 1500 {
            state.fragments.sort {
                let lhs = $0.salience * $0.strength / (1 + Double($0.recallCount) * 0.05)
                let rhs = $1.salience * $1.strength / (1 + Double($1.recallCount) * 0.05)
                return lhs > rhs
            }
            state.fragments = Array(state.fragments.prefix(1500))
        }
    }

    public static func purge(_ state: inout MemorySnapshot, matching source: (SourceRef) -> Bool) {
        let removed = Set(state.fragments.filter { $0.provenance.contains(where: source) }.map(\.id))
        state.fragments.removeAll { removed.contains($0.id) }
        state.observations.removeAll { source($0.source) }
        state.utterances = state.utterances.map { item in
            var copy = item; copy.sourceIDs.removeAll { removed.contains($0) }; return copy
        }
        if var dream = state.dream {
            dream.utterance.sourceIDs.removeAll { removed.contains($0) }
            state.dream = dream.utterance.sourceIDs.isEmpty ? nil : dream
        }
        state.prenatalProcessedIDs = state.prenatalProcessedIDs.filter { !source(SourceRef(.photo, $0)) }
    }
}
