import Foundation
import QuietCore
import CoreLocation
import CoreMotion
import EventKit
import Photos
import Vision
import WeatherKit

struct TimeSense: SenseSource {
    let kind: SenseKind = .time
    func observe(at date: Date) async -> [SenseObservation] {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let part = hour < 5 ? "深夜" : hour < 11 ? "朝" : hour < 16 ? "昼" : hour < 20 ? "夕方" : "夜"
        let season = ["冬", "冬", "春", "春", "春", "夏", "夏", "夏", "秋", "秋", "秋", "冬"][calendar.component(.month, from: date) - 1]
        return [SenseObservation(source: SourceRef(.time, BudgetPolicy.day(for: date)), observedAt: date,
                            text: "\(season)の\(part)", tags: [season, part, "時刻"], timeHint: part)]
    }
}

@MainActor
final class PlaceSense: NSObject, SenseSource, CLLocationManagerDelegate {
    nonisolated let kind: SenseKind = .location
    private let manager = CLLocationManager()
    private(set) var latestLocation: CLLocation?
    private var latestVisit: CLVisit?
    var onVisit: (() -> Void)?
    var isAuthorized: Bool { manager.authorizationStatus == .authorizedAlways }
    override init() { super.init(); manager.delegate = self }
    func requestPermission() {
        if manager.authorizationStatus == .notDetermined { manager.requestAlwaysAuthorization() }
        if manager.authorizationStatus == .authorizedAlways { manager.startMonitoringVisits() }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways { manager.startMonitoringVisits() }
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            latestVisit = nil; latestLocation = nil
        }
    }
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        latestVisit = visit
        latestLocation = CLLocation(latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude)
        onVisit?()
    }
    func observe(at date: Date) async -> [SenseObservation] {
        guard let visit = latestVisit, manager.authorizationStatus == .authorizedAlways else { return [] }
        // Coarse ~5 km grid; exact CLLocation never enters SenseObservation or long-term storage.
        let key = "\(Int((visit.coordinate.latitude * 20).rounded())):\(Int((visit.coordinate.longitude * 20).rounded()))"
        return [SenseObservation(source: SourceRef(.location, key), observedAt: date,
                            text: "前にいた場所の気配", tags: ["場所", "訪問", "移動"], placeKey: key)]
    }
}

struct WeatherSense: SenseSource {
    let kind: SenseKind = .weather
    let location: @Sendable () async -> CLLocation?
    func observe(at date: Date) async -> [SenseObservation] {
        guard let coordinate = await location(),
              let current = try? await WeatherService.shared.weather(for: coordinate, including: .current) else { return [] }
        let temperature = current.temperature.converted(to: .celsius).value
        let state = current.condition.description
        let warmth = temperature >= 28 ? "暑い" : temperature <= 8 ? "寒い" : "穏やか"
        return [SenseObservation(source: SourceRef(.weather, BudgetPolicy.day(for: date)), observedAt: date,
                            text: "\(warmth)日の空", tags: ["天気", warmth, String(state.prefix(20))])]
    }
}

struct ActivitySense: SenseSource {
    let kind: SenseKind = .activity
    func observe(at date: Date) async -> [SenseObservation] {
        guard UserDefaults.standard.bool(forKey: "activitySenseEnabled"),
              CMPedometer.isStepCountingAvailable() else { return [] }
        let pedometer = CMPedometer()
        let start = Calendar.current.startOfDay(for: date)
        let steps: Int? = await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: date) { data, _ in
                continuation.resume(returning: data?.numberOfSteps.intValue)
            }
        }
        guard let steps else { return [] }
        let level = steps < 2500 ? "少ない" : steps < 8500 ? "普通" : "多い"
        return [SenseObservation(source: SourceRef(.activity, BudgetPolicy.day(for: date)), observedAt: date,
                            text: "歩く量が\(level)日", tags: ["歩行", "活動", level])]
    }
}

@MainActor
final class CalendarSense: SenseSource {
    nonisolated let kind: SenseKind = .calendar
    private let store = EKEventStore()
    func requestPermission() async {
        _ = try? await store.requestFullAccessToEvents()
    }
    func observe(at date: Date) async -> [SenseObservation] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
        let start = date.addingTimeInterval(-72 * 3600)
        let predicate = store.predicateForEvents(withStart: start, end: date, calendars: nil)
        return store.events(matching: predicate).filter { $0.endDate <= date }.prefix(4).map { event in
            SenseObservation(source: SourceRef(.calendar, event.eventIdentifier ?? UUID().uuidString),
                        observedAt: event.endDate, text: "終わった用事の気配",
                        tags: ["用事", "終わり", "暦"])
        }
    }
    func containsEvent(_ id: String) -> Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess && store.event(withIdentifier: id) != nil
    }
}

@MainActor
final class PhotoSense: SenseSource {
    nonisolated let kind: SenseKind = .photo
    func requestPermission() async {
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }
    func accessibleIDs() -> Set<String> {
        guard hasAccess else { return [] }
        let results = PHAsset.fetchAssets(with: .image, options: nil)
        var ids = Set<String>()
        results.enumerateObjects { asset, _, _ in ids.insert(asset.localIdentifier) }
        return ids
    }
    private var hasAccess: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }
    func observe(at date: Date) async -> [SenseObservation] { [] }
    func selectAssets(at date: Date) -> [String] {
        guard hasAccess else { return [] }
        let results = PHAsset.fetchAssets(with: .image, options: nil)
        var candidates: [PhotoCandidate] = []
        results.enumerateObjects { asset, _, _ in
            guard let createdAt = asset.creationDate else { return }
            candidates.append(PhotoCandidate(id: asset.localIdentifier, createdAt: createdAt,
                                             favorite: asset.isFavorite))
        }
        var rng = SystemRandomNumberGenerator()
        return PrenatalSampler.sample(candidates, now: date, random: &rng).map(\.id)
    }
    func bootstrap(selection: [String], processed: Set<String>) async -> [SenseObservation] {
        guard hasAccess else { return [] }
        var observations: [SenseObservation] = []
        for id in selection where !processed.contains(id) {
            if Task.isCancelled { break }
            let results = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
            guard let asset = results.firstObject, let data = await imageData(for: asset) else { continue }
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(data: data)
            guard (try? handler.perform([request])) != nil else { continue }
            let tags = Array((request.results ?? []).filter { $0.confidence > 0.15 }.prefix(3).map(\.identifier))
            let coarse = Array((tags + ["写真", "昔", "景色"]).prefix(3))
            observations.append(SenseObservation(source: SourceRef(.photo, id), observedAt: asset.creationDate ?? Date(),
                                            text: "昔の写真に\(coarse[0])", tags: coarse))
        }
        return observations
    }
    private func imageData(for asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true // PhotoKit-managed iCloud retrieval.
            options.deliveryMode = .fastFormat
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
