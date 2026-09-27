import Foundation

public struct PhotoCandidate: Sendable {
    public let id: String
    public let createdAt: Date
    public let favorite: Bool
    public init(id: String, createdAt: Date, favorite: Bool) {
        self.id = id; self.createdAt = createdAt; self.favorite = favorite
    }
}

public enum PrenatalSampler {
    public static func sample<R: RandomNumberGenerator>(_ assets: [PhotoCandidate], now: Date,
                                                         random: inout R) -> [PhotoCandidate] {
        let ordered = assets.sorted { $0.createdAt < $1.createdAt }
        var selected: [PhotoCandidate] = []
        var seen = Set<String>()
        func append(_ candidate: PhotoCandidate) {
            if seen.insert(candidate.id).inserted { selected.append(candidate) }
        }
        if !ordered.isEmpty {
            for slot in 0..<min(24, ordered.count) {
                let index = min(ordered.count - 1, slot * ordered.count / min(24, ordered.count))
                append(ordered[index])
            }
        }
        for item in ordered.filter({ $0.createdAt >= now.addingTimeInterval(-90 * 86400) })
            .shuffled(using: &random).prefix(12) { append(item) }
        for item in ordered.filter(\.favorite).shuffled(using: &random).prefix(6) { append(item) }
        for item in ordered.shuffled(using: &random) where selected.count < 48 { append(item) }
        return Array(selected.prefix(48))
    }

    public static func compress(_ observations: [SenseObservation], at date: Date) -> [MemoryFragment] {
        guard !observations.isEmpty else { return [] }
        let count = min(20, max(12, Int(ceil(Double(observations.count) / 3))))
        let groups = min(count, observations.count)
        return (0..<groups).map { index in
            let chunk = stride(from: index, to: observations.count, by: groups).map { observations[$0] }
            let tags = Array(Set(chunk.flatMap(\.tags))).sorted().prefix(6)
            let phrase = chunk.first?.text ?? "古い気配"
            return MemoryFragment(text: phrase, tags: Array(tags), origin: .prenatal,
                                  bornAt: date, timeHint: chunk.first?.timeHint,
                                  placeKey: chunk.first?.placeKey, salience: 0.4,
                                  truth: .inferred, provenance: chunk.map(\.source))
        }
    }
}
