## 反応マップ上のマーカーを操作するシミュレータ（設計書 §3.1）。
##
## 純粋ロジック（Node ではなく RefCounted）。実験室で「時間を消費せず何度でも
## 経路を試せる」ことが要件なので、ここには一切の副作用・エンジン依存を持たせない。
##
## 操作と移動:
##   加熱     → 上へ（+y）
##   加水     → 左へ（-x）
##   蒸留     → 右へ（+x、収率が落ちる）
##   素材投入 → 素材固有の方向へ跳躍
##
## 収率: 経路が長いほど、また蒸留を多用するほど下がる（§3.3「経路の効率が収率になる」）。
class_name ReactionSim
extends RefCounted

## 経路長が収率を削る係数。
const PATH_YIELD_COST := 0.05
## 蒸留 1 単位あたりの追加収率ペナルティ。
const DISTILL_PENALTY := 0.1

var map: ReactionMap
var position: Vector2
var path_length: float = 0.0
var _distill_penalty: float = 0.0

func _init(reaction_map: ReactionMap, start: Vector2 = Vector2.ZERO) -> void:
	map = reaction_map
	position = _clamp_to_bounds(start)

## 加熱: 上へ。
func heat(amount: float) -> void:
	_move_to(position + Vector2(0.0, amount))

## 加水: 左へ。
func add_water(amount: float) -> void:
	_move_to(position + Vector2(-amount, 0.0))

## 蒸留: 右へ。収率が落ちる。
func distill(amount: float) -> void:
	_move_to(position + Vector2(amount, 0.0))
	_distill_penalty += absf(amount) * DISTILL_PENALTY

## 素材投入: その素材固有の方向へ跳躍。
func add_material(material: MaterialDef) -> void:
	_move_to(position + material.jump_vector * material.jump_magnitude)

## 現在地を含む領域（無ければ null）。
func current_region() -> ReactionRegion:
	if map == null:
		return null
	return map.region_at(position)

## 暴走域にいるか。
func is_hazard() -> bool:
	var r := current_region()
	return r != null and r.kind == ReactionRegion.Kind.HAZARD

## 現在の収率（0〜1）。経路が短いほど高い。
func yield_ratio() -> float:
	var base := 1.0 / (1.0 + path_length * PATH_YIELD_COST)
	return clampf(base - _distill_penalty, 0.0, 1.0)

func _move_to(target: Vector2) -> void:
	var clamped := _clamp_to_bounds(target)
	path_length += position.distance_to(clamped)
	position = clamped

func _clamp_to_bounds(p: Vector2) -> Vector2:
	if map == null:
		return p
	var b := map.bounds
	return Vector2(
		clampf(p.x, b.position.x, b.position.x + b.size.x),
		clampf(p.y, b.position.y, b.position.y + b.size.y)
	)
