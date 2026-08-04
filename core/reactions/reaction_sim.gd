## 反応マップ上のマーカーを操作するシミュレータ（設計書 §3.1）。
##
## 純粋ロジック（Node ではなく RefCounted）。実験室で「時間を消費せず何度でも
## 経路を試せる」ことが要件なので、ここには一切の副作用・エンジン依存を持たせない。
##
## 操作モデルは「離散工程の積み重ね」（第10章の決定）。1操作 = 1ステップで、
## 各操作は量（連続値）を持つ。
##
## 操作と移動:
##   加熱     → 上へ（+y）
##   加水     → 左へ（-x、濃度が下がり pH は中性へ寄る）
##   蒸留     → 右へ（+x、収率が落ちる）
##   酸/塩基  → 組成（net_acid）を動かす＝中和。マーカーは動かさない
##   素材投入 → 素材固有の方向へ跳躍し、素材の酸性度を組成へ加える
##
## 収率: 目標領域では「最短直線 / 実経路長」の効率で決まり、遠回り・蒸留・暴走域の
## かすりで下がる（§3.3「経路の効率が収率になる」）。暴走域への突入はバッチ全損。
class_name ReactionSim
extends RefCounted

## 目標領域外での経路長ペナルティ係数（フォールバック用）。
const PATH_YIELD_COST := 0.05
## 蒸留 1 単位あたりの追加収率ペナルティ。
const DISTILL_PENALTY := 0.1
## 経路効率 → 収率のカーブの鋭さ（大きいほど最短経路が有利）。
const YIELD_EXPONENT := 1.5
## 暴走域の“縁”とみなす半径外の余白。この範囲をかすめると収率が落ちる。
const HAZARD_GRAZE_MARGIN := 1.0
## かすり時の最大収率ペナルティ（縁に近いほどこの値に近づく）。
const HAZARD_GRAZE_PENALTY := 0.4
## この正規化温度以上の暴走域に突入すると設備を痛める（第10章: 素材ロス＋設備耐久）。
const HAZARD_DEEP_TEMP := 0.7
## 深部暴走域で受ける設備ダメージ量。
const HAZARD_EQUIP_DAMAGE := 0.5

var map: ReactionMap
var position: Vector2
## 正味の酸当量（正=酸性 / 負=塩基性）。pH を決める組成側の状態。
var net_acid: float = 0.0
var path_length: float = 0.0
## 暴走域に突入したか（true ならこのバッチは全損）。
var batch_lost: bool = false
## この試行で設備が受けたダメージ（0〜）。
var equipment_damage: float = 0.0

## 実行した操作の記録（設計書 §7 の実験ノート＝経路の保存の下地）。
## 各要素は { "op": StringName, "amount": float } か { "op": &"material", "material_id": StringName }。
var operations: Array = []

var _start_position: Vector2
var _distill_penalty: float = 0.0
var _hazard_penalty: float = 0.0

func _init(reaction_map: ReactionMap, start: Vector2 = Vector2.ZERO) -> void:
	map = reaction_map
	position = _clamp_to_bounds(start)
	_start_position = position

## 加熱: 上へ。
func heat(amount: float) -> void:
	operations.append({"op": &"heat", "amount": amount})
	_move_to(position + Vector2(0.0, amount))

## 加水: 左へ。濃度が下がるので pH は中性へ寄る。
func add_water(amount: float) -> void:
	operations.append({"op": &"water", "amount": amount})
	_move_to(position + Vector2(-amount, 0.0))

## 蒸留: 右へ。収率が落ちる。
func distill(amount: float) -> void:
	operations.append({"op": &"distill", "amount": amount})
	_move_to(position + Vector2(amount, 0.0))
	_distill_penalty += absf(amount) * DISTILL_PENALTY

## 酸を加える: 組成を酸性側へ（pH を下げる）。マーカーは動かさない。
func add_acid(equivalents: float) -> void:
	operations.append({"op": &"acid", "amount": equivalents})
	net_acid += absf(equivalents)

## 塩基を加える: 組成を塩基側へ（pH を上げる＝中和）。マーカーは動かさない。
func add_base(equivalents: float) -> void:
	operations.append({"op": &"base", "amount": equivalents})
	net_acid -= absf(equivalents)

## 素材投入: 固有方向へ跳躍し、素材の酸性度を組成へ加える。
func add_material(material: MaterialDef) -> void:
	operations.append({"op": &"material", "material_id": material.id})
	_move_to(position + material.jump_vector * material.jump_magnitude)
	net_acid += material.acidity * material.jump_magnitude

## 濃度（マップ横軸を 0〜1 に正規化）。
func concentration01() -> float:
	if map == null or map.bounds.size.x <= 0.0:
		return 0.0
	return clampf((position.x - map.bounds.position.x) / map.bounds.size.x, 0.0, 1.0)

## 温度（マップ縦軸を 0〜1 に正規化）。
func temperature01() -> float:
	if map == null or map.bounds.size.y <= 0.0:
		return 0.0
	return clampf((position.y - map.bounds.position.y) / map.bounds.size.y, 0.0, 1.0)

## 現在の pH（組成・濃度・温度から算出）。
func ph() -> float:
	return PHModel.compute(net_acid, concentration01(), temperature01())

## 現在地を含む領域（無ければ null）。座標のみで判定。
func current_region() -> ReactionRegion:
	if map == null:
		return null
	return map.region_at(position)

## 暴走域にいるか。
func is_hazard() -> bool:
	var r := current_region()
	return r != null and r.kind == ReactionRegion.Kind.HAZARD

## 座標と pH の両条件を満たす目標領域（無ければ null）。到達＝即成功（第10章の決定）。
func reached_target() -> ReactionRegion:
	if map == null:
		return null
	var p := ph()
	for r in map.regions:
		if r.kind == ReactionRegion.Kind.TARGET and r.contains(position) and r.accepts_ph(p):
			return r
	return null

## 現在の収率（0〜1）。目標領域では最短経路ほど高く、暴走域突入で 0。
func yield_ratio() -> float:
	if batch_lost:
		return 0.0
	var base: float
	var region := current_region()
	if region != null and region.kind == ReactionRegion.Kind.TARGET:
		# 効率 = 最短直線 / 実経路長。まっすぐ到達で 1、遠回りで低下。
		var optimal := _start_position.distance_to(region.center)
		if optimal > 0.0:
			var actual := maxf(path_length, optimal)
			base = pow(clampf(optimal / actual, 0.0, 1.0), YIELD_EXPONENT)
		else:
			base = 1.0
	else:
		# 目標外では素朴な経路長ペナルティ（試行中の目安）。
		base = 1.0 / (1.0 + path_length * PATH_YIELD_COST)
	return clampf(base - _distill_penalty - _hazard_penalty, 0.0, 1.0)

## この試行を実験ノートとして保存する（設計書 §7）。
## 到達した目標があれば product_id・base_purity・収率を記録し、以降は再生・委任量産できる。
func to_note() -> ReactionNote:
	var note := ReactionNote.new()
	note.map_id = map.id if map != null else &""
	note.start_position = _start_position
	note.operations = operations.duplicate(true)
	note.recorded_yield = yield_ratio()
	var t := reached_target()
	if t != null:
		note.product_id = t.product_id
		note.base_purity = t.base_purity
	return note

func _move_to(target: Vector2) -> void:
	var clamped := _clamp_to_bounds(target)
	path_length += position.distance_to(clamped)
	position = clamped
	_check_hazards()

## 移動先が暴走域か、その縁かを判定してペナルティを積む。
func _check_hazards() -> void:
	if map == null:
		return
	for r in map.regions:
		if r.kind != ReactionRegion.Kind.HAZARD:
			continue
		var d := position.distance_to(r.center)
		if d <= r.radius:
			# 突入: バッチ全損。深部（高温）なら設備も痛める。
			batch_lost = true
			_hazard_penalty = 1.0
			if temperature01() >= HAZARD_DEEP_TEMP:
				equipment_damage = maxf(equipment_damage, HAZARD_EQUIP_DAMAGE)
		elif d <= r.radius + HAZARD_GRAZE_MARGIN:
			# かすり: 縁に近いほど収率を削る（警告的ペナルティ）。
			var closeness := 1.0 - (d - r.radius) / HAZARD_GRAZE_MARGIN
			_hazard_penalty = maxf(_hazard_penalty, HAZARD_GRAZE_PENALTY * closeness)

func _clamp_to_bounds(p: Vector2) -> Vector2:
	if map == null:
		return p
	var b := map.bounds
	return Vector2(
		clampf(p.x, b.position.x, b.position.x + b.size.x),
		clampf(p.y, b.position.y, b.position.y + b.size.y)
	)
