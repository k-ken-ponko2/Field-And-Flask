## 反応マップの仮UI（presentation 層）。
##
## core（ReactionSim / ReactionMap / MaterialDef）と data/*.tres を繋いで、
## Godot 上で反応マップを「触れる」プロトタイプにする。ロジックは core 側。
##
## 実行:
##   res://presentation/reaction/reaction_lab.tscn を開いて実行（F6）。
class_name ReactionLab
extends Control

const START := Vector2(2, 2)

var map: ReactionMap
var materials: Dictionary = {}
var sim: ReactionSim
var view: ReactionMapView
var readout: RichTextLabel
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
	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		outer.add_theme_constant_override(m, 18)
	add_child(outer)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	outer.add_child(root)

	# 左：反応マップをカード（PanelContainer）で額装。
	var mapcard := PanelContainer.new()
	mapcard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mapcard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mapcard)
	view = ReactionMapView.new()
	view.custom_minimum_size = Vector2(440, 440)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mapcard.add_child(view)

	# 右：操作コンソールのカード。
	var concard := PanelContainer.new()
	concard.custom_minimum_size = Vector2(330, 0)
	root.add_child(concard)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 8)
	concard.add_child(panel)

	var title := Label.new()
	title.text = "反応マップ — 温度 × 濃度 / pH"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.541, 0.353, 0.086))
	panel.add_child(title)

	panel.add_child(_section("温度"))
	panel.add_child(_row([
		_btn("加熱 +1", func(): sim.heat(1.0)),
		_btn("冷却 −1", func(): sim.heat(-1.0)),
	]))
	panel.add_child(_section("濃度"))
	panel.add_child(_row([
		_btn("加水 ←", func(): sim.add_water(1.0)),
		_btn("蒸留 →", func(): sim.distill(1.0)),
	]))
	panel.add_child(_section("中和"))
	panel.add_child(_row([
		_btn("酸 pH↓", func(): sim.add_acid(0.5)),
		_btn("塩基 pH↑", func(): sim.add_base(0.5)),
	]))
	panel.add_child(_section("素材投入"))
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

	panel.add_child(_section("計測"))
	readout = RichTextLabel.new()
	readout.bbcode_enabled = true
	readout.fit_content = true
	readout.scroll_active = false
	panel.add_child(readout)

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.55, 0.5, 0.42))
	return l

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

	var yield_txt := "—"
	if tgt != null:
		yield_txt = "%d%%" % int(round(sim.yield_ratio() * 100.0))
	elif sim.batch_lost:
		yield_txt = "0%"
	var status_txt := "正常"
	var status_hex := "3f7a3f"
	if sim.batch_lost:
		status_txt = "バッチ全損"
		status_hex = "c0392b"

	var lines := PackedStringArray()
	lines.append("[font_size=24][b][color=#%s]pH %.2f[/color][/b][/font_size]" % [_ph_hex(p), p])
	lines.append(_kv("濃度 / 温度", "%.2f / %.2f" % [sim.position.x, sim.position.y]))
	lines.append(_kv("net_acid", "%.2f" % sim.net_acid))
	lines.append(_kvc("収率", yield_txt, "3f7a3f" if tgt != null else "8a8172"))
	lines.append(_kv("経路長", "%.1f" % sim.path_length))
	lines.append(_kv("領域", reg.label if reg != null else "—"))
	lines.append(_kvc("目標", (tgt.label + " 到達") if tgt != null else "未到達", "3f7a3f" if tgt != null else "8a8172"))
	lines.append(_kvc("状態", status_txt, status_hex))
	lines.append(_kv("操作", "%d 手" % sim.operations.size()))
	readout.text = "\n".join(lines)

func _kv(label: String, value: String) -> String:
	return _kvc(label, value, "2a2620")

func _kvc(label: String, value: String, vhex: String) -> String:
	return "[color=#8a8172]%s[/color]  [color=#%s]%s[/color]" % [label, vhex, value]

func _ph_hex(p: float) -> String:
	if p < 4.0:
		return "c0392b"
	elif p < 6.5:
		return "b8791f"
	elif p <= 7.5:
		return "3f7a3f"
	elif p < 9.5:
		return "2f7ab0"
	return "3a5fb0"
