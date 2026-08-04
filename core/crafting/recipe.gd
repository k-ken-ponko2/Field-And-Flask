## レシピ＝「ある物質を作るのに何が要るか」の定義（データ駆動）。
##
## 願い（例: 病人を治したい）から必要物質を逆算するための依存関係の1ノード。
## 実データは `data/recipes/*.tres`。
class_name Recipe
extends Resource

## 生成物の id（例: &"dilute_sulfuric_acid"）。
@export var product_id: StringName = &""

## 表示名（例: "希硫酸"）。
@export var display_name: String = ""

## 必要な入力素材・中間生成物の id 一覧。
@export var inputs: Array[StringName] = []

## この生成物を作る反応マップの id（&"" なら反応マップを介さない単純加工）。
@export var map_id: StringName = &""

## 必要な設備・技術の id（&"" なら不要）。制約解除（設計書 §2）に対応。
@export var tech_id: StringName = &""
