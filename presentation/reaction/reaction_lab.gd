## 反応マップの仮UI（presentation 層）。
##
## core（ReactionSim / ReactionMap / MaterialDef）と data/*.tres を繋いで、
## Godot 上で反応マップを「触れる」プロトタイプにする。ロジックは core 側。
##
## 実行:
##   godot --path . （このシーンを開いて実行）
##   もしくは res://presentation/reaction/reaction_lab.tscn をメインにして起動。
class_name ReactionLab
extends Control

const START := Vector2(2, 2)

var map: ReactionMap
var materials: Dictionary = {}
var sim: ReactionSim
var view: ReactionMapView
var readout: Label
var _trace: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	map = load("res://data/reactions/acid_base_map.tres")
	for id in ["vitriol", "lime", "water", "sulfur"]:
		var m: MaterialDef = load("res://data/materials/%s.tres" % id)
		if m != null:
			materials[m.id] = m
	_build_ui()
	_new_batch()

func _new_batch() -> void:
	sim = ReactionSim.new(map, START)
	_trace = PackedVector2Array([sim.position])
	view.setup(sim)
	_refresh()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12
	root.offset_top = 12
	root.offset_right = -12
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	view = ReactionMapView.new()
	view.custom_minimum_size = Vector2(420, 420)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(view)

	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_constant_override("separation", 8)
	root.add_child(panel)

	var title := Label.new()
	title.text = "反応マップ（仮UI）— 温度 × 濃度 / pH"
	panel.add_child(title)

	panel.add_child(_row([
		_btn("加熱 +1", func(): sim.heat(1.0)),
		_btn("冷却 −1", func(): sim.heat(-1.0)),
	]))
	panel.add_child(_row([
		_btn("加水 ←", func(): sim.add_water(1.0)),
		_btn("蒸留 →", func(): sim.distill(1.0)),
	]))
	panel.add_child(_row([
		_btn("酸 pH↓", func(): sim.add_acid(0.5)),
		_btn("塩基 pH↑", func(): sim.add_base(0.5)),
	]))
	panel.add_child(_row([
		_btn("緑礬", func(): sim.add_material(materials[&"vitriol"])),
		_btn("石灰", func(): sim.add_material(materials[&"lime"])),
		_btn("水", func(): sim.add_material(materials[&"water"])),
		_btn("硫黄", func(): sim.add_material(materials[&"sulfur"])),
	]))
	var reset := Button.new()
	reset.text = "リセット"
	reset.pressed.connect(_new_batch)
	panel.add_child(reset)

	readout = Label.new()
	panel.add_child(readout)

func _row(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for b in buttons:
		row.add_child(b)
	return row

func _btn(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func(): _op(action))
	return b

func _op(action: Callable) -> void:
	action.call()
	_trace.append(sim.position)
	_refresh()

func _refresh() -> void:
	view.trace = _trace
	view.refresh()
	var p := sim.ph()
	var tgt := sim.reached_target()
	var reg := sim.current_region()
	var status := "正常"
	if sim.batch_lost:
		status = "バッチ全損"
	var lines := [
		"pH: %.2f" % p,
		"濃度: %.2f   温度: %.2f" % [sim.position.x, sim.position.y],
		"net_acid: %.2f" % sim.net_acid,
		"収率: %s   経路長: %.1f" % ["%d%%" % int(round(sim.yield_ratio() * 100.0)) if tgt != null else "—", sim.path_length],
		"領域: %s" % (reg.label if reg != null else "—"),
		"目標: %s" % (tgt.label + " 到達" if tgt != null else "未到達"),
		"暴走: %s   設備損傷: %.1f" % [status, sim.equipment_damage],
		"操作: %d 手" % sim.operations.size(),
	]
	readout.text = "\n".join(lines)
