# Quality Gates

## `check`

将来 `make check` にまとめる。

必須項目:

- Swift build
- unit tests
- integration tests
- UI tests
- privacy/network boundary guard
- privacy purge tests
- dogma checks
- model fixture checks

## Privacy / network gate

CIの目的は「ネットワークAPIを1つでも使ったら失敗」にすることではない。
**未レビューの外部送信経路を増やさないこと**を目的にする。

最低限、CIで以下を検知し、review対象にする。

- new `URLSession` usage
- `Network.framework` imports
- developer-controlled endpoint strings
- analytics / telemetry / ad SDK
- cloud AI SDK
- remote model URL
- remote WebView
- app-managed sync

allowlist方式を優先する。
allowlist entryには最低限、destination / purpose / transmitted fieldsを記録する。

以下は、それだけを理由に失敗させない。

- MapKit / Apple Maps / geocoding
- PhotoKitのiCloud-backed asset retrieval
- MusicKit等のApple platform service
- OS-managed backup / restore

ただし、Apple framework利用でも、静かなAI独自のmemory / prompt / utterance history等をcustom payloadとして送る処理はreview対象とする。

## Cognition gate

fixturesを用意し、以下を確認する。

- conscious fragmentsが3〜7
- 出力にgrounding sourceがある
- max daily notification budgetを超えない
- identical sourceばかり選ばない
- memory decayが働く
- old memory revivalが可能
- full resetでtraceが残らない
- source purgeでderived dataが残らない

文章の「賢さ」を単一golden string比較で固定しない。

## UI gate

UI変更PRは:

- iPhone 16 screenshot
- HIG review
- anti-slop review
- accessibility review

を添える。

3Dはテスト時に固定pose / seedを使い、
比較可能なスクリーンショットを作れるようにする。
