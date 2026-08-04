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

## pH 条件を課すか（設計書 §3: 目標・暴走域は座標＋pH の複合で定義できる）。
## true のとき、この領域は空間的に含むだけでなく pH が [ph_min, ph_max] に入る必要がある。
@export var requires_ph: bool = false

## pH 条件の下限（requires_ph のときのみ有効）。
@export_range(0.0, 14.0) var ph_min: float = 0.0

## pH 条件の上限（requires_ph のときのみ有効）。
@export_range(0.0, 14.0) var ph_max: float = 14.0

## 点がこの領域に空間的に含まれるか（pH は見ない）。
func contains(p: Vector2) -> bool:
	return p.distance_to(center) <= radius

## この pH が領域の条件を満たすか（pH 条件が無ければ常に true）。
func accepts_ph(value: float) -> bool:
	if not requires_ph:
		return true
	return value >= ph_min and value <= ph_max
