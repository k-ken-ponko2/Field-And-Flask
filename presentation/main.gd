## 起動シーンのプレースホルダ（presentation 層）。
##
## core/ の純粋ロジックを .tres データで動かすデモ。実際のUI・反応マップ描画・
## TileMap による採取マップはこの層に積み上げていく。
extends Node2D

func _ready() -> void:
	var map: ReactionMap = load("res://data/reactions/acid_base_map.tres")
	if map == null:
		push_error("反応マップの読み込みに失敗しました")
		return

	# 例: 冷たい希薄状態 (2, 2) から加熱して希硫酸の領域を目指す。
	var sim := ReactionSim.new(map, Vector2(2, 2))
	sim.heat(4.0)

	var region := sim.current_region()
	if region != null and region.kind == ReactionRegion.Kind.TARGET:
		print("到達: %s ／ 収率 %.2f ／ 純度目安 %.2f" % [
			region.label, sim.yield_ratio(), region.base_purity
		])
	elif sim.is_hazard():
		print("暴走域に入ってしまいました: %s" % region.label)
	else:
		print("何もない領域にいます（現在地 %s）" % sim.position)
