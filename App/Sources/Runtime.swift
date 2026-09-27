import Foundation
import Observation
import FoundationModels
import UserNotifications
import BackgroundTasks
import SwiftData
import QuietCore

struct LocalModel: LanguageModelAdapter {
    var available: Bool { get async { SystemLanguageModel.default.isAvailable } }
    func respond(to prompt: String) async throws -> String {
        // A fresh session has no accumulated conversation or hidden life history.
        let session = LanguageModelSession(model: .default)
        let response = try await session.respond(to: prompt)
        return response.content
    }
}

struct BrainTrace: Identifiable {
    let id = UUID()
    let timestamp: Date
    let observations: [SenseObservation]
    let recall: RecallResult?
    let association: Association?
    let rawOutput: String?
    let result: String
    let scheduledAt: Date?
}

@MainActor @Observable
final class CreatureRuntime {
    let store: any MemoryStore
    let model: any LanguageModelAdapter
    let notifications: any NotificationScheduling
    let photos = PhotoSense()
    let places = PlaceSense()
    let calendar = CalendarSense()
    var latest: Utterance?
    var utterances: [Utterance] = []
    var traces: [BrainTrace] = []
    var developerMode = false
    var modelReady = true
    var quietStart = (UserDefaults.standard.object(forKey: "quietStart") as? Int) ?? 23 {
        didSet { UserDefaults.standard.set(quietStart, forKey: "quietStart") }
    }
    var quietEnd = (UserDefaults.standard.object(forKey: "quietEnd") as? Int) ?? 7 {
        didSet { UserDefaults.standard.set(quietEnd, forKey: "quietEnd") }
    }
    private let injectedSenses: [any SenseSource]?
    private let clock: @MainActor () -> Date
    private var running = false
    private let notificationID = "quiet-ai-dream"

    init(store: any MemoryStore, model: any LanguageModelAdapter = LocalModel(),
         senses: [any SenseSource]? = nil,
         notifications: any NotificationScheduling = LocalNotificationScheduler(),
         clock: @escaping @MainActor () -> Date = { Date() }) {
        self.store = store; self.model = model; self.injectedSenses = senses
        self.notifications = notifications
        self.clock = clock
    }

    func refresh() async {
        guard let state = try? await store.snapshot() else { return }
        utterances = state.utterances.sorted { $0.createdAt > $1.createdAt }
        latest = utterances.first
        modelReady = await model.available
    }

    func bootstrap() async {
        guard let state = try? await store.snapshot() else { return }
        let now = clock()
        let selection = state.prenatalSelectedIDs.isEmpty ? photos.selectAssets(at: now) : state.prenatalSelectedIDs
        if state.prenatalSelectedIDs.isEmpty {
            try? await store.update { $0.prenatalSelectedIDs = selection }
        }
        let observations = await photos.bootstrap(selection: selection, processed: state.prenatalProcessedIDs)
        guard !observations.isEmpty else { return }
        // Rebuild from the bounded coarse draft so cancellation never duplicates memories.
        try? await store.update { snapshot in
            snapshot.prenatalDraft.append(contentsOf: observations)
            snapshot.fragments.removeAll { $0.origin == .prenatal }
            snapshot.fragments.append(contentsOf: PrenatalSampler.compress(snapshot.prenatalDraft, at: now))
            snapshot.prenatalProcessedIDs.formUnion(observations.map { $0.source.id })
            if snapshot.prenatalProcessedIDs.count >= snapshot.prenatalSelectedIDs.count {
                snapshot.prenatalDraft.removeAll()
            }
            MemoryPolicy.maintain(&snapshot, now: now)
        }
    }

    func reconcileSources() async {
        let state = try? await store.snapshot()
        guard let state else { return }
        let photoStatus = PHAuthorization.photoAccess
        let photoIDs = photoStatus ? photos.accessibleIDs() : []
        let calendarAllowed = EKAuthorization.calendarAccess
        let placeAllowed = places.isAuthorized
        let calendarIDs = Set(state.fragments.flatMap(\.provenance).filter { $0.kind == .calendar }.map(\.id)
            .filter { calendar.containsEvent($0) })
        try? await store.update { snapshot in
            MemoryPolicy.purge(&snapshot) { source in
                switch source.kind {
                case .photo: return !photoIDs.contains(source.id)
                case .calendar: return !calendarAllowed || !calendarIDs.contains(source.id)
                case .location: return !placeAllowed
                default: return false
                }
            }
        }
        let after = try? await store.snapshot()
        if after?.fragments.count != state.fragments.count || after?.observations.count != state.observations.count {
            traces.removeAll() // Prompts and raw outputs may contain data from the revoked source.
        }
        if state.dream != nil, after?.dream == nil {
            notifications.removePending([notificationID])
        }
    }

    func wake(allowDream: Bool = true, backgroundOnly: Bool = false) async {
        guard !running else { return }
        running = true
        defer { running = false }
        let now = clock()
        let foreground: [any SenseSource] = [TimeSense(),
            WeatherSense(location: { [places] in await places.latestLocation }),
            places, ActivitySense(), calendar]
        let senses: [any SenseSource] = injectedSenses ?? (backgroundOnly ? [TimeSense(), places] : foreground)
        var observations: [SenseObservation] = []
        for sense in senses { observations += await sense.observe(at: now) }
        guard let current = observations.first else { return }
        let gathered = observations
        try? await store.update { state in
            state.observations.append(contentsOf: gathered)
            // Only a few coarse fragments per day survive. The raw observation has a 72h TTL.
            let today = BudgetPolicy.day(for: now)
            let made = state.fragments.filter { $0.origin == .lived && BudgetPolicy.day(for: $0.bornAt) == today }.count
            for observation in gathered.prefix(max(0, 4 - made)) {
                guard !state.fragments.contains(where: { $0.origin == .lived && $0.provenance == [observation.source] && BudgetPolicy.day(for: $0.bornAt) == today }) else { continue }
                state.fragments.append(MemoryFragment(text: observation.text, tags: observation.tags,
                    origin: .lived, bornAt: now, timeHint: observation.timeHint,
                    placeKey: observation.placeKey, provenance: [observation.source]))
            }
            MemoryPolicy.maintain(&state, now: now)
        }
        if backgroundOnly { return }
        await consider(observation: current, dreamDelivery: nil, now: now)
        if allowDream { await scheduleDream(after: now) }
        await refresh()
    }

    private func consider(observation: SenseObservation?, dreamDelivery: Date?, now: Date) async {
        guard var state = try? await store.snapshot() else { return }
        if state.budget?.day != BudgetPolicy.day(for: now) {
            var rng = SystemRandomNumberGenerator()
            let newBudget = DailyBudget(day: BudgetPolicy.day(for: now), limit: BudgetPolicy.limit(using: &rng))
            try? await store.update { $0.budget = newBudget }
            state.budget = newBudget
        }
        var rng = SystemRandomNumberGenerator()
        let recall = RecallEngine.recall(state.fragments, observation: observation, at: now, random: &rng)
        let association = AssociationMaker.make(recall.selected, observation: observation, dream: dreamDelivery != nil)
        guard await model.available, let association else {
            record(BrainTrace(timestamp: now, observations: observation.map { [$0] } ?? [], recall: recall,
                              association: association, rawOutput: nil, result: "modelUnavailable / noGrounding", scheduledAt: nil))
            return
        }
        let raw = try? await model.respond(to: association.prompt)
        let delivery = dreamDelivery ?? now
        var recent = state.utterances
        if let pending = state.dream { recent.append(pending.utterance) }
        let result = raw.map { SpeechGate.assess($0, association: association, recent: recent,
                                                  budget: state.budget!, now: delivery,
                                                  dream: dreamDelivery != nil) } ?? .silence(.modelUnavailable)
        switch result {
        case .silence(let reason):
            record(BrainTrace(timestamp: now, observations: observation.map { [$0] } ?? [], recall: recall,
                              association: association, rawOutput: raw, result: reason.rawValue, scheduledAt: nil))
        case .accepted(let utterance):
            let selected = Set(recall.selected.map(\.id))
            let recorded = Utterance(id: utterance.id, text: utterance.text, createdAt: delivery,
                                     sourceIDs: utterance.sourceIDs)
            try? await store.update { snapshot in
                if dreamDelivery == nil { snapshot.utterances.append(recorded) }
                else { snapshot.dream = DreamUtterance(utterance: recorded, scheduledAt: delivery) }
                snapshot.budget?.used += 1
                for index in snapshot.fragments.indices where selected.contains(snapshot.fragments[index].id) {
                    snapshot.fragments[index].lastRecalledAt = now
                    snapshot.fragments[index].recallCount += 1
                }
            }
            if dreamDelivery != nil {
                await notifications.schedule(recorded, at: delivery, identifier: notificationID)
                record(BrainTrace(timestamp: now, observations: [], recall: recall, association: association,
                                  rawOutput: raw, result: "dream", scheduledAt: delivery))
            } else {
                await notifications.schedule(recorded, at: now.addingTimeInterval(2), identifier: utterance.id.uuidString)
                record(BrainTrace(timestamp: now, observations: [currentForTrace(observation)], recall: recall,
                                  association: association, rawOutput: raw, result: "accepted", scheduledAt: now))
            }
        }
    }

    private func currentForTrace(_ observation: SenseObservation?) -> SenseObservation {
        observation ?? SenseObservation(source: SourceRef(.time, "unknown"), observedAt: Date(), text: "", tags: [])
    }
    private func nextDelivery(after date: Date) -> Date {
        var next = date.addingTimeInterval(4 * 3600)
        let calendar = Calendar.current
        for _ in 0..<24 {
            let hour = calendar.component(.hour, from: next)
            if quietStart <= quietEnd ? (hour < quietStart || hour >= quietEnd) : (hour >= quietEnd && hour < quietStart) {
                break
            }
            next = next.addingTimeInterval(3600)
        }
        return next
    }
    private func scheduleDream(after now: Date) async {
        guard let state = try? await store.snapshot(), state.dream == nil,
              let budget = state.budget, budget.used < budget.limit else { return }
        let delivery = nextDelivery(after: now)
        // A reservation belongs to its delivery day; never spend tomorrow's budget today.
        guard Calendar.current.isDate(delivery, inSameDayAs: now) else { return }
        await consider(observation: nil, dreamDelivery: delivery, now: now)
    }
    func reconcileNotifications() async {
        guard let state = try? await store.snapshot(), let dream = state.dream else { return }
        if dream.scheduledAt <= Date() {
            try? await store.update {
                $0.utterances.append(dream.utterance)
                $0.dream = nil
            }
            await refresh()
            return
        }
        let pending = await notifications.pendingIDs()
        if !pending.contains(notificationID) {
            await notifications.schedule(dream.utterance, at: dream.scheduledAt, identifier: notificationID)
        }
    }
    private func record(_ trace: BrainTrace) {
        traces.append(trace)
        traces.removeAll { $0.timestamp < Date().addingTimeInterval(-72 * 3600) }
        if traces.count > 30 { traces.removeFirst(traces.count - 30) }
    }
    func erase() async {
        notifications.removeAll()
        traces.removeAll()
        developerMode = false
        UserDefaults.standard.removeObject(forKey: "quietStart")
        UserDefaults.standard.removeObject(forKey: "quietEnd")
        UserDefaults.standard.removeObject(forKey: "activitySenseEnabled")
        UserDefaults.standard.removeObject(forKey: "weatherSenseEnabled")
        UserDefaults.standard.removeObject(forKey: "didExplainSenses")
        quietStart = 23; quietEnd = 7
        try? await store.reset()
        await refresh()
    }
}

// Keeping permission checks in one place makes revocation reconciliation explicit.
import Photos
import EventKit
private enum PHAuthorization {
    @MainActor static var photoAccess: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }
}
private enum EKAuthorization {
    @MainActor static var calendarAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }
}
