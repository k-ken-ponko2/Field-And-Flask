## 手に持つ道具の定義（データ駆動）。
##
## 「処理 ＝ 状態 × 手に持つ道具 × 動作」（`docs/design/tactile-crafting.md` §3）の“道具”側。
## 素手も 1 つの道具（id = &"hand"）として扱う。上位の道具ほど強い/精密な所作になる（道具ツリー）。
class_name ToolDef
extends Resource

## 一意な識別子（例: &"hammer" 敲石）。
@export var id: StringName = &""

## 表示名（例: "敲石"）。
@export var display_name: String = ""

## 道具ツリー上の段階（素手=0、原始的な道具=1…）。
@export var tier: int = 0

## 動作の強さ（打撃力・送風量など）。処理の効果スケールに使う。
@export var power: float = 1.0

## 精密さ（細かい剥離・微調整の可否）。
@export var precision: float = 1.0
