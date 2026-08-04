## 素材の静的定義（データ駆動）。
##
## 実データは `data/materials/*.tres` に置き、この型を `script` に指定する。
## エンジン非依存の純粋データなので `core/` に属する。
class_name MaterialDef
extends Resource

## 一意な識別子（例: &"sulfur"）。
@export var id: StringName = &""

## 表示名（例: "硫黄"）。
@export var display_name: String = ""

## 産地・用途などのメモ。
@export_multiline var description: String = ""

## 反応マップ上でこの素材を投入したときの跳躍方向（マップ座標系の単位ベクトル想定）。
## 軸の意味はマップ側（ReactionMap.axis_x / axis_y）が定義する。
@export var jump_vector: Vector2 = Vector2.ZERO

## 跳躍の強さ（倍率）。純度や量に応じて呼び出し側でさらにスケールしてよい。
@export var jump_magnitude: float = 1.0
