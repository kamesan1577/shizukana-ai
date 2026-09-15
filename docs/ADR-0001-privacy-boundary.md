# ADR-0001: 「完全オフライン」から明示的なプライバシー境界へ

Status: accepted

Date: 2026-09-15

## Context

静かなAIは写真、位置、Calendar、Health等の強い個人情報へアクセスする。
初期仕様では安全側に倒し、アプリ全体を「完全オフライン」と定義していた。

その結果、次まで一律禁止する設計になっていた。

- iOS標準のbackup / restore
- PhotoKitのiCloud-backed asset retrieval
- MapKit / Apple Maps / geocoding
- MusicKit等のApple platform service
- network APIの存在そのもの

しかし、本当に守りたい境界は「ネットワークを一切使わないこと」ではない。
静かなAIが観測した生活データを、開発者サーバー、クラウドAI、広告・分析基盤、用途不明な第三者へ勝手に送らないことである。

通信ゼロを目的化すると、通常のiOS機能や復旧性まで不必要に犠牲にし、将来の実装判断も手段ベースで硬直する。

## Decision

「完全オフライン」をproduct invariantから外す。

代わりに、次を不変条件とする。

1. Memory Store、Weak Attention、Association、model input construction、language model inference、utterance generationはオンデバイスで完結する。
2. AIが観測したユーザー由来の個人データを、開発者サーバー、クラウドAI、広告・分析基盤、用途不明な第三者へ送らない。
3. iOS標準のbackup / restoreとApple platform serviceは、それだけを理由に禁止しない。
4. アプリが意図的に個人データをonline serviceへ渡す新規機能は、destination / fields / purpose / retention / user controlを明示してproduct-level privacy reviewを行う。
5. CIはnetwork APIの全面禁止ではなく、未レビューのapp-controlled external data pathを検出する。

## Allowed examples

- iOS標準backup / restore
- iCloud-backed PhotoKit asset retrieval
- MapKit / Apple Maps / geocoding
- MusicKit等のApple platform service
- App Store / OSが管理する通常の配布・診断経路

これらの利用時も、静かなAI独自のmemory、prompt、utterance history、生活ログ等を追加payloadとして勝手に送らない。

## Still prohibited

- cloud inference
- developer backendへの生活データupload
- analytics / telemetryへの生活データ送信
- ad SDKへの個人データ送信
- unreviewed third-party SDK / APIへのユーザー由来データ送信
- remote modelへの個人context送信

## Consequences

### Positive

- iOS標準の復旧性を壊さずに済む。
- MapKit等のApple APIを、必要性に応じて普通に採用できる。
- privacy reviewが「どのAPIを使ったか」ではなく「何をどこへ送るか」に集中する。
- 将来の実装が不必要に特殊化しない。

### Trade-offs

- READMEやonboardingで「このiPhoneから一切データが出ない」とは表現できない。
- ネットワーク利用を追加するPRでは、データフローを明示する必要がある。
- Apple platform serviceとcustom third-party transferの境界をreviewで維持する必要がある。

## User-facing promise

推奨する説明は次の意味に揃える。

> AIの記憶や推論のために、あなたの生活データを外部AIや開発者サーバーへ送りません。

「完全オフライン」「端末外へ一切出ない」といった、OS-managed backupやplatform serviceまで含めて否定する表現は使わない。
