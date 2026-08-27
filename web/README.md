# MIDNIGHT PORT — 公式サイト風テンプレート (TypeScript)

日本のメディアミックス作品の公式サイト（[18trip.jp](https://18trip.jp/) のような
アニメ・ゲーム系ティザーサイト）でよく使われる構成・演出を、**TypeScript + Vite** で
組み直した1ページ構成のテンプレートです。

> **中身はすべてオリジナルのダミーコンテンツです。**
> 実在作品のテキスト・画像・キャラクター・ロゴは一切含んでいません。
> 「ミッドナイト・ポート」は、レイアウトを見せるために用意した架空のプロジェクトです。
> 実案件に使う場合は `src/data/` を差し替えてください。

## 実装されている構成・演出

| 要素 | 内容 |
|---|---|
| ローディング画面 | 000→100 のカウンタと進捗バー、完了後にヒーローの文字送りへ受け渡し |
| 固定ヘッダー | スクロール量で背景付与／下方向で隠れ上方向で復帰、現在セクションに下線 |
| 全画面メニュー | ハンバーガー → フェード＋スタガー表示、ESC で閉じる、背景スクロールロック |
| ヒーロー | 1文字ずつせり上がるキャッチコピー、背景のゆっくりしたドリフト、下部マーキー |
| NEWS | カテゴリタブで絞り込み、`NEW` バッジ、モバイルでは2段組に再配置 |
| ABOUT | 本文＋作品スペック表（dl） |
| CHARACTER | ユニット絞り込み、ホバーでキャッチコピー、クリックでモーダル詳細 |
| MOVIE | サムネイルグリッド → モーダル内プレイヤー（埋め込み URL は空） |
| MUSIC | ポインタでドラッグできる横スクロールカルーセル、スナップ付き |
| SNS / フッター | リンクカードとコピーライト |

演出は `prefers-reduced-motion` を尊重し、モーダルはフォーカストラップ・
`aria-modal`・ESC/背景クリックでの閉じ操作に対応しています。

## 画像素材について

外部画像を一切使っていません。キービジュアル・キャラクター立ち絵・ジャケットは
すべて `src/lib/keyvisual.ts` が **シード値と2色パレットから SVG を生成**しています
（シルエット＋スポットライト）。実写・イラストに差し替えるときは、
`background-image` に渡している data URI を実ファイルの URL に置き換えるだけで、
レイアウト側の変更は不要です。

## セットアップ

```bash
cd web
npm install
npm run dev       # 開発サーバ
npm run build     # 型チェック (tsc --noEmit) + 本番ビルド
npm run preview   # ビルド結果の確認
```

`index.html` から Google Fonts（Zen Kaku Gothic New / Oswald）を読み込みます。
オフライン環境ではシステムフォントにフォールバックします。

## ディレクトリ

```
web/
  index.html            ローディング画面のマークアップのみ。本体は TS が生成
  src/
    main.ts             各セクションを組み立ててマウント
    types.ts            コンテンツの型定義
    data/               ← 差し替えるのはここ
      site.ts             サイト名・キャッチコピー・ナビ項目
      news.ts             お知らせ
      characters.ts       キャラクター／ユニット
      media.ts            ムービー・楽曲・SNS
    lib/
      dom.ts              DOM ヘルパ（要素生成・文字分割・日付整形）
      keyvisual.ts        SVG のプレースホルダ画像生成
      loader.ts           ローディング画面
      nav.ts              ヘッダー・全画面メニュー・スムーススクロール
      reveal.ts           スクロール連動の表示アニメーションと現在地判定
      dragScroll.ts       ドラッグ横スクロール
      modal.ts            フォーカストラップ付きモーダル
    sections/           各セクションの描画関数
    styles/             reset / tokens / layout / components
```

配色・余白・フォント・モーションはすべて `src/styles/tokens.css` の
カスタムプロパティに集約してあるので、まずはここを変えるとサイト全体の印象が変わります。

## 検証状況

- `npm run build`（`tsc --noEmit` + Vite ビルド）: 成功
- Chromium（Playwright）で描画確認: ローディング → ヒーロー → 全セクション →
  キャラクターモーダル → NEWS 絞り込み → モバイル表示・全画面メニュー まで動作、
  コンソールエラーなし、モバイル幅（390px）で横スクロールの発生なし

TypeScript は `strict` に加えて `noUncheckedIndexedAccess` /
`exactOptionalPropertyTypes` / `verbatimModuleSyntax` を有効にしています。
