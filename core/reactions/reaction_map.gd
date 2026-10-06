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

## 縦軸（温度）の下端・上端が何℃にあたるか。熱源の天井（℃）をマップ座標へ写すのに使う。
## 値は仮（`docs/design/heat-tiers.md` §6）。
@export var temperature_range: Vector2 = Vector2(20.0, 1000.0)

## 領域の一覧（目標・暴走・未踏）。
@export var regions: Array[ReactionRegion] = []

## 指定座標を含む最初の領域を返す（無ければ null）。
func region_at(p: Vector2) -> ReactionRegion:
	for r in regions:
		if r.contains(p):
			return r
	return null

## 温度（℃）→ 縦軸座標。範囲外は端にクランプする。
func temperature_to_y(celsius: float) -> float:
	var span := temperature_range.y - temperature_range.x
	if span <= 0.0:
		return bounds.position.y
	var t := clampf((celsius - temperature_range.x) / span, 0.0, 1.0)
	return bounds.position.y + bounds.size.y * t

## 縦軸座標 → 温度（℃）。
func y_to_temperature(y: float) -> float:
	if bounds.size.y <= 0.0:
		return temperature_range.x
	var t := clampf((y - bounds.position.y) / bounds.size.y, 0.0, 1.0)
	return temperature_range.x + (temperature_range.y - temperature_range.x) * t
