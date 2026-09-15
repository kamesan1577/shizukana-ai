# 静かなAI — Design Contract

## Authority order

デザイン判断の優先順位:

1. `spec/invariants/README.md`
2. Apple Human Interface Guidelines
3. この `DESIGN.md`
4. anti-slop filter
5. 実装都合

HIGとanti-slopが衝突した場合はHIGを優先する。

## Design goal

**プロのiOSプロダクトデザイナーが、Appleのプラットフォーム文法の中で、
ひとつだけ異物を飼っているような画面を作った状態。**

普通のiOSアプリ部分は極めて自然。
異質なのは中央の生物だけ。

UI全体までSF・サイバー・AI風にしない。

## Visual identity

- deep sea
- quiet
- dark
- biological
- unborn
- wet but toon-shaded
- eerie, not horror
- restrained
- tactile
- high craft

### Creature

- 中央に3D
- 未形成の魚 / 胚 / 卵
- 暗い深海色
- 半透明
- 内部発光は控えめ
- 少しグロい
- ただし写実的な血肉にはしない
- トゥーンレンダリング
- 大きすぎる目は禁止
- キャラクターグッズ的な可愛さへ寄せない

## Apple-native first

UIはSwiftUIのネイティブコンポーネントを第一選択とする。

- NavigationStack
- List / Form
- native sheets
- system typography
- semantic colors
- SF Symbols
- standard permission flows
- system notification behavior

独自コントロールは、
生物表現や世界観上必要な場合だけ作る。

## Liquid Glass

iOS 27のLiquid Glassは積極的に使ってよいが、
**Appleが想定する階層・ナビゲーション・コントロール表現として使う**。

禁止:

- 何でも半透明カードにする
- 全画面glassmorphism
- 読みにくさを世界観として正当化する
- glass + glow + gradientを重ねて「AI感」を出す

## Anti-slop rules

禁止傾向:

- 青紫AIグラデーション
- 意味のない発光
- カードの中にカード
- すべて角丸コンテナ
- 丸い四角の中にアイコンを大量配置
- emojiをUIアイコンに使う
- 不要なステータスpill
- 「AI POWERED」系のラベル
- hero copyのような大見出し
- ダッシュボード化
- チャットバブル化
- 親密度バー
- streak / badge / gamification
- 説明過多

## Home

主役は個体。

ホームで見せるものを増やさない。

理想:

- 余白
- 深海の空間
- 3D個体
- ごく少ないシステムUI
- 必要なら最新発話への控えめな導線

画面を「情報で埋める」ことを完成度と勘違いしない。

## Specimen box

チャットUI禁止。

発話は標本として並べる。

- 時刻
- 一言
- 必要最小限の区切り

詳細画面でも「AIがこう考えました」という説明はしない。

痕跡を置くだけ。

## Location trace

位置表現は、プライバシー上の理由でMapKitを一律禁止しない。
MapKit / Apple Mapsを使った方がiOSとして自然で分かりやすい場面では使ってよい。

ただし、静かなAIの通常画面では「どこにいたか」を精密に説明すること自体が主目的ではない。
世界観としては、

- 抽象的な位置クラスタ
- 軌跡
- 点
- 距離感

などの曖昧な痕跡を第一候補にする。

地図を使う場合も、生活ログダッシュボードのような精密表示へ寄せない。

## Motion

個体のモーションは有機的で遅い。

- 呼吸のような微細な膨張
- 体液/膜のゆらぎ
- 反射的な縮み
- 少し遅れて戻る

禁止:

- ゲーム的bounce
- 常時派手なparticle
- 意味のないループ演出
- 過剰なspring

`Reduce Motion` を尊重する。

## Accessibility

最低限ではなく、プロダクト品質として扱う。

- Dynamic Type
- VoiceOver
- 44pt以上の操作領域
- semantic color
- contrast
- Reduce Motion
- Differentiate Without Color
- 触覚だけに意味を依存しない

3D個体そのものが情報伝達の唯一手段にならないようにする。

## Review gate

UI変更は次を満たすまで完了ではない。

- iPhone 16 / iOS 27で実画面確認
- Apple HIG review
- anti-slop review
- accessibility review
- Light/Darkの扱いを意図的に確認
- Reduce Motion確認
- PR screenshot添付
- 「なぜこのUIが必要か」を説明できる
