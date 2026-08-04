# フォント（同梱）

## ipaexg.ttf — IPAexゴシック

- **用途**: UI 既定フォント（`presentation/theme/default_theme.tres` から参照）。日本語表示に使う。
- **選定理由**: JIS X 0213 を全収録し、「礬」（緑礬）のような珍しい漢字も欠落なく表示できる。OS への日本語フォント導入が不要になり、どの環境でも文字化けしない。
- **配布元**: IPA（情報処理推進機構）IPAexゴシック。
- **ライセンス**: IPA Font License Agreement v1.0（`IPA_Font_License_Agreement_v1.0.txt` を同梱）。
  フォントファイルを改変せずそのまま同梱・再配布している。ライセンス全文を必ず同梱すること。

`Readme_ipaexg00301.txt` は配布元の README。

> 補足: `*.import` は `.gitignore` 対象（各環境で Godot が自動再生成）。フォント本体 `ipaexg.ttf` はコミットする。
