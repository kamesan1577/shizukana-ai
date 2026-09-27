# 静かなAI — Architecture

## 1. Platform

- iOS 27
- iPhone 16 baseline
- Swift
- SwiftUI
- Xcode 27+
- Foundation Models
- Core AI
- Vision
- PhotoKit
- Core Location
- Core Motion
- EventKit
- UserNotifications
- BackgroundTasks
- RealityKit
- HealthKit (optional / policy-isolated)
- MusicKit
- MapKit (optional)

## 2. High-level pipeline

```text
Device-local signals
      ↓
Observation (short-lived)
      ↓
Memory Maker
      ↓
MemoryFragment
      ↓
Recall (5 fragments)
      ↓
Association
      ↓
SystemLanguageModel
      ↓
Speech Gate
      ↓
Utterance / SILENCE
      ↓
Local notification / specimen box
```

Observationは生値を含み得るが短命。
長期保存では情報を落としたMemoryFragmentへ変換する。
Language modelへ生活全体を渡さず、Recall後の小さなconscious stateだけを渡す。

## 3. Modules

Suggested boundaries:

```text
App/
  AppShell/
  Creature/
  SpecimenBox/
  Settings/
  Onboarding/

Core/
  Sensing/
  Memory/
  Attention/
  Cognition/
  Language/
  Utterance/
  Notifications/
  Privacy/
  Diagnostics/

Dev/
  DeveloperMode/
  Fixtures/
  DeterministicSeeds/
```

## 4. Protocol boundaries

### SenseSource

各Apple frameworkを直接全体へ漏らさない。

```swift
protocol SenseSource {
    associatedtype Event
    func bootstrap() async throws -> [Event]
    func refresh() async throws -> [Event]
}
```

### MemoryStore

保存と検索を分離。

```swift
protocol MemoryStore {
    func insert(_ fragments: [MemoryFragment]) async throws
    func candidates(for context: AttentionContext) async throws -> [MemoryFragment]
    func purge(source: SourceIdentity) async throws
    func purgeAll() async throws
}
```

### LanguageModelAdapter

モデル交換可能にする。

```swift
protocol LanguageModelAdapter {
    func utterance(from state: ConsciousState) async throws -> String
}
```

## 5. MemoryFragment

MVP v0.1:

```swift
struct MemoryFragment {
    let id: UUID
    var text: String
    var tags: [String]
    var origin: Origin
    var bornAt: Date
    var timeHint: TimeHint?
    var placeKey: String?
    var salience: Float
    var strength: Float
    var lastRecalledAt: Date?
    var recallCount: Int
    var truth: TruthType
    var provenance: Provenance
}
```

- `text` は最大64文字程度
- `tags` は3〜6個
- exact coordinateは長期記憶へ保存しない
- vector DBはMVP必須ではない
- Observationは最大72時間
- MemoryFragmentは最大1,500件
- 類似した古いfragmentはconsolidated memoryへ圧縮可能

## 6. Recall / Weak Attention

毎回5 MemoryFragmentを基本とする。

score目安:

```text
0.30 * tag_or_semantic_hint
+ 0.15 * place_match
+ 0.15 * time_or_season_match
+ 0.15 * salience
+ 0.10 * forgottenness
+ 0.15 * random_noise
- repetition_penalty
```

選択:

- 2: current contextと多少関連
- 1: 長く想起していない
- 1: random
- 1: free slot

精密検索を目的にしない。
「少し外れた記憶が混ざる」ことを品質として扱う。
fixture + seed固定時は再現可能にする。

## 7. Association

入力は、粗化したcurrent ObservationとRecallされた5断片だけ。

禁止:

- 生の巨大なmemory context
- exact location history
- full photo library
- future calendar agenda
- life-log summary

Associationはさらに情報を落とし、Speech Gateへ渡せる小さなstateへする。
この情報損失が「構造的な弱さ」の一部である。

## 8. Local language model

MVP v0.1ではFoundation Modelsの `SystemLanguageModel` を `LanguageModelAdapter` 越しに利用する。

- inferenceはオンデバイス
- cloud fallback禁止
- model unavailable時はその実行機会では黙る
- sessionは必要最小限のcontextで作る
- private user contextを外部AIへ送らない

モデルの潜在能力を低く保つことは要件ではない。
弱さはObservationの粗化、Recall件数、noise、Associationの情報損失で作る。

将来app-bundled modelへ差し替える余地は `LanguageModelAdapter` で維持する。

## 9. Image memory / fetal memory

初回はPhotoKitで許可されたassetから最大48枚をサンプルする。

- 24: 全期間へ時間的に分散
- 12: 直近90日
- 6: favorite
- 6: random

そこから12〜20程度のMemoryFragmentへ圧縮する。
人物の実名同定はしない。

画像そのものをMemory Storeへ複製することを前提にしない。
必要な処理のために一時取得してよいが、長期記憶は粗いtext/tags/time/place/provenance中心とする。

## 10. Location

位置はAI内部では人間向け住所へ過剰変換しない。

- raw location → coarse cluster
- visit / region / movement event
- relative distance
- repetition

を主に扱う。

MapKit / Apple Maps / geocodingは、UIや補助機能として必要なら利用してよい。
利用すること自体をprivacy violationとは扱わない。

AIの生活履歴やmodel contextをcustom requestへ載せない。

## 11. Background execution

任意時刻のbackground起動は前提にしない。

使う実行機会:

- Core Location Visits
- BGAppRefreshTask
- foreground opportunity
- 必要に応じてBGProcessingTask

background eventでは短時間でObservation保存と次回refresh requestを行う。
十分な実行時間がある場合だけRecall〜Speech Gateまで進める。

また、実行機会が少ない場合に備えて `DreamUtterance` を最大1件先行生成し、将来時刻のlocal notificationへ予約できる。
Dreamは記憶だけから生成し、予約後に「現在の状態」を断言しない。

## 12. Notification budget

永続状態として日次budgetを持つ。

目安:

- 0回: 20%
- 1回: 55%
- 2回: 20%
- 3回: 5%

追加rules:

- max 3/day
- minimum interval 3 hours
- 0/dayを正常系として許容
- recent utterance repetition penalty
- Speech Gateは積極的にSILENCEを選ぶ
- DreamUtteranceも同じbudgetを消費する

## 13. Creature rendering

RealityKitを第一候補にする。

要件:

- SwiftUIと統合
- 端末内asset
- toon / stylized shading
- touch hit-test
- reduced-motion mode
- deterministic test pose

必要ならcustom shaderを検討するが、
最初からMetal直書きへ行かない。

## 14. Persistence

第一候補:

- SwiftData / local SQLite-backed persistence
- Observation
- MemoryFragment
- Utterance
- DreamUtterance
- daily notification budget
- permission / source reconciliation state

Retention:

- Observation: max 72 hours
- MemoryFragment: max 1,500
- Utterance: persistent until reset
- Developer trace: short-lived / bounded

AIのMemory Storeを外部DBサーバーへ置かない。
OS-managed backup / restoreは許容する。
CloudKit等によるapp-managed memory syncはMVPに含めない。

## 15. Network / privacy boundary

ネットワークAPIの存在そのものを禁止しない。

### Allowed without product-dogma change

- OS-managed backup / restore
- iCloud-backed Apple framework access
- MapKit / Apple Maps / geocoding
- MusicKit等のApple platform service
- App Store / OSが管理する通常の配布・診断経路

### Must stay local

- memory retrieval
- attention
- association
- model input
- model inference
- utterance generation

### Review required

次を追加する場合は、送信先・送信項目・目的を `SECURITY.md` と同一PRで明文化する。

- custom `URLSession` / `Network.framework` endpoint
- third-party SDK
- app-managed cloud sync
- remote WebViewへユーザー由来データを渡す処理
- developer-controlled backend

## 16. Deterministic developer mode

本番ではnoiseを使うが、
テストではseed固定可能にする。

同じfixture + same seedなら、

- candidate selection
- association
- prompt construction

が再現できる。

モデル生成自体の非決定性は別管理。

## 17. HealthKit caveat

HealthKit由来データはAppleの利用ポリシー上、
health / fitness目的との整合が問題になり得る。

よって、

- sideload personal buildではoptional senseとして隔離
- App Store buildを検討する際はpolicy review gateを設ける
- HealthKitがなくてもコア体験が成立する

構造にする。
