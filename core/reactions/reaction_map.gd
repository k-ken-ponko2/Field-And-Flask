## 分野ごとの反応マップの定義（設計書 §3.4）。データ駆動（.tres）。
##
## 軸の意味（axis_x / axis_y）はここで宣言するだけで、シミュレーション側は
## 軸に依存しない。第10章の「軸を何にするか」が未確定でも、データ差し替えで対応できる。
class_name ReactionMap
extends Resource

## 一意な識別子（例: &"acid_base"）。技術ツリーの解除と 1:1 対応させる。
@export var id: StringName = &""

## 表示名（例: "酸・塩基系マップ"）。
@export var display_name: String = ""

## 横軸の意味（第一候補: "濃度"）。左が低・右が高。
@export var axis_x: String = "濃度"

## 縦軸の意味（第一候補: "温度"）。下が低・上が高。
@export var axis_y: String = "温度"

## マップの有効範囲。マーカーはこの矩形内にクランプされる。
@export var bounds: Rect2 = Rect2(0, 0, 10, 10)

## 領域の一覧（目標・暴走・未踏）。
@export var regions: Array[ReactionRegion] = []

## 指定座標を含む最初の領域を返す（無ければ null）。
func region_at(p: Vector2) -> ReactionRegion:
	for r in regions:
		if r.contains(p):
			return r
	return null
