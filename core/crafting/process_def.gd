## 処理の定義（データ駆動）。「状態 × 手に持つ道具 × 動作」で成立する 1 手。
##
## 発見型ワークベンチ（`docs/design/tactile-crafting.md` §4）の判定核。
## プレイヤーには見えず、成立条件を満たす操作をしたときだけ「既知の工程」として現れる。
class_name ProcessDef
extends Resource

## 一意な識別子（例: &"rough" 粗割り）。
@export var id: StringName = &""

## 表示名（発見時に浮かび上がる工程名。例: "粗割り"）。
@export var display_name: String = ""

## 必要な装備道具の id（例: &"hammer"）。&"" なら道具不問。
@export var tool: StringName = &""

## 必要な動作（例: &"strike" 叩く）。
@export var motion: StringName = &""

## 成立に必要なワークピースの形（例: "原石"）。"" なら形不問。
@export var requires_shape: String = ""

## 成立に必要なパラメータ範囲。{ StringName: Vector2(min, max) }。空なら不問。
@export var requires_props: Dictionary = {}

## 成立後のワークピースの形（"" なら形は変えない）。
@export var result_shape: String = ""

## 成立後に設定するパラメータ（{ StringName: float }。set-to 方式）。
@export var effects: Dictionary = {}

## この処理が今のワークピース状態で成立しうるか（道具は見ない・形とパラメータのみ）。
func state_matches(wp: Workpiece) -> bool:
	if requires_shape != "" and wp.shape != requires_shape:
		return false
	for k in requires_props:
		var r: Vector2 = requires_props[k]
		var v := wp.get_prop(k)
		if v < r.x or v > r.y:
			return false
	return true

## ワークピースに効果を適用する。
func apply_to(wp: Workpiece) -> void:
	if result_shape != "":
		wp.shape = result_shape
	for k in effects:
		wp.set_prop(k, effects[k])
