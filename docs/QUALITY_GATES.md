# Quality Gates

## `check`

将来 `make check` にまとめる。

必須項目:

- Swift build
- unit tests
- integration tests
- UI tests
- offline/network guard
- privacy purge tests
- dogma checks
- model fixture checks

## Offline gate

最低限、CIで以下を検知する。

- new URLSession usage
- Network.framework imports
- CloudKit imports
- analytics/crash SDK
- remote model URL
- remote WebView
- unexpected telemetry package

allowlist方式を優先する。

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
