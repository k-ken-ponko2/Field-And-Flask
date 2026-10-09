## 実験ノート＝一度成功させた反応（経路）の保存物（設計書 §7）。
##
## 「初回だけが推理ゲーム、二回目以降は資産」を成立させる中核。
## 操作列（operations）を保存し、同じマップ・開始点で再生すれば決定的に再現できる。
## また委任量産（produce）で、UI を起動せず素材から生産量・純度を計算できる。
##
## Resource なので `.tres` として保存でき、仲間への委任や自動なぞりに使える。
class_name ReactionNote
extends Resource

## どのマップ上の経路か（ReactionMap.id）。
@export var map_id: StringName = &""

## 開始座標（収率は開始点からの最短距離で決まるため、再現には開始点が要る）。
@export var start_position: Vector2 = Vector2.ZERO

## 操作列。ReactionSim.operations と同形式:
##   { "op": &"heat"/"water"/"distill"/"acid"/"base", "amount": float }
##   { "op": &"material"/&"queue", "material_id": StringName }
##   { "op": &"stir", "amount": float }（queue した経路をかき混ぜて進む）
@export var operations: Array = []

## 到達した目標物質の id（未到達なら &""）。
@export var product_id: StringName = &""

## 目標領域の base_purity（完璧な経路での到達純度の目安）。
@export_range(0.0, 1.0) var base_purity: float = 0.0

## 記録時の収率（0〜1）。
@export_range(0.0, 1.0) var recorded_yield: float = 0.0

## ノートを再生し、結果の ReactionSim を返す（決定的な再現）。
##   materials: material_id -> MaterialDef の辞書（素材投入の解決に使う）。
func replay(map: ReactionMap, materials: Dictionary = {}) -> ReactionSim:
	var sim := ReactionSim.new(map, start_position)
	for op in operations:
		match op.get("op"):
			&"heat":
				sim.heat(op["amount"])
			&"water":
				sim.add_water(op["amount"])
			&"distill":
				sim.distill(op["amount"])
			&"acid":
				sim.add_acid(op["amount"])
			&"base":
				sim.add_base(op["amount"])
			&"material":
				var m: MaterialDef = materials.get(op.get("material_id"))
				if m != null:
					sim.add_material(m)
			&"queue":
				var q: MaterialDef = materials.get(op.get("material_id"))
				if q != null:
					sim.queue_material(q)
			&"stir":
				sim.stir(op["amount"])
	return sim

## 委任量産: 入力素材の量・純度から、生産される量と純度を求める。
##   量  = 入力量 × 収率（経路の効率ぶんだけ目減りする）
##   純度 = base_purity × 入力純度（不純な素材からは不純な生成物）
## 戻り値: { "product_id": StringName, "amount": float, "purity": float }
func produce(input_amount: float, input_purity: float = 1.0) -> Dictionary:
	return {
		"product_id": product_id,
		"amount": maxf(input_amount, 0.0) * recorded_yield,
		"purity": clampf(base_purity * clampf(input_purity, 0.0, 1.0), 0.0, 1.0),
	}
