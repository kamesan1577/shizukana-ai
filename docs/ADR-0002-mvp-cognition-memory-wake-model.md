# ADR-0002: MVP v0.1 cognition / memory / wake modelを固定する

Status: accepted

Date: 2026-09-28

## Context

静かなAIのコンセプトとprivacy boundaryは固まっていたが、実装に必要な以下が未確定だった。

- 何を1つの記憶として保存するか
- Recallをどの程度不完全にするか
- 「弱いAI」をmodel性能とarchitectureのどちらで作るか
- iOSのbackground execution制約下で、どう不定期発話を成立させるか
- MVPの感覚器官・発話頻度・UIをどこまでに限定するか

## Decision

### Structural weakness

MVPは `SystemLanguageModel` を利用する。
ただし生活全体をモデルへ渡さない。

弱さはObservationの粗化、Recall 5件、random noise、exact metadataの削減、Associationでの情報損失によって作る。
強いmodelへ全データを理解させ、文体だけ幼くする設計は禁止する。

### Memory

- Observation retention: max 72 hours
- MemoryFragment cap: 1,500
- MemoryFragment text: max ~64 chars
- tags: 3〜6
- exact locationはlocal place clusterへ変換
- old similar fragmentsはconsolidated memoryへ圧縮可能
- vector DBはMVP要件にしない

### Recall

毎回5件を基本とする。

- 2: current context関連
- 1: 長く想起していない
- 1: random
- 1: free slot

score目安は tag/semantic 30%, place 15%, time/season 15%, salience 15%, forgottenness 10%, random noise 15%。

### Utterance budget

- 0/day: 20%
- 1/day: 55%
- 2/day: 20%
- 3/day: 5%
- minimum interval: 3 hours
- 原則20文字以内
- userへ返答を要求しない
- advice / coaching / reminder化しない

### Background wake model

iOSに任意時刻の起動を要求しない。
Core Location Visits / BGAppRefreshTask / foreground opportunity / 必要に応じてBGProcessingTaskを実行機会として扱う。

実行機会が少ない場合に備え、記憶だけから `DreamUtterance` を最大1件先行生成し、local notificationを将来時刻へ予約できる。

### MVP senses

Photos / Time / Weather / Location / Activity / finished Calendar events。
Music / detailed Health / app usage / browser history / notification contentsはMVP外。

### Fetal memory

初回は最大48 photosをサンプルし、12〜20程度のMemoryFragmentへ圧縮する。

### UI

tab barなし。central 3D creature / latest utterance / specimen box / settings。
chat / regenerate / prompt / memory list / training feedbackなし。

### Debug Brain

Developer ModeではObservation → Recall → Association → model input/output → Speech Gate → notification scheduleまで追跡可能にする。
一般UIには説明を出さない。

## Consequences

### Positive

- model更新で基礎能力が上がっても「世界の狭さ」をarchitectureで維持できる
- background executionをOS制約と争わず、不定期性として体験へ取り込める
- memory DBを精密なlife logにせずに済む
- deterministic seedを使った調整・回帰テストが可能になる

### Trade-offs

- SystemLanguageModel unavailable時はAIが黙る
- Recall品質を検索精度だけでは評価できない
- notification timingを厳密には保証しない
- MemoryFragment consolidationで過去の細部を意図的に失う
