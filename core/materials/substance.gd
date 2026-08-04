## インベントリ上の「実体」。どの素材が、どれだけ、どの純度で存在するか。
##
## MaterialDef が「定義」なのに対し、こちらは「所持している量と純度」を持つ。
class_name Substance
extends Resource

## 対応する MaterialDef の id。
@export var material_id: StringName = &""

## 量（g などの抽象単位）。
@export var amount: float = 0.0

## 純度 0.0〜1.0。用途ごとに要求純度が異なる（設計書 §4）。
@export_range(0.0, 1.0) var purity: float = 1.0
