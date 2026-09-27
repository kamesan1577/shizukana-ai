import SwiftUI
import RealityKit
import QuietCore
import UserNotifications
import Photos
import EventKit

struct RootView: View {
    @Bindable var runtime: CreatureRuntime
    @Bindable var notificationRouter: NotificationRouter
    @AppStorage("didExplainSenses") private var didExplainSenses = false
    @State private var showSettings = false
    @State private var showSpecimens = false
    @State private var showNotificationDetail = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { showSpecimens = true } label: { Image(systemName: "square.stack") }
                        .accessibilityLabel("発話標本箱")
                        .frame(width: 44, height: 44)
                    Spacer()
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("設定")
                        .frame(width: 44, height: 44)
                }
                .font(.title3)
                .buttonStyle(.plain)
                .frame(height: 52)
                .padding(.horizontal, 24)
                Spacer(minLength: 0)
                CreatureView(reduceMotion: reduceMotion)
                    .frame(height: 330)
                    .accessibilityLabel("深海に漂う個体。触れると身を縮めます")
                Spacer(minLength: 0)
                Text(runtime.latest?.text ?? "")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 68)
                    .accessibilityLabel(runtime.latest?.text ?? "まだ言葉はありません")
                if !runtime.modelReady {
                    Text("この端末では、まだ声を作れません")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .tint(.primary)
        .sheet(isPresented: $showSettings) { SettingsView(runtime: runtime) }
        .sheet(isPresented: $showSpecimens) { SpecimenView(runtime: runtime) }
        .sheet(isPresented: $showNotificationDetail) {
            NavigationStack {
                if let selected = runtime.utterances.first(where: { $0.id == notificationRouter.selectedID }) {
                    SpecimenDetail(utterance: selected, store: runtime.store)
                }
            }
        }
        .onChange(of: notificationRouter.selectedID) { _, id in showNotificationDetail = id != nil }
        .task { if notificationRouter.selectedID != nil { showNotificationDetail = true } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await runtime.reconcileSources(); await runtime.reconcileNotifications(); await runtime.refresh() } }
        }
        .sheet(isPresented: Binding(get: { !didExplainSenses }, set: { if !$0 { didExplainSenses = true } })) {
            NavigationStack {
                ScrollView { VStack(alignment: .leading, spacing: 24) {
                    Text("静かなAI").font(.largeTitle)
                    Text("この生き物は、あなたの生活の断片を見ます。")
                    Text("記憶や推論のために、生活データを外部AIや開発者サーバーへ送りません。感覚は後から一つずつ選べます。")
                        .foregroundStyle(.secondary)
                    Button("はじめる") { didExplainSenses = true }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                } }
                .padding(30)
            }
            .interactiveDismissDisabled()
        }
    }
}

struct CreatureView: View {
    let reduceMotion: Bool
    @State private var recoil = false
    var body: some View {
        RealityView { content in
            let body = ModelEntity(mesh: .generateSphere(radius: 0.65),
                materials: [SimpleMaterial(color: UIColor(red: 0.08, green: 0.29, blue: 0.29, alpha: 0.72), isMetallic: false)])
            body.name = "membrane"
            body.components.set(InputTargetComponent())
            body.generateCollisionShapes(recursive: true)
            let core = ModelEntity(mesh: .generateSphere(radius: 0.27),
                materials: [SimpleMaterial(color: UIColor(red: 0.05, green: 0.16, blue: 0.18, alpha: 1), isMetallic: false)])
            core.position = [0.05, -0.08, 0.32]
            body.addChild(core)
            content.add(body)
        } update: { content in
            if let entity = content.entities.first {
                entity.transform.scale = recoil ? SIMD3<Float>(0.89, 0.94, 0.89) : SIMD3<Float>(1, 1, 1)
                entity.transform.rotation = simd_quatf(angle: recoil ? 0.18 : 0, axis: [0, 1, 0])
            }
        }
        .onTapGesture {
            recoil = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 80 : 420))
                recoil = false
            }
        }
        .accessibilityAddTraits(.isButton)
    }
}

struct SpecimenView: View {
    let runtime: CreatureRuntime
    var body: some View {
        NavigationStack {
            List(runtime.utterances) { utterance in
                NavigationLink {
                    SpecimenDetail(utterance: utterance, store: runtime.store)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(utterance.createdAt, format: .dateTime.year().month().day().hour().minute())
                            .font(.footnote).foregroundStyle(.secondary)
                        Text(utterance.text)
                    }
                }
            }
            .overlay { if runtime.utterances.isEmpty { ContentUnavailableView("まだ標本はありません", systemImage: "square.stack") } }
            .navigationTitle("標本箱")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SpecimenDetail: View {
    let utterance: Utterance
    let store: any MemoryStore
    @State private var vagueTrace = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text(utterance.text).font(.title2)
            Text(utterance.createdAt, format: .dateTime.year().month().day().hour().minute())
                .foregroundStyle(.secondary)
            if !vagueTrace.isEmpty { Text(vagueTrace).foregroundStyle(.tertiary) }
            Spacer()
        }.frame(maxWidth: .infinity, alignment: .leading).padding()
            .task(id: utterance.id) {
                guard let snapshot = try? await store.snapshot() else { return }
                let ids = Set(utterance.sourceIDs)
                let tags = snapshot.fragments.filter { ids.contains($0.id) }.flatMap(\.tags)
                vagueTrace = Array(Set(tags)).sorted().prefix(2).joined(separator: " ・ ")
            }
    }
}

struct SettingsView: View {
    @Bindable var runtime: CreatureRuntime
    @State private var versionTaps = 0
    @State private var confirmErase = false
    @State private var permissionRevision = 0
    @AppStorage("weatherSenseEnabled") private var weatherEnabled = false
    var body: some View {
        NavigationStack {
            Form {
                Section("感覚") {
                    Button {
                        Task { await runtime.photos.requestPermission(); await runtime.bootstrap(); permissionRevision += 1 }
                    } label: { LabeledContent("写真", value: photoStatus) }
                    Button { runtime.places.requestPermission(); permissionRevision += 1 }
                        label: { LabeledContent("場所", value: runtime.places.permissionDescription) }
                    Text("天気にはWeatherKit対応の署名が必要です。許可された現在地をAppleに渡して取得します。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Toggle("天気", isOn: $weatherEnabled)
                    LabeledContent("時刻", value: "常に利用")
                    Button {
                        Task {
                            if await ActivityPermission.request() {
                                UserDefaults.standard.set(true, forKey: "activitySenseEnabled")
                                permissionRevision += 1
                            }
                        }
                    } label: { LabeledContent("活動", value: UserDefaults.standard.bool(forKey: "activitySenseEnabled") ? "許可済み" : "未設定") }
                    Button { Task { await runtime.calendar.requestPermission(); permissionRevision += 1 } }
                        label: { LabeledContent("カレンダー", value: EKEventStore.authorizationStatus(for: .event) == .fullAccess ? "許可済み" : "未設定") }
                    Link("iOSの権限設定を開く", destination: URL(string: UIApplication.openSettingsURLString)!)
                }
                Section("通知") {
                    Button("通知を許可") {
                        Task { _ = try? await UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .sound, .badge]) }
                    }
                    Picker("静かな時間の開始", selection: $runtime.quietStart) {
                        ForEach(0..<24) { Text("\($0):00").tag($0) }
                    }
                    Picker("静かな時間の終了", selection: $runtime.quietEnd) {
                        ForEach(0..<24) { Text("\($0):00").tag($0) }
                    }
                }
                Section("この個体") {
                    Button("この子の記憶をすべて消す", role: .destructive) { confirmErase = true }
                    Button("Version 0.1") {
                        versionTaps += 1
                        if versionTaps >= 7 { runtime.developerMode = true }
                    }.foregroundStyle(.secondary)
                }
                if runtime.developerMode {
                    Section { NavigationLink("Debug Brain") { DebugBrainView(runtime: runtime) } }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .alert("この子の記憶をすべて消しますか", isPresented: $confirmErase) {
                Button("消す", role: .destructive) { Task { await runtime.erase() } }
                Button("やめる", role: .cancel) {}
            } message: { Text("記憶、標本、予約中の発話が消えます。元に戻せません。") }
        }
        .id(permissionRevision)
    }

    private var photoStatus: String {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized: "許可済み"
        case .limited: "選択した写真のみ"
        case .denied, .restricted: "許可なし"
        default: "未設定"
        }
    }
}

import CoreMotion
private enum ActivityPermission {
    static func request() async -> Bool {
        guard CMPedometer.isStepCountingAvailable() else { return false }
        let pedometer = CMPedometer()
        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: Date().addingTimeInterval(-60), to: Date()) { _, error in
                continuation.resume(returning: error == nil)
            }
        }
    }
}

struct DebugBrainView: View {
    let runtime: CreatureRuntime
    var body: some View {
        List(runtime.traces.reversed()) { trace in
            Section(trace.timestamp.formatted()) {
                LabeledContent("SenseObservation", value: trace.observations.map(\.text).joined(separator: ", "))
                LabeledContent("Candidates", value: "\(trace.recall?.candidates.count ?? 0)")
                ForEach(trace.recall?.candidates ?? [], id: \.id) { score in
                    LabeledContent(score.id.uuidString.prefix(8).description,
                                   value: String(format: "%.2f (noise %.2f)", score.total, score.noise))
                }
                LabeledContent("Selected", value: trace.recall?.selected.map(\.text).joined(separator: " / ") ?? "")
                LabeledContent("Association", value: trace.association?.text ?? "")
                LabeledContent("Model input", value: trace.association?.prompt ?? "")
                LabeledContent("Model output", value: trace.rawOutput ?? "")
                LabeledContent("Gate", value: trace.result)
                if let date = trace.scheduledAt { LabeledContent("Scheduled", value: date.formatted()) }
            }
        }.navigationTitle("Debug Brain")
    }
}
