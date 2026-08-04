# core/ — 純粋ロジック層

エンジンから切り離された、副作用なしのゲームロジック（設計書 §8）。

## この層のルール

- **依存してよいもの**: Godot の値型（`Vector2`, `Rect2`, `Resource`, `RefCounted`, 数学関数）
- **依存してはいけないもの**: `Node` / シーンツリー / 入力 / 描画 / 音 / `get_node` / `_process`
- 実データは持たず、**定義と計算だけ**。実データは `data/*.tres` に置く。

この分離を守るかぎり、`core/__tests__/run_tests.gd` を使って
UI を起動せずにロジックを検証できる。数十時間規模のバランス調整では、
これができるかどうかが決定的な差になる。

## 中身

| ファイル | 役割 |
|---|---|
| `materials/material_def.gd` | 素材の静的定義（データ駆動） |
| `materials/substance.gd` | 所持している量と純度 |
| `materials/purity.gd` | 混合・精製・要求純度の判定 |
| `reactions/reaction_region.gd` | 反応マップ上の領域（目標・暴走・未踏、pH 条件） |
| `reactions/reaction_map.gd` | 分野ごとのマップ定義（軸はデータ） |
| `reactions/reaction_sim.gd` | マーカー操作・収率・暴走域・pH の計算 |
| `reactions/ph_model.gd` | pH の連続モデル（組成・濃度・温度 → pH） |
| `calendar/game_calendar.gd` | 季節・カレンダー |
| `__tests__/run_tests.gd` | ヘッドレステスト |
