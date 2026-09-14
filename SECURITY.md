# 静かなAI — Security & Privacy

## Principle

このアプリは大量の個人情報を読む。
したがって「外へ送らない」は機能ではなく前提条件。

## Network: forbidden by default

production codeでは原則禁止:

- URLSessionを使った外部通信
- Network.frameworkによる外部接続
- WebSocket
- remote WebView
- analytics SDK
- crash reporting SDK
- remote config
- cloud AI SDK
- ad SDK
- tracking SDK

CIにnetwork guardを置き、
上記導入を検知する。

例外を作る場合はドグマ変更級のレビューを要求する。

## Apple framework implicit network

完全オフライン保証のため、
OS frameworkが裏でネットワーク取得し得る箇所にも注意する。

### Photos

PhotoKitでiCloud downloadを許可しない。

- `isNetworkAccessAllowed = false`

端末上にないassetはスキップする。

### Music

オンラインcatalog検索はコア機能に使わない。
端末上にダウンロード済み、またはoffline動作が確認できる範囲だけ利用する。

### Maps / geocoding

オンラインmap tileやreverse geocodingへ依存しない。

## Data copies

元データは可能な限り複製しない。

保存は、

- source ID
- feature
- coarse metadata
- derived association state

を中心にする。

## Provenance

全MemoryFragmentに由来元を持たせる。

目的:

- source削除時に確実にpurge
- permission revoke時に確実にpurge
- Developer Modeでgrounding確認
- 全削除を検証

## At-rest protection

OSのData Protectionを使う。
バックグラウンド要件と両立する範囲で強いfile protectionを選ぶ。

個人データをUserDefaultsへ雑に置かない。

## Backup / sync

静かなAIの記憶DB・derived features・developer tracesは、
クラウド同期の対象にしない。

バックアップ除外を明示する。

## Logs

release buildで個人情報をConsoleへ出さない。

禁止例:

- exact coordinates
- calendar title
- health value
- photo asset metadata
- model prompt containing user data

Developer Modeでも、
保存期間を限定し、
export機能は初期仕様に入れない。

## Deletion

### Source deletion

元データが消えたら派生記憶を削除。

### Permission revoke

そのsense由来データを削除。

### Reset

全個体データを削除。

### App uninstall

以前の個体へ復帰するidentifierをKeychain等へ残さない。

## OSS

公開repoには以下を絶対に入れない。

- Provisioning profile
- signing certificate
- private key
- actual personal dataset
- actual memory DB
- exported developer trace
- personal screenshot containing private data
- model license上再配布不可なweight

モデルと3Dassetはライセンスレビューを通したものだけ配布する。
