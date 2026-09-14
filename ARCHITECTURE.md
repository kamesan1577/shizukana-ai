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
- MusicKit (offline-safe subset only)

## 2. High-level pipeline

```text
Device-local signals
      ↓
Sense adapters
      ↓
Normalization
      ↓
Memory Store
      ↓
Weak Attention
      ↓
3–7 conscious fragments
      ↓
Association
      ↓
Small local LanguageModel
      ↓
Deterministic output gates
      ↓
Utterance record
      ↓
Local notification / specimen box
```

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

概念例:

```text
id
sourceType
sourceIdentity
capturedAt
coarseLocationCluster?
featureVector?
scalarFeatures
associationTokens
salience
provenance
```

元写真・元Healthデータ等を不必要に複製しない。

## 6. Weak Attention

完全な検索エンジンにしない。

候補スコアの概念:

```text
score =
  similarity
  + recency
  + surprise
  + sourceDiversity
  + randomNoise
  - repetitionPenalty
```

重みはDeveloper Modeから調整可能にしてよい。

### Rules

- 3〜7 fragmentを選ぶ
- 同じsourceだけで埋めない
- deterministic top-kにしすぎない
- 古い記憶にはdecay
- ただし強い類似で復活可能
- 何も引っかからない場合は喋らない

## 7. Association

Attention結果から、
モデルへ渡す情報をさらに粗くする。

モデルへ生の巨大コンテキストを渡さない。

例:

```text
time: evening
image_relation: similar_to_old
place_relation: different_cluster
age_hint: old
visual_hint: warm/red
```

意味ラベルを増やしすぎない。
「世界理解の解像度を上げる」実装はドグマ違反になり得る。

## 8. Local language model

iOS 27のFoundation Models `LanguageModel` abstractionの上に、
Core AIで変換した小型モデルを載せる構成を第一候補とする。

初期選定:

- 0.5〜1B級
- 日本語最低限
- iPhone 16で常用可能
- Core AI export可能
- 再配布可能ライセンス
- app同梱可能サイズ

最終的なモデル名はベンチマークで決める。

### Evaluation axis

賢さ最大化ではなく、

- 短い日本語を壊しすぎず出せる
- 説明しすぎない
- 与えた断片に弱く引っ張られる
- 同じ定型句を繰り返しすぎない
- iPhone 16で現実的に動く

を評価する。

## 9. Image memory

Visionのimage feature print等を使い、
画像の意味を完全な文章へ変換しない。

保存候補:

- feature vector
- simple color / luminance features
- capture timestamp
- coarse location
- PHAsset identifier

PhotoKit要求はnetwork accessを無効にし、
iCloud上にしかない画像はスキップする。

## 10. Location

位置は人間向け住所へ過剰変換しない。

- raw location → coarse cluster
- visit / region / movement event
- relative distance
- repetition

を主に扱う。

reverse geocoding等のネットワーク依存処理は使わない。

## 11. Background execution

iOSのbackground executionは時刻保証されない前提で設計する。

使い分け:

- Core Location event
- BGAppRefreshTask
- BGProcessingTask
- foreground opportunity

実行可能なタイミングで、

1. 新しい断片を取り込む
2. Attention判定
3. 必要なら発話生成
4. Local notificationを将来時刻へschedule

する。

「完全にランダムな時刻へ必ず発火」は保証しない。
ユーザー体験として不定期に見えればよい。

## 12. Notification budget

永続状態として当日発話数を持つ。

- default max: 3/day
- 0/dayを許容
- silent streakを許容
- repetition penaltyを持つ

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
- vector/scalarはlocal blob/dataで保持
- 必要ならAccelerateで類似計算

外部DBサーバーは禁止。

## 15. Deterministic developer mode

本番ではnoiseを使うが、
テストではseed固定可能にする。

同じfixture + same seedなら、

- candidate selection
- association
- prompt construction

が再現できる。

モデル生成自体の非決定性は別管理。

## 16. HealthKit caveat

HealthKit由来データはAppleの利用ポリシー上、
health / fitness目的との整合が問題になり得る。

よって、

- sideload personal buildではoptional senseとして隔離
- App Store buildを検討する際はpolicy review gateを設ける
- HealthKitがなくてもコア体験が成立する

構造にする。
