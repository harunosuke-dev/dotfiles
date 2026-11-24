# スニペット一覧

`snippets/<filetype>.json` に置いた自作スニペットの一覧。
呼び出し方と追加の仕方は [README](../README.md) のスニペットの節にある。

実体は JSON の方である。
スニペットを足したり消したりしたら、この表も合わせて直す。

関連: [Vim / Neovim 入門](vim.md)

## JSON で書くときの約束事

スニペットの本体は JSON の文字列なので、JSON の規則が先に効く。

| 書きたいもの | JSON の中での書き方 | 理由 |
| --- | --- | --- |
| `"` | `\"` | 文字列の終わりと区別する（`lang=\"ja\"`） |
| `\` | `\\` | `\` 自体が escape の印である |
| タブ | `\t` | |
| そのままの `$` | `\\$` | `$` はスニペットの穴の印。JSON で `\\` にして、スニペットに `\$` を届ける |

最後の要素の後ろに `,` を付けるとエラーになる。コメントは書けない。
誤りは JSON の LSP が診断に出すので、`]d` で飛べる。

prefix の先頭に `!` を付けても、展開したあとに `!` は残らない（`!html` で確かめた）。

---

## html

| prefix | 名前 | 何をするか |
| --- | --- | --- |
| `!html` | HTML の雛形 | `<!doctype html>` から `</html>` まで。`lang`・`charset`・`viewport`・`<title>` と、`style.css` の `<link>`・`main.tsx` の `<script>` を含む。`<link>` と `<script>` は使わなければ消す |

## css

| prefix | 名前 | 何をするか |
| --- | --- | --- |
| `bbox` | box-sizing リセット | width を「占める幅」に読み替える。padding と border を含める |
| `flow` | owl — 流れる文章の間隔 | 隣り合う兄弟の間にだけ余白。端に余分な余白が出ない |
| `stack` | 縦に積む Flexbox | 並べる箱の間隔。gap は相殺しないので指定した値がそのまま出る |
| `wrap` | 中央寄せと行長の制限 | 上限を決めて中央へ。位置や大きさは決め打たない |
| `clamp` | 流体的なサイズ | 下限・可変・上限。分岐せずに連続的に伸縮させる |
| `focus` | フォーカスの輪郭 | 現在位置の表示。`outline: none` を書くなら代わりを必ず置く |
| `reduce` | 動きを減らす設定を尊重 | `prefers-reduced-motion` のとき動きを止める |

## typescriptreact

`typescript` と `javascript` の分も候補に出る。

| prefix | 名前 | 何をするか |
| --- | --- | --- |
| `rfc` | React function component | props の型付きの関数 component |
| `cssm` | CSS Modules import | CSS Modules の import |

## mdx

ブログの MDX 用。`markdown` の分も候補に出る。

| prefix | 何をするか |
| --- | --- |
| `Definition` / `Theorem` / `Lemma` / `Corollary` / `Proposition` / `Axiom` | 定義・定理などのブロック。id / category / title は必須。tags と label は任意 |
| `Example` / `Remark` / `Confer` | 例・注意・参考のブロック。title は省略可 |
| `Proof` / `Solution` | 証明・解答の折りたたみ。`defaultOpen` を足すと開いて出る |
| `Box` / `Box-accent` | 左上にラベルを出す枠。accent は枠線とラベルに色を付ける |
| `CalloutNote` / `CalloutTip` / `CalloutWarning` | 補足・コツ・注意の吹き出し |
| `Figure` | キャプション付きの画像 |
| `LinkCard` / `LinkPreview` | リンクをカードで出す / リンク先を先読みして見せる |
| `Embed` / `YouTubeEmbed` | iframe を比率つきで埋め込む / YouTube の動画 |
| `Spacer` / `Indent` / `InlineToc` | 縦の余白 / 字下げ / 本文中の目次 |
| `code` / `details` / `table` | コードブロック / 折りたたみ / 2 列の表 |
