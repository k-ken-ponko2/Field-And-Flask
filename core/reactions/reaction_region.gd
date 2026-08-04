## 反応マップ上の「領域」（設計書 §3.2）。
##
## 雛形では円で表現する（中心＋半径）。将来はポリゴンやマスク画像に差し替え可能。
## 判定ロジックだけを持ち、描画は presentation 側の責務。
class_name ReactionRegion
extends Resource

enum Kind {
	TARGET, ## 目標領域: 到達すれば物質を得る（希硫酸など）。
	HAZARD, ## 暴走域: 侵入するとペナルティ（爆発・有毒ガス）。
	FOG,    ## 未踏領域: 設備性能で霧が晴れる範囲が決まる。
}

@export var kind: Kind = Kind.TARGET

## 表示ラベル（例: "希硫酸"）。
@export var label: String = ""

## マップ座標系での中心。
@export var center: Vector2 = Vector2.ZERO

## 半径。
@export var radius: float = 1.0

## TARGET のとき、得られる物質の id。
@export var product_id: StringName = &""

## TARGET のとき、経路が完璧な場合の到達純度の目安。
@export_range(0.0, 1.0) var base_purity: float = 0.9

## 点がこの領域に含まれるか。
func contains(p: Vector2) -> bool:
	return p.distance_to(center) <= radius
