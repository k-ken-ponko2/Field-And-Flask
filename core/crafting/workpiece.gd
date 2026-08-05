## ワークピース＝作りかけの唯一の“通し”オブジェクト（`docs/design/tactile-crafting.md` §4）。
##
## 状態（組成/純度/水分/可塑性/形/鋭さ/温度/完成度…）を持ち、各処理がそれを変形する。
## 1 画面で全工程を貫けるのは、この 1 個の状態が工程を跨いで持続するから。
## 純粋データ（副作用なし）。形は当面 String ラベル＋数値パラメータで抽象表現する。
class_name Workpiece
extends RefCounted

## 現在の形（例: "原石" → "粗い両面" → "鏃"）。&"" 相当の "" は「まだ何もない」。
var shape: String = ""

## 由来素材の id（任意）。
var material_id: StringName = &""

## 数値パラメータ（例: {"鋭さ": 35.0, "完成度": 20.0}）。
var props: Dictionary = {}

func _init(start_shape: String = "", start_props: Dictionary = {}) -> void:
	shape = start_shape
	props = start_props.duplicate()

## パラメータ取得（無ければ既定値）。
func get_prop(name: StringName, default_value: float = 0.0) -> float:
	return props.get(name, default_value)

## パラメータ設定。
func set_prop(name: StringName, value: float) -> void:
	props[name] = value
