import Foundation
import Observation
import FoundationModels
import UserNotifications
import BackgroundTasks
import SwiftData
import CoreMotion
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

// A generation is invalidated before reset/purge. Store mutations check it inside the
// transaction too, so an awaited model/sense result cannot restore deleted data.
private final class RuntimeGeneration: @unchecked Sendable {
    private let lock = NSLock()
    private var valid = true
    var isValid: Bool { lock.withLock { valid } }
    func invalidate() { lock.withLock { valid = false } }
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
        didSet {
            UserDefaults.standard.set(quietStart, forKey: "quietStart")
            if oldValue != quietStart { quietHoursChanged() }
        }
    }
    var quietEnd = (UserDefaults.standard.object(forKey: "quietEnd") as? Int) ?? 7 {
        didSet {
            UserDefaults.standard.set(quietEnd, forKey: "quietEnd")
            if oldValue != quietEnd { quietHoursChanged() }
        }
    }
    private let injectedSenses: [any SenseSource]?
    private let clock: @MainActor () -> Date
    private var running = false
    private var bootstrapping = false
    private var reconcilingNotifications = false
    private var activating = false
    private var activationRequested = false
    private var foregroundActive = false
    private var resetRevision = 0
    private var erasing = false
    private var purging = false
    private var privacyBlocked = false
    private var generation = RuntimeGeneration()
    private(set) var persistenceFailed = false
    private let legacyDreamID = "quiet-ai-dream"
    private func dreamNotificationID(_ utterance: Utterance) -> String {
        "quiet-ai-dream-\(utterance.id.uuidString)"
    }

    init(store: any MemoryStore, model: any LanguageModelAdapter = LocalModel(),
         senses: [any SenseSource]? = nil,
         notifications: any NotificationScheduling = LocalNotificationScheduler(),
         clock: @escaping @MainActor () -> Date = { Date() }) {
        self.store = store; self.model = model; self.injectedSenses = senses
        self.notifications = notifications
        self.clock = clock
    }

    func refresh() async {
        let token = generation
        guard let state = try? await store.snapshot(), token.isValid else { return }
        utterances = state.utterances.sorted { $0.createdAt > $1.createdAt }
        latest = utterances.first
        let available = await model.available
        if token.isValid { modelReady = available }
    }

    private func quietHoursChanged() {
        guard !erasing, !purging else { return }
        invalidateWork()
        Task { await reconcileNotifications() }
    }

    /// Called for every foreground activation, including return from iOS Settings.
    func activate() async {
        guard !erasing, !purging else { return }
        foregroundActive = true
        if activating { activationRequested = true; return }
        activating = true
        defer {
            activating = false
            if activationRequested, foregroundActive {
                activationRequested = false
                Task { if foregroundActive { await activate() } }
            }
        }
        let revision = resetRevision
        await reconcileSources()
        guard !Task.isCancelled, foregroundActive, !privacyBlocked, revision == resetRevision else { return }
        let token = generation
        await bootstrap()
        guard isCurrent(token) else { return }
        await wake()
        if isCurrent(token) { await refresh() }
    }

    func deactivate() {
        foregroundActive = false
        activationRequested = false
        invalidateWork()
    }

    private func isCurrent(_ token: RuntimeGeneration) -> Bool {
        token.isValid && !Task.isCancelled && !erasing && !purging && !privacyBlocked
    }

    private func invalidateWork() {
        generation.invalidate()
        generation = RuntimeGeneration()
    }

    func bootstrap() async {
        guard !bootstrapping, !erasing, !purging, !privacyBlocked else { return }
        bootstrapping = true
        defer { bootstrapping = false }
        let token = generation
        let now = clock()
        do { try await store.update { if token.isValid { MemoryPolicy.maintain(&$0, now: now) } } }
        catch { persistenceFailed = true; return }
        guard let state = try? await store.snapshot(), isCurrent(token) else { return }
        let selection = state.prenatalSelectedIDs.isEmpty ? photos.selectAssets(at: now) : state.prenatalSelectedIDs
        do {
            if state.prenatalSelectedIDs.isEmpty {
                try await store.update { if token.isValid { $0.prenatalSelectedIDs = selection } }
            }
            guard isCurrent(token) else { return }
            let observations = await photos.bootstrap(selection: selection, processed: state.prenatalProcessedIDs)
            guard isCurrent(token), !observations.isEmpty else { return }
            try await store.update { snapshot in
                guard token.isValid else { return }
                // Rebuild the bounded draft, keeping every source for later deletion.
                if snapshot.prenatalDraft.isEmpty { snapshot.prenatalDraftStartedAt = now }
                let known = Set(snapshot.prenatalDraft.map(\.source))
                snapshot.prenatalDraft.append(contentsOf: observations.filter { !known.contains($0.source) })
                let replaced = Set(snapshot.fragments.filter { $0.origin == .prenatal }.map(\.id))
                MemoryPolicy.discardFragments(&snapshot, ids: replaced)
                snapshot.fragments.append(contentsOf: PrenatalSampler.compress(snapshot.prenatalDraft, at: now))
                snapshot.prenatalProcessedIDs.formUnion(observations.map { $0.source.id })
                if snapshot.prenatalProcessedIDs.count >= snapshot.prenatalSelectedIDs.count {
                    snapshot.prenatalDraft.removeAll()
                    snapshot.prenatalDraftStartedAt = nil
                }
                MemoryPolicy.maintain(&snapshot, now: now)
            }
            if isCurrent(token) { await reconcileNotifications() }
        } catch { persistenceFailed = true }
    }

    func reconcileSources() async {
        let token = generation
        guard !erasing, let state = try? await store.snapshot(), token.isValid, !Task.isCancelled else { return }
        let photoIDs = PHAuthorization.photoAccess ? photos.accessibleIDs() : []
        let calendarAllowed = EKAuthorization.calendarAccess
        let placeAllowed = places.isAuthorized
        let activityAllowed = CMPedometer.authorizationStatus() == .authorized
            && UserDefaults.standard.bool(forKey: "activitySenseEnabled")
        let weatherAllowed = placeAllowed && UserDefaults.standard.bool(forKey: "weatherSenseEnabled")
        let sources = Set(state.fragments.flatMap(\.provenance)
            + state.observations.map(\.source) + state.prenatalDraft.map(\.source)
            + state.prenatalSelectedIDs.map { SourceRef(.photo, $0) })
        let removed = Set(sources.filter { source in
            switch source.kind {
            case .photo: return !photoIDs.contains(source.id)
            case .calendar: return !calendarAllowed || !calendar.containsEvent(source.id)
            case .location: return !placeAllowed
            case .activity: return !activityAllowed
            case .weather: return !weatherAllowed
            default: return false
            }
        })
        if !removed.isEmpty { await purgeSources { removed.contains($0) } }
    }

    func purgeSources(matching source: @escaping @Sendable (SourceRef) -> Bool) async {
        guard !erasing, !purging else { return }
        purging = true
        invalidateWork()
        let token = generation
        defer { purging = false }
        traces.removeAll()
        do {
            let before = try await store.snapshot()
            guard token.isValid else { return }
            let removed = Set(before.fragments.filter { $0.provenance.contains(where: source) }.map(\.id))
            let pending = before.utterances.filter { $0.sourceIDs.contains(where: removed.contains) }.map { $0.id.uuidString }
            await notifications.removePending(pending)
            guard token.isValid else { return }
            try await store.update { if token.isValid { MemoryPolicy.purge(&$0, matching: source) } }
            guard token.isValid else { return }
            privacyBlocked = false
            purging = false
            await reconcileNotifications()
            await refresh()
        } catch {
            guard token.isValid else { return }
            // Fail closed until the source purge can be persisted.
            privacyBlocked = true
            persistenceFailed = true
            await notifications.removeAll()
        }
    }

    func wake(allowDream: Bool = true, backgroundOnly: Bool = false) async {
        guard !running, !erasing, !purging, !privacyBlocked else { return }
        running = true
        defer { running = false }
        let revision = resetRevision
        if backgroundOnly { await reconcileSources() }
        guard !Task.isCancelled, !privacyBlocked, revision == resetRevision else { return }
        let token = generation
        let now = clock()
        await reconcileNotifications()
        guard isCurrent(token) else { return }
        let foreground: [any SenseSource] = [TimeSense(), photos, places, ActivitySense(), calendar,
            WeatherSense(location: { [places] in await places.latestLocation })]
        let senses: [any SenseSource] = injectedSenses ?? (backgroundOnly ? [TimeSense(), places] : foreground)
        var observations: [SenseObservation] = []
        for sense in senses {
            observations += await sense.observe(at: now)
            guard isCurrent(token) else { return }
        }
        guard let current = observations.first else { return }
        let gathered = observations
        do {
            try await store.update { state in
                guard token.isValid else { return }
                state.observations.append(contentsOf: gathered)
                let today = BudgetPolicy.day(for: now)
                var made = state.fragments.filter { $0.origin == .lived && BudgetPolicy.day(for: $0.bornAt) == today }.count
                // Daily photos/finished events must not be starved by the ever-present clock.
                let candidates = gathered.filter { $0.source.kind != .time } + gathered.filter { $0.source.kind == .time }
                for observation in candidates where made < 4 {
                    let alreadyKnown = state.fragments.contains { memory in
                        guard memory.provenance.contains(observation.source) else { return false }
                        return observation.source.kind == .photo || observation.source.kind == .calendar
                            || BudgetPolicy.day(for: memory.bornAt) == today
                    }
                    guard !alreadyKnown else { continue }
                    state.fragments.append(MemoryFragment(text: observation.text, tags: observation.tags,
                        origin: .lived, bornAt: now, timeHint: observation.timeHint,
                        placeKey: observation.placeKey, provenance: [observation.source]))
                    made += 1
                }
                MemoryPolicy.maintain(&state, now: now)
            }
        } catch { persistenceFailed = true; return }
        guard isCurrent(token) else { return }
        await reconcileNotifications()
        guard isCurrent(token), !backgroundOnly else { return }
        await ensureBudget(at: now, token: token)
        guard isCurrent(token) else { return }
        if !isQuiet(at: now) { await consider(observation: current, dreamDelivery: nil, now: now, token: token) }
        if allowDream, isCurrent(token) { await scheduleDream(after: now, token: token) }
        if isCurrent(token) { await refresh() }
    }

    private func ensureBudget(at now: Date, token: RuntimeGeneration) async {
        do {
            try await store.update { state in
                guard token.isValid, state.budget?.day != BudgetPolicy.day(for: now) else { return }
                var rng = SystemRandomNumberGenerator()
                state.budget = DailyBudget(day: BudgetPolicy.day(for: now), limit: BudgetPolicy.limit(using: &rng))
            }
        } catch { persistenceFailed = true }
    }

    private func consider(observation: SenseObservation?, dreamDelivery: Date?, now: Date, token: RuntimeGeneration) async {
        guard let state = try? await store.snapshot(), isCurrent(token),
              let budget = state.budget, budget.day == BudgetPolicy.day(for: now),
              budget.used < budget.limit else { return }
        var rng = SystemRandomNumberGenerator()
        let recall = RecallEngine.recall(state.fragments, observation: observation, at: now, random: &rng)
        let association = AssociationMaker.make(recall.selected, observation: observation, dream: dreamDelivery != nil)
        let available = await model.available
        guard isCurrent(token) else { return }
        guard available, let association else {
            record(BrainTrace(timestamp: now, observations: observation.map { [$0] } ?? [], recall: recall,
                              association: association, rawOutput: nil, result: "modelUnavailable / noGrounding", scheduledAt: nil))
            return
        }
        let raw = try? await model.respond(to: association.prompt)
        guard isCurrent(token) else { return }
        let delivery = dreamDelivery ?? now
        var recent = state.utterances
        if let pending = state.dream { recent.append(pending.utterance) }
        let result = raw.map { SpeechGate.assess($0, association: association, recent: recent,
                                                  budget: budget, now: delivery,
                                                  dream: dreamDelivery != nil) } ?? .silence(.modelUnavailable)
        switch result {
        case .silence(let reason):
            record(BrainTrace(timestamp: now, observations: observation.map { [$0] } ?? [], recall: recall,
                              association: association, rawOutput: raw, result: reason.rawValue, scheduledAt: nil))
        case .accepted(let utterance):
            let selected = Set(recall.selected.map(\.id))
            let recorded = Utterance(id: utterance.id, text: utterance.text, createdAt: delivery,
                                     sourceIDs: utterance.sourceIDs)
            do {
                try await store.update { snapshot in
                    guard token.isValid else { return }
                    if dreamDelivery == nil { snapshot.utterances.append(recorded) }
                    else { snapshot.dream = DreamUtterance(utterance: recorded, scheduledAt: delivery) }
                    snapshot.budget?.used += 1
                    for index in snapshot.fragments.indices where selected.contains(snapshot.fragments[index].id) {
                        snapshot.fragments[index].lastRecalledAt = now
                        snapshot.fragments[index].recallCount += 1
                    }
                }
            } catch { persistenceFailed = true; return }
            guard isCurrent(token) else { return }
            if dreamDelivery != nil {
                let notificationID = dreamNotificationID(recorded)
                await notifications.schedule(recorded, at: delivery, identifier: notificationID)
                guard isCurrent(token) else {
                    await notifications.removePending([notificationID]); return
                }
                record(BrainTrace(timestamp: now, observations: [], recall: recall, association: association,
                                  rawOutput: raw, result: "dream", scheduledAt: delivery))
            } else {
                await notifications.schedule(recorded, at: now.addingTimeInterval(2), identifier: utterance.id.uuidString)
                guard isCurrent(token) else {
                    await notifications.removePending([utterance.id.uuidString]); return
                }
                record(BrainTrace(timestamp: now, observations: observation.map { [$0] } ?? [], recall: recall,
                                  association: association, rawOutput: raw, result: "accepted", scheduledAt: now))
            }
        }
    }

    private func isQuiet(at date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        if quietStart == quietEnd { return false }
        if quietStart < quietEnd { return hour >= quietStart && hour < quietEnd }
        return hour >= quietStart || hour < quietEnd
    }
    private func nextDelivery(after date: Date) -> Date {
        var next = date.addingTimeInterval(4 * 3600)
        for _ in 0..<24 {
            if !isQuiet(at: next) {
                break
            }
            next = next.addingTimeInterval(3600)
        }
        return next
    }
    private func scheduleDream(after now: Date, token: RuntimeGeneration) async {
        guard let state = try? await store.snapshot(), state.dream == nil,
              let budget = state.budget, budget.used < budget.limit else { return }
        let delivery = nextDelivery(after: now)
        // A reservation belongs to its delivery day; never spend tomorrow's budget today.
        guard Calendar.current.isDate(delivery, inSameDayAs: now) else { return }
        await consider(observation: nil, dreamDelivery: delivery, now: now, token: token)
    }
    func reconcileNotifications() async {
        guard !reconcilingNotifications, !erasing else { return }
        reconcilingNotifications = true
        defer { reconcilingNotifications = false }
        let token = generation
        guard let state = try? await store.snapshot(), isCurrent(token) else { return }
        let pending = await notifications.pendingIDs()
        guard isCurrent(token) else { return }
        let expectedID = state.dream.map { dreamNotificationID($0.utterance) }
        let orphaned = pending.filter { ($0 == legacyDreamID || $0.hasPrefix("quiet-ai-dream-")) && $0 != expectedID }
        await notifications.removePending(Array(orphaned))
        guard isCurrent(token), let dream = state.dream else { return }
        let notificationID = dreamNotificationID(dream.utterance)
        let now = clock()
        if dream.scheduledAt <= now || isQuiet(at: dream.scheduledAt) {
            do {
                let shouldRecord = dream.scheduledAt <= now
                try await store.update { snapshot in
                    guard token.isValid, snapshot.dream?.id == dream.id else { return }
                    if shouldRecord, !snapshot.utterances.contains(where: { $0.id == dream.utterance.id }) {
                        snapshot.utterances.append(dream.utterance)
                    }
                    snapshot.dream = nil
                }
                await notifications.removePending([notificationID])
                if isCurrent(token) { await refresh() }
            } catch { persistenceFailed = true }
            return
        }
        guard isCurrent(token) else { return }
        if !pending.contains(notificationID) {
            await notifications.schedule(dream.utterance, at: dream.scheduledAt, identifier: notificationID)
            if !isCurrent(token) { await notifications.removePending([notificationID]) }
        }
    }
    private func record(_ trace: BrainTrace) {
        traces.append(trace)
        traces.removeAll { $0.timestamp < clock().addingTimeInterval(-72 * 3600) }
        if traces.count > 30 { traces.removeFirst(traces.count - 30) }
    }
    @discardableResult
    func erase() async -> Bool {
        guard !erasing else { return false }
        erasing = true
        resetRevision += 1
        activationRequested = false
        invalidateWork()
        defer { erasing = false }
        await notifications.removeAll()
        traces.removeAll()
        do { try await store.reset() }
        catch { persistenceFailed = true; privacyBlocked = true; return false }
        developerMode = false
        UserDefaults.standard.removeObject(forKey: "quietStart")
        UserDefaults.standard.removeObject(forKey: "quietEnd")
        UserDefaults.standard.removeObject(forKey: "activitySenseEnabled")
        UserDefaults.standard.removeObject(forKey: "weatherSenseEnabled")
        UserDefaults.standard.removeObject(forKey: "didExplainSenses")
        quietStart = 23; quietEnd = 7
        privacyBlocked = false
        persistenceFailed = false
        utterances = []; latest = nil
        return true
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
