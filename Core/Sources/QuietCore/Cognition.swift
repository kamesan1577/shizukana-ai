import Foundation

public protocol LanguageModelAdapter: Sendable {
    var available: Bool { get async }
    func respond(to prompt: String) async throws -> String
}

public struct Association: Sendable {
    public let text: String
    public let sourceIDs: [UUID]
    public let prompt: String
}

public enum AssociationMaker {
    public static func make(_ recalled: [MemoryFragment], observation: SenseObservation?, dream: Bool) -> Association? {
        guard !recalled.isEmpty else { return nil }
        let evidence = recalled.prefix(5).map { $0.text }.joined(separator: " / ")
        let context = dream ? "" : observation.map { "今の粗い気配: \($0.text)\n" } ?? ""
        let text = String(evidence.prefix(120))
        let prompt = """
        実際に見た断片だけをもとに、曖昧な独り言を一文で返す。説明、助言、予定、問いかけは禁止。
        20文字以内。根拠が薄ければ SILENCE と返す。現在や未来の状態を断言しない。
        \(context)記憶の断片: \(text)
        """
        return Association(text: text, sourceIDs: Array(recalled.prefix(5).map(\.id)), prompt: prompt)
    }
}

public enum SilenceReason: String, Sendable {
    case modelUnavailable, noGrounding, modelSilence, tooLong, assistantLike, repetition, budget, interval
}

public enum GateResult: Sendable {
    case accepted(Utterance)
    case silence(SilenceReason)
}

public enum SpeechGate {
    public static func assess(_ raw: String, association: Association?, recent: [Utterance],
                              budget: DailyBudget, now: Date) -> GateResult {
        guard let association, !association.sourceIDs.isEmpty else { return .silence(.noGrounding) }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != "SILENCE" else { return .silence(.modelSilence) }
        guard !text.contains("\n"), text.count <= 20 else { return .silence(.tooLong) }
        let forbidden = ["してください", "しましょう", "おすすめ", "教えて", "リマインド", "理由", "なぜなら"]
        guard !forbidden.contains(where: text.contains) else { return .silence(.assistantLike) }
        guard budget.used < budget.limit else { return .silence(.budget) }
        guard !recent.contains(where: { abs(now.timeIntervalSince($0.createdAt)) < 3 * 3600 }) else {
            return .silence(.interval)
        }
        guard !recent.suffix(20).contains(where: { $0.text == text }) else { return .silence(.repetition) }
        return .accepted(Utterance(text: text, createdAt: now, sourceIDs: association.sourceIDs))
    }
}

public enum BudgetPolicy {
    public static func day(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
    public static func limit<R: RandomNumberGenerator>(using random: inout R) -> Int {
        let draw = Int.random(in: 0..<100, using: &random)
        if draw < 20 { return 0 }
        if draw < 75 { return 1 }
        if draw < 95 { return 2 }
        return 3
    }
}
