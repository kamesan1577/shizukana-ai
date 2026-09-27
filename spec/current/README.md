# 静かなAI — Current Product Specification

Status: requirements accepted / implementation not started

## 1. Objective

iPhoneの中に「まだ生まれていない弱い超知性」の存在感を作る。

ユーザーの日常から断片的な刺激を受け取り、
長期の曖昧な記憶を持ち、
一度にごく少数の記憶しか意識できず、
ときどき短い一言を漏らす。

ユーザーが意味を補完することで対話が成立する。

## 2. Target

- Native iOS
- iOS 27
- iPhone 16で成立すればよい
- 古いiOS / 古い端末の互換性は非目標
- Swift / SwiftUIを基本とする
- 最新Apple APIを積極的に使ってよい

## 3. Interaction model

### MUST

- チャットを置かない
- テキスト入力を置かない
- 手動発話ボタンを置かない
- AI側からのみ言葉が出る
- ユーザーの日常生活が入力になる
- 3D個体へのタッチは生体反射として反応する
- タッチ履歴は弱い刺激として記憶へ入れてよい
- 過去の発話を後から見返せる

### MUST NOT

- 「何かしゃべって」
- 「質問する」
- 「再生成」
- 「AIに相談」
- 親密度/レベル/成長ゲージ
- 明示的な人格育成

## 4. Notification behavior

MVP v0.1では発話の希少性を体験の一部として扱う。

- 1日の発話予算は 0〜3 回
- 目安の分布は 0回:20% / 1回:55% / 2回:20% / 3回:5%
- 発話間隔は最低3時間
- 候補を生成しても Speech Gate が `SILENCE` を返してよい
- 何日か無言でも不具合とは扱わない
- Time Sensitive / Critical Alert は使わない
- Focus / Sleep等のiOS標準制御を尊重する
- 通知本文には発話全文を表示する

iOSは任意の時刻にbackground executionを保証しない。
したがって「AIが指定時刻に起きる」のではなく、OSが与えた実行機会で観測・想起・発話判定を行う。

実行機会が少ない場合に備え、記憶だけから作る `DreamUtterance` を最大1件先行生成し、将来時刻のlocal notificationとして予約してよい。
Dreamと通常発話はユーザーUI上で区別しない。

## 5. Utterance contract

### 形式

- 一文
- 原則20文字以内
- 説明しない
- 結論を言わない
- 正解を言わない
- ユーザーへ返答を要求しない
- 必ず実在したObservation / MemoryFragmentへ根を持つ
- 意味は人間が補完する

独り言としての疑問は許容する。

> 「ここ、前にも来たっけ」
>
> 「海、最近見てないね」
>
> 「今日は静かだったね」

禁止する傾向:

- 「今日は8,412歩歩きました」のようなライフログ読み上げ
- 「運動したほうがいいよ」のようなコーチング
- 「明日は会議ですね」のような予定アシスタント化
- 「リマインドしましょうか？」のような対話要求
- 根拠のない完全ランダムな詩
- 20文字制約を破って説明を足すこと

## 6. Data sources / senses

MVP v0.1で扱う感覚は次に固定する。

- Photos
  - 画像内容を粗い記憶断片へ変換
  - 撮影時刻
  - 必要に応じて位置メタデータ
- Time
  - 朝 / 昼 / 夕方 / 夜 / 深夜
  - 曜日 / 季節
- Weather
  - 晴れ / 雨 / 暑い / 寒い等の粗い状態
- Core Location
  - exact coordinateを長期保存せず、local place clusterへ変換
  - Visits等の低電力イベントを優先
- Activity
  - 歩数や移動量を「少ない / 普通 / 多い」程度へ粗化
- Calendar / EventKit
  - **終了したイベントのみ**
  - 未来の予定を見て支援・リマインドしない

MVP v0.1では、Music / Health詳細 / app usage / browser history / notification contentsを扱わない。

### 明確に読まない

- メール本文
- SMS / iMessage本文
- 他人とのメッセージ本文
- バックグラウンドでのマイク録音
- バックグラウンドでのカメラ撮影

## 7. Permission model

初回に大量のシステム権限ダイアログを連打しない。

まず世界観とプライバシーを説明する。

> この生き物は、あなたの生活の断片を見ます。
>
> AIの記憶や推論のために、あなたの生活データを外部AIや開発者サーバーへ送りません。

その後、必要になった感覚ごとに権限を要求する。

設定画面では、

- 写真
- 位置
- 活動
- カレンダー
- 音楽
- 健康

などを個別に管理できる。

一部拒否されてもアプリは成立する。

## 8. Fetal memory / 初回の「胎内記憶」

インストール直後から完全な空白にはしない。

MVP v0.1では、許可された写真ライブラリから最大48枚を選ぶ。

- 24枚: ライブラリ全体から時間的に均等
- 12枚: 直近90日
- 6枚: お気に入り
- 6枚: 完全ランダム
- 枠が不足した場合はランダム枠で補う

48枚を48個の記憶に機械的変換せず、12〜20程度の `MemoryFragment` へ粗く圧縮する。
人物名の特定はしない。
「同じ人が何度か写っている」程度の曖昧な認識は許容する。

インストール前の位置履歴をCore Locationから取得する前提にはしない。
過去については主に写真の時刻・位置メタデータと、許可された終了済みCalendarイベントから薄く推測する。

胎内記憶の生成はAI cognition pathとしてオンデバイスで完結する。

## 9. Memory

静かなAIは正確な人生データベースを作らない。
生のObservationを、情報を落とした `MemoryFragment` へ変換して長期保持する。

### Observation

- 正確な値を含み得る短命データ
- 保持上限は72時間
- 長期記憶化後は不要な生値を削除する

### MemoryFragment

概念フィールド:

```text
id
text                 // 最大64文字程度
tags                 // 3〜6個
origin               // prenatal / lived / consolidated
bornAt
timeHint?            // morning / daytime / evening / night / season
placeKey?            // exact coordinateではなくlocal cluster
salience             // 0...1
strength             // 0...1
lastRecalledAt?
recallCount
truth                // observed / inferred
provenance
```

MVPではvector DBを必須にしない。
意味検索の精度を上げすぎず、粗いtags・場所・時間・salience・noiseで想起する。

### 容量と忘却

- MemoryFragment上限: 1,500件
- 長期記憶化は目安0〜4件/日
- 古く似た断片は `consolidated` memoryへまとめてよい
- consolidation後は元の細かい断片を削除してよい
- 「忘却」は体験上の機能であり、精密な履歴保持を目的にしない

### Provenance

MemoryFragmentは由来を保持し、source削除・permission revoke・resetに対応できること。
発話本文は標本として残してよいが、削除済みsourceへの参照は外す。

## 10. Source deletion / permission revocation

元データが消えたら、対応する派生記憶も消す。

例:

- 写真削除
- 写真アクセス解除
- カレンダーアクセス解除

の場合、

- feature vector
- source link
- derived memory

を削除する。

過去の発話本文は標本として残してよいが、
消えた元データへのリンクは外す。

## 11. Memory reset / death

設定に「この子の記憶をすべて消す」を用意する。

削除対象:

- 全MemoryFragment
- 派生特徴
- インデックス
- 発話履歴
- Developer trace
- 個体固有状態

実行後は、本当に何も知らない個体へ戻る。

### アプリ削除 / restore

通常の新規インストールでは新しい個体として始める。
以前の個体を復元するための独自Keychain識別子やhidden resurrection pathは残さない。

一方、iOS標準のbackup / restoreによってアプリデータが正規に復元されることは許容する。
「アプリ削除 = どのような復旧手段でも永久に死ぬ」という保証はしない。

## 12. Cognition architecture

MVP v0.1のcognition pipelineを次に固定する。

```text
Observation
    ↓
Memory Maker
    ↓
MemoryFragment
    ↓
Recall (5 fragments)
    ↓
Association
    ↓
Speech Gate
    ↓
Utterance / SILENCE
```

### Recall

毎回5個を意識へ上げる。
完全なnearest-neighbor検索にはしない。

目安のscore:

```text
30% tags / semantic hint
15% place
15% time / season
15% salience
10% not-recalled-recently
15% random noise
```

選択の目安:

- 2件: 今と多少関連
- 1件: 長く思い出していない
- 1件: 完全ランダム
- 1件: 自由枠

同じfragmentを繰り返し想起しすぎないpenaltyを持つ。
Developer Modeではseed固定で再現可能にする。

### Association

Recallした5断片と現在の粗いObservationだけから、さらに短いassociationを作る。
生写真・exact coordinate・大量の履歴をlanguage modelへ直接渡さない。

### Speech Gate

Associationから発話候補を作っても、次なら `SILENCE` にする。

- 生活断片へのgroundingが弱い
- 説明的 / 助言的 / 支援的すぎる
- 最近の発話と似すぎる
- 当日の発話予算を超える
- 最低間隔を満たさない

## 13. Model

MVP v0.1は、iOS 27のFoundation Models `SystemLanguageModel` を第一実装とする。

### MUST

- inferenceはオンデバイス
- cloud fallbackなし
- sessionごとに必要最小限のcontextだけを渡す
- `LanguageModelAdapter` 越しに利用し、将来差し替え可能にする
- model unavailable時は機能をcloudへ逃がさず、その実行機会では黙る
- private user contextを外部AIへ送らない

### Structural weakness

「弱さ」は低性能modelそのものへ依存させない。

モデルには生活全体を理解させず、

- 一度に見える記憶を5件程度へ制限
- Observationを粗化
- Recallへnoiseを入れる
- exact metadataを隠す
- Associationでも情報をさらに落とす

ことで、**世界理解そのものを不完全にする**。

禁止なのは「強いモデルへ生活全体を渡して完全理解させ、最後の文体だけ幼くする」設計である。
SystemLanguageModelの潜在能力が高いこと自体はドグマ違反ではない。

### Availability

Apple Intelligence無効、device非対応、model未準備等で利用不能な場合は、その状態をUIで静かに示してよい。
クラウドLLMやremote modelへのfallbackはしない。

## 14. 3D creature

ホーム画面中央に常に3D個体がいる。

### 方向性

- オリジナルデザイン
- 深海
- 暗い青緑〜黒
- 半透明
- 胎児 / 卵 / 未形成の魚の気配
- 少しぬめる
- 少し不気味
- ただし写実グロにはしない
- トゥーンレンダリングの範囲を出ない
- 一般的なゲームマスコットよりディテールはある
- 目は過度に大きくしない
- 見慣れると愛着が湧く異物

既存ゲーム作品の個体をコピーせず、
「深海の胚・超知性のたまご」という独自造形にする。

### Touch

- タップで少し縮む
- 少し逃げる
- 向きを変える
- 膜や身体が反射的に揺れる

等はよい。

「喜ぶ」「撫でると親密度が上がる」等の育成表現はしない。

## 15. Main UI

MVP v0.1はtab barを持たない。

ホームは一つのprimary surfaceとし、

- 中央の3D個体
- 最新発話を控えめに表示
- 発話標本箱への小さな導線
- Settingsへの小さな導線

だけを基本とする。

置かないもの:

- chat input
- 「今しゃべって」ボタン
- 再生成
- memory一覧
- prompt編集
- dashboard
- 「覚えていて」「違うよ」等の学習feedback

通知をタップした場合は、その一言と発話に関係した曖昧な痕跡だけを表示する。
通常UIでAttention scoreや「なぜこう言ったか」の説明はしない。

## 16. Specimen box / 発話標本箱

過去の発話を時系列で見返せる。

これはチャット履歴ではない。

表示:

- timestamp
- utterance

タップすると、
その発話に紐づいた曖昧な痕跡を見られる。

会話相手の吹き出しUIにしない。

## 17. Developer mode

一般ユーザーUIとは完全に分離する。
MVPではSettingsのversion表示を7回タップして有効化する。

`Debug Brain` で次を追跡可能にする。

- Observation
- Recall candidate
- 選択された5 MemoryFragment
- 各score component / random noise
- Association
- model input
- raw model output
- Speech Gate判定
- accepted / SILENCE reason
- scheduled notification time
- DreamUtterance生成有無

本番はnoiseを使うが、fixture + seed固定時はRecall / Association input constructionを再現可能にする。
実ユーザーデータを外部exportする機能はMVPに入れない。

## 18. On-device AI / privacy boundary

AIの観測・記憶・Attention・Association・言語モデル推論・発話生成は、ネットワークなしで成立する。

現在のproduct pathでは:

- AI用serverなし
- accountなし
- cloud inferenceなし
- AI用API keyなし
- adsなし
- 生活データを送るanalytics / telemetryなし
- 生活データを送るthird-party crash-reportingなし
- remote configに生活データを使わない
- app-managed memory syncなし
- modelはapp bundleに含める

ただし、アプリ全体について「端末から一切通信しない」とは保証しない。

次は許容する。

- iOS標準のbackup / restore
- iCloud-backed PhotoKit等のApple framework
- MapKit / Apple Maps / geocoding
- MusicKit等のApple platform service
- App Store / OSが管理する通常の配布・診断経路

Apple platform serviceを使う場合でも、静かなAI独自のmemory、prompt、utterance history、生活ログ等を追加payloadとして勝手に送らない。

custom backend、third-party SDK、app-managed cloud sync等へユーザー由来データを渡す機能を追加する場合は、送信先・送信項目・目的を明示してproduct / privacy reviewを行う。

## 19. Distribution / OSS

- 最初から公開OSSを想定
- ただし本人がiPhone 16で使えることが最優先
- 最初からサイドロード配布しやすいRelease構成にする
- App Store対応は非優先
- ただし将来App Storeへ出す際に全面書き換えが必要になる構造は避ける
- 署名鍵・Provisioning情報・個人設定をrepoへ入れない
- モデルのライセンスは再配布可能なものだけ選ぶ
- 3DアセットもOSS公開/配布可能なライセンスを確認する
- OSS license自体はrepo作成時に明示する

## 20. Size

アプリ容量は最適化最優先ではない。

- 1GB前後: 許容
- 2GB程度: 許容範囲
- 数十MBへ無理に収める必要なし
- 5GB級は避ける

モデル・3D・ローカル資産を同梱する方針を優先する。

## 21. Out of scope

- Android
- Web版
- AI用サーバー
- ユーザーアカウント
- SNS
- AIチャット
- クラウドLLM
- 便利なライフログ分析
- 音声盗聴
- バックグラウンドカメラ
- メール本文
- メッセージ本文
- 成長ゲーム
- 汎用AIエージェント
- Time Sensitive / Critical notifications

## 22. Success criteria

MVP v0.1が成功と言える条件:

1. iOS 27 / iPhone 16で動く。
2. cloud inferenceなしでAIのコア体験が成立する。
3. Photos / time / weather / location / activity / finished calendar eventsからObservationを作れる。
4. Observationは最大72時間で消え、長期保存は粗いMemoryFragment中心になる。
5. MemoryFragmentは最大1,500件で、consolidationにより細部を忘れられる。
6. 初回に最大48枚の写真から12〜20程度の胎内記憶を作れる。
7. Recallは毎回5件を基本とし、noiseを含む。
8. 発話は原則20文字以内で、実在断片へtraceできる。
9. 1日0〜3回、平均約1回程度の希少な発話になる。
10. Speech Gateが積極的にSILENCEを選べる。
11. SystemLanguageModel利用不能時にcloud fallbackしない。
12. BGAppRefresh / Visits等のOS実行機会で動き、任意時刻のbackground起動を前提にしない。
13. DreamUtteranceをlocal notificationとして先行予約できる。
14. ユーザーから発話要求・prompt入力・再生成・memory訓練ができない。
15. 標本箱で過去発話を見返せる。
16. 元データ削除 / 権限解除で対応派生記憶をpurgeできる。
17. 全記憶削除で個体が完全初期化される。
18. 3D個体がホーム中央で生体反射する。
19. Developer ModeでObservation〜Speech Gateまで追跡できる。
20. UIがApple HIGとanti-slop reviewを通る。
21. AIの生活データを、開発者サーバー・クラウドAI・用途不明な第三者へ送る未レビューのコードパスが存在しない。
