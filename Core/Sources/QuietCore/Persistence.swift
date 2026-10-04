import Foundation
import SwiftData

@Model
public final class StoredIndividual {
    @Attribute(.unique) public var key: String
    public var payload: Data
    public init(key: String = "individual", payload: Data = Data()) {
        self.key = key; self.payload = payload
    }
}

@MainActor
public final class SwiftDataMemoryStore: MemoryStore {
    private let context: ModelContext
    public init(container: ModelContainer) { context = ModelContext(container) }

    public func snapshot() throws -> MemorySnapshot {
        let records = try context.fetch(FetchDescriptor<StoredIndividual>())
        guard let data = records.first(where: { $0.key == "individual" })?.payload,
              !data.isEmpty else { return MemorySnapshot() }
        return try JSONDecoder().decode(MemorySnapshot.self, from: data)
    }

    public func update(_ body: @Sendable (inout MemorySnapshot) -> Void) throws {
        var state = try snapshot()
        body(&state)
        let records = try context.fetch(FetchDescriptor<StoredIndividual>())
        let record = records.first(where: { $0.key == "individual" }) ?? StoredIndividual()
        record.payload = try JSONEncoder().encode(state)
        if record.modelContext == nil { context.insert(record) }
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    public func reset() throws {
        try context.delete(model: StoredIndividual.self)
        do { try context.save() }
        catch { context.rollback(); throw error }
    }
}

public actor InMemoryStore: MemoryStore {
    private var state = MemorySnapshot()
    public init() {}
    public func snapshot() -> MemorySnapshot { state }
    public func update(_ body: @Sendable (inout MemorySnapshot) -> Void) { body(&state) }
    public func reset() { state = MemorySnapshot() }
}
