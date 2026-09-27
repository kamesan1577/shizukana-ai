import Foundation

public struct SeededNoise: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }
}

public struct RecallScore: Sendable {
    public let id: UUID
    public let related: Double
    public let place: Double
    public let time: Double
    public let salience: Double
    public let forgottenness: Double
    public let noise: Double
    public let repetitionPenalty: Double
    public var total: Double {
        0.30 * related + 0.15 * place + 0.15 * time + 0.15 * salience
        + 0.10 * forgottenness + 0.15 * noise - repetitionPenalty
    }
}

public struct RecallResult: Sendable {
    public let candidates: [RecallScore]
    public let selected: [MemoryFragment]
}

public enum RecallEngine {
    public static func recall<R: RandomNumberGenerator>(
        _ fragments: [MemoryFragment], observation: Observation?, at date: Date,
        random: inout R
    ) -> RecallResult {
        let scores = fragments.map { memory -> RecallScore in
            let overlap = observation.map { Set(memory.tags).intersection($0.tags).count } ?? 0
            let related = Double(overlap) / Double(max(1, observation?.tags.count ?? 1))
            let place = observation?.placeKey.flatMap { $0 == memory.placeKey ? 1.0 : 0 } ?? 0
            let time = observation?.timeHint.flatMap { $0 == memory.timeHint ? 1.0 : 0 } ?? 0
            let days = max(0, date.timeIntervalSince(memory.lastRecalledAt ?? memory.bornAt) / 86400)
            let forgottenness = min(1, days / 30) * memory.strength
            let noise = Double.random(in: 0..<1, using: &random)
            let penalty = memory.lastRecalledAt.map {
                max(0, 0.3 * (1 - date.timeIntervalSince($0) / (7 * 86400)))
            } ?? 0
            return RecallScore(id: memory.id, related: related, place: place, time: time,
                               salience: memory.salience, forgottenness: forgottenness,
                               noise: noise, repetitionPenalty: penalty)
        }
        let lookup = Dictionary(uniqueKeysWithValues: fragments.map { ($0.id, $0) })
        var pool = scores
        var chosen: [MemoryFragment] = []
        func take(_ ordering: (RecallScore, RecallScore) -> Bool) {
            guard let score = pool.sorted(by: ordering).first, let memory = lookup[score.id] else { return }
            chosen.append(memory)
            pool.removeAll { $0.id == score.id }
        }
        // One slot intentionally ignores relevance: old, unrelated memories can surface.
        for _ in 0..<2 { take { $0.total > $1.total } }
        take { $0.forgottenness > $1.forgottenness }
        take { $0.noise > $1.noise }
        take { $0.total > $1.total }
        return RecallResult(candidates: scores, selected: chosen)
    }
}
