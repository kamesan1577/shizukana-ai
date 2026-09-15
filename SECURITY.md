# 静かなAI — Security & Privacy

## Principle

このアプリは大量の個人情報を読む。
したがって、**AIが観測した生活データを、アプリが勝手に外部へ持ち出さない**ことを前提条件とする。

ただし、この原則は「端末から1bitも通信してはいけない」という意味ではない。
iOS標準のバックアップや、AppleのOS / platform serviceまで一律に禁止することは目的にしない。

守るべき境界は、主に次の2つ。

1. AIの観測・記憶・推論のための個人データを、開発者サーバー、クラウドAI、広告・分析基盤、用途不明な第三者へ送らない。
2. アプリが意図的に個人データをオンラインサービスへ渡す機能を追加する場合は、送信先・送信データ・目的を明示してレビューする。

## On-device AI boundary

production pathでは、以下を端末内で完結させる。

- Memory Store
- Weak Attention
- Association
- model input construction
- language model inference
- utterance generation
- notification scheduling

禁止:

- cloud AIへ生活データやmodel inputを送る
- 開発者が管理するサーバーへ生活データを送る
- 広告SDKへ個人データを渡す
- analytics / telemetryへ生活データを渡す
- remote configのために個人データや識別子を送る
- ユーザーの記憶・写真特徴・位置履歴・Health情報等を用途不明な第三者APIへ送る

## Network policy

ネットワークアクセスそのものは全面禁止しない。

### Allowed by default

以下は、それだけを理由にドグマ違反とはしない。

- iOSが管理するbackup / restore
- ユーザーが有効にしているiCloud-backed system dataへのApple framework経由のアクセス
- MapKit / Apple Maps / geocoding等のApple platform service
- MusicKit等のApple platform service
- App Store / OSが管理する通常の配布・更新・診断経路

ただし、Apple frameworkを使う場合でも、静かなAI独自の記憶、prompt、発話履歴、生活ログ等を追加payloadとして勝手に送ってはいけない。

### Review required

以下を追加する変更は、`SECURITY.md` と仕様を同一PRで更新し、product-level reviewを行う。

- `URLSession` / `Network.framework` 等で独自endpointへ通信する
- third-party SDKを追加する
- app-managed cloud syncを追加する
- remote WebViewへユーザー由来データを渡す
- custom backendへ識別子や利用状況を送る

レビューでは最低限、次を明文化する。

- destination
- data fields
- purpose
- retention
- whether the feature works without the transfer
- user-facing disclosure / control

## Apple framework network use

### Photos

PhotoKitが、ユーザーのiCloud PhotosからOS管理でassetを取得することは許容する。

静かなAIが別サーバーへ写真や画像特徴をuploadすることは禁止する。

### Music

MusicKitのApple service利用自体は全面禁止しない。

ただし、静かなAIの記憶や他sense由来の個人データを検索query等へ混ぜない。

### Maps / geocoding

MapKit、Apple Maps、geocodingを必要に応じて利用してよい。

地図を使うこと自体をprivacy violationとは扱わない。
一方で、静かなAI独自の生活履歴、記憶、model context等をcustom requestへ載せない。

## Data minimization

「元データを絶対に複製しない」ことは目的にしない。

必要な機能、性能、復旧性のために合理的なlocal copyを持ってよい。
ただし、不要な生データの複製は避ける。

保存は可能な範囲で、

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

### OS-managed backup

iOS標準のbackup / restoreは許容する。
静かなAIのDBやderived dataを、セキュリティ上の理由だけで強制的にbackup対象外へする必要はない。

### App-managed sync

CloudKit等を使った「静かなAI自身の記憶同期」は現在の製品要件には含めない。
ただし、将来追加すること自体を永久禁止するドグマにはしない。
追加する場合は、明示的なproduct / privacy reviewとユーザー向け説明を必須とする。

## Logs

release buildで個人情報をConsoleや外部ログ基盤へ出さない。

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

OS-managed backup / restoreのライフサイクルはiOSの管理に従う。
アプリ独自の隠し復活経路は作らない。

## CI / review guard

CIは「ネットワークAPIが存在するだけで失敗」にはしない。
代わりに、app-controlled network pathをinventoryし、未レビューの外部送信経路を検出する。

最低限、次を検知・レビュー対象にする。

- new `URLSession` usage
- `Network.framework`
- third-party analytics / crash / ad SDK
- cloud AI SDK
- remote model URL
- remote WebView
- app-managed sync

Apple frameworkの通常利用やOS-managed backupは、自動的な禁止対象にしない。

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
