# Field & Flask（仮題）

> 採取・精製・創造に特化した科学クラフトゲーム
> **石器時代同然の世界で、素材を探して集め、化学の力で文明の道具を一つずつ取り戻していく。**

- マップ・採取の手触り: Stardew Valley
- クラフト・調合の手触り: Potion Craft
- 技術の積み上げ方: 目標から逆算する技術ツリー
- エンジン: **Godot 4.7**

詳しいコンセプトは [`docs/design/concept-v2.md`](docs/design/concept-v2.md) を参照。

---

## プロジェクト構成

設計原則は「**ロジックとエンジンの分離**」（設計書 §8）。

```
core/            ← 副作用なし・エンジン非依存の純粋ロジック
  materials/       素材定義・純度計算
  reactions/       反応マップ・領域・シミュレータ
  calendar/        季節・カレンダー
  __tests__/       ヘッドレステスト
presentation/    ← エンジン依存（描画・UI）。core を呼ぶだけ
data/            ← データ駆動の .tres（素材・反応マップの実データ）
  materials/
  reactions/
docs/design/     ← 設計ドキュメント
```

`core/` は Node に依存しない（`RefCounted` / `Resource` のみ）。
「純度72%の硫酸で反応Xは成立するか」を **UIを起動せず** 検証できることが、
数十時間規模のバランス調整では決定的な差になる。

## セットアップ

1. [Godot 4.7](https://godotengine.org/) を入手する（MIT・完全無料）。
2. このリポジトリを Godot エディタで「インポート」する（`project.godot` を選択）。
3. F5 で採取マップ（`presentation/field/field.tscn`）が起動し、キャラクターを操作できる。

### 操作

| キー | 動作 |
|---|---|
| W / A / S / D または 矢印キー | 移動（8方向） |

`presentation/main.tscn` は core ロジックのヘッドレスデモ（別シーン）。

## テストの実行

`core/` の純粋ロジックは UI を起動せずヘッドレスで検証できる:

```bash
godot --headless --path . --script res://core/__tests__/run_tests.gd
```

全テストが通れば終了コード 0、失敗があれば 1 を返す（CI 連携用）。

### 検証状況

この雛形は **Godot 4.7 stable（ヘッドレス）で検証済み**:

- プロジェクトのインポート: 成功（`class_name` 登録・エラーなし）
- `core/__tests__/run_tests.gd`: **passed=23 failed=0**
- `main.tscn` 起動（`data/reactions/acid_base_map.tres` の読み込み）:
  `到達: 希硫酸 ／ 収率 0.83 ／ 純度目安 0.70`

Godot 未導入の環境でも、公式バイナリ（単一実行ファイル）を取得すれば検証できる:

```bash
curl -sSL -o godot.zip \
  https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip
unzip godot.zip
./Godot_v4.7-stable_linux.x86_64 --headless --path . --import
./Godot_v4.7-stable_linux.x86_64 --headless --path . --script res://core/__tests__/run_tests.gd
```

## 現状（この雛形でできること）

- **採取マップを歩ける**（`CharacterBody2D` による8方向移動・カメラ追従・木や岩との衝突）
  - 見た目は手続き生成（外部素材なし）: シームレスノイズの草原シェーダ、影付き＋Yソートの
    木・岩・茂み・草、池・小道、ビネット。将来は `TileMapLayer` + `TileSet` や本物の
    スプライトに差し替え可能（設計書 §8）
- 反応マップ上のマーカーを操作（加熱＝上／加水＝左／蒸留＝右／素材投入＝跳躍）
- 領域判定（目標・暴走・未踏）と暴走域の検出
- 経路の効率が収率になるモデル（遠回り・蒸留で収率低下）
- 純度の混合・精製計算
- 季節・カレンダーの純粋ロジック
- `.tres` によるデータ駆動（素材・反応マップ）

## まだ決めていないこと（設計書 §10）

1. 反応マップの軸（温度×濃度が第一候補。pH／酸化還元電位も案）
   → 雛形では軸を `ReactionMap.axis_x / axis_y` の**データ**にしてあり、差し替え可能
2. 経路の「なぞり方」（連続的な直接操作か、離散工程か）
3. 暴走・失敗のペナルティ（素材ロスか、設備破損か、負傷か）
