# 静かなAI 開発入口

チャット履歴を仕様として必要としない。
作業開始時に、必ず以下を順に読む。

1. `spec/invariants/README.md`
2. `spec/current/README.md`
3. `HANDOFF.md`
4. 変更内容に応じて `DESIGN.md` / `SECURITY.md` / `ARCHITECTURE.md`
5. 関連ADR
6. コードとテスト

## 最上位ルール

`spec/invariants/README.md` はこのプロジェクトの憲法である。

実装上の都合、一般的なAIアプリの慣習、便利さ、モデル性能、外部ライブラリの都合が
ドグマと衝突した場合、**ドグマを変えるのではなく実装を変える**。

特に次を禁止する。

- 静かなAIを便利なチャットアシスタントにする
- ユーザーから「今しゃべって」と発話させる
- 強いAIが赤ちゃんを演技する設計にする
- 正確なライフログ要約へ寄せる
- クラウド推論・外部API・テレメトリを追加する
- 「成長して賢くなる」育成ゲームへ寄せる

## 変更ルーティング

- AI・記憶・Attention・発話を変更する:
  - `.codex/skills/quiet-ai-dogma/SKILL.md`
  - `.codex/skills/quiet-ai-cognition/SKILL.md`
- UI・3D・モーション・通知導線を変更する:
  - `.codex/skills/quiet-ai-dogma/SKILL.md`
  - `.codex/skills/quiet-ai-design-contract/SKILL.md`
  - Apple HIG skill
  - anti-slop skill
- 位置・写真・HealthKit・Calendar等のデータを変更する:
  - `.codex/skills/quiet-ai-data-safety/SKILL.md`
- 公開・配布・CIを変更する:
  - `SECURITY.md`
  - `ARCHITECTURE.md`

## UI変更の必須手順

1. `DESIGN.md` を読む。
2. Apple Human Interface Guidelines を一次基準として確認する。
3. anti-slop を通し、典型的な生成AI風UIを排除する。
4. iPhone 16 / iOS 27 Simulator で実画面を確認する。
5. Dynamic Type / VoiceOver / Reduce Motion を確認する。
6. PRにスクリーンショットを添える。

HIGとanti-slopが衝突した場合は **HIGが優先**。
anti-slopはスタイルガイドではなく、雑なAI生成UIを弾くフィルタとして扱う。

## 品質

- 仕様変更は仕様ファイルと同一変更で反映する。
- 設計変更はADRに残す。
- 不具合は再現テストを先に置く。
- 失敗をskip/retryで隠さない。
- テスト未実施を成功と書かない。
- ネットワークアクセスを新設する変更は原則禁止。
- 個人データ、モデル入力、デバッグログ、実端末由来データをコミットしない。

## 完了条件

コード・仕様・UI・テスト・プライバシー境界が一致し、
ドグマ違反がなく、対象端末で確認できたものだけを完了とする。
