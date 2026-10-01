## 反応マップの仮UI（presentation 層）。
##
## core（ReactionSim / ReactionMap / MaterialDef / ReactionNote）と data/*.tres を繋いで、
## Godot 上で反応マップを「触れる」プロトタイプにする。ロジックは core 側。
##
## 実行:
##   単体: res://presentation/reaction/reaction_lab.tscn を開いて実行（F6）。
##   埋め込み: field.gd が作業台の前で E を押したときにオーバーレイとして開く
##   （`embedded = true` にすると「フィールドへ戻る」と Esc で閉じられる）。
##
## キー操作（移動と同じ WASD/矢印を流用）:
##   W/↑ 加熱   S/↓ 冷却   A/← 加水   D/→ 蒸留
##   Q 酸  E 塩基   1〜4 素材投入   Z 一手戻す   R リセット   Esc 閉じる
class_name ReactionLab
extends Control

## 閉じるときに発火。到達していれば note.product_id と表示名 product_label が入る。
signal closed(note: ReactionNote, product_label: String)

const START := Vector2(2, 2)
const MATERIAL_IDS: Array[StringName] = [&"vitriol", &"lime", &"water", &"sulfur"]
const MATERIAL_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4]
const OP_LABELS := {
	&"heat": "加熱", &"water": "加水", &"distill": "蒸留",
	&"acid": "酸", &"base": "塩基", &"material": "投入",
}

## フィールドから開かれたとき true（戻るボタンと Esc を有効にする）。
var embedded := false

var map: ReactionMap
var materials: Dictionary = {}
var sim: ReactionSim
var view: ReactionMapView

var _trace: PackedVector2Array = PackedVector2Array()
var _subtitle: Label
var _status_chip: PanelContainer
var _status_label: Label
var _ph_value: Label
var _ph_scale: Label
var _tiles: Dictionary = {}
var _chips: Dictionary = {}
var _op_count: Label
var _log: RichTextLabel
var _undo_btn: Button

func _ready() -> void:
	map = load("res://data/reactions/acid_base_map.tres")
	for id in MATERIAL_IDS:
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

## 直前の操作を取り消す。ReactionNote の再生で決定的に再構築する（core にアンドゥは無い）。
func _undo() -> void:
	if sim.operations.is_empty():
		return
	var note := ReactionNote.new()
	note.start_position = START
	note.operations = sim.operations.slice(0, sim.operations.size() - 1)
	sim = note.replay(map, materials)
	_trace.resize(_trace.size() - 1)
	view.setup(sim)
	_refresh()

func _close() -> void:
	var target := sim.reached_target()
	closed.emit(sim.to_note(), target.label if target != null else "")

# --- 入力 ----------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("move_up"):
		_op(func(): sim.heat(1.0))
	elif event.is_action_pressed("move_down"):
		_op(func(): sim.heat(-1.0))
	elif event.is_action_pressed("move_left"):
		_op(func(): sim.add_water(1.0))
	elif event.is_action_pressed("move_right"):
		_op(func(): sim.distill(1.0))
	elif embedded and event.is_action_pressed("ui_cancel"):
		_close()
	else:
		_handle_key(event as InputEventKey)
		return
	get_viewport().set_input_as_handled()

func _handle_key(key: InputEventKey) -> void:
	if key == null:
		return
	var idx := MATERIAL_KEYS.find(key.physical_keycode)
	if idx >= 0:
		_add_material(MATERIAL_IDS[idx])
	elif key.physical_keycode == KEY_Q:
		_op(func(): sim.add_acid(0.5))
	elif key.physical_keycode == KEY_E:
		_op(func(): sim.add_base(0.5))
	elif key.physical_keycode == KEY_Z:
		_undo()
	elif key.physical_keycode == KEY_R:
		_new_batch()
	else:
		return
	get_viewport().set_input_as_handled()

# --- UI 構築 -------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		outer.add_theme_constant_override(m, 14 if embedded else 18)
	add_child(outer)

	# 埋め込み時は暗いスクリムの上に載るので、全体を 1 枚のカードで包んで読みやすくする。
	var host: Control = outer
	if embedded:
		var card := PanelContainer.new()
		outer.add_child(card)
		host = card

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	host.add_child(column)
	column.add_child(_build_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)

	# 左：反応マップを額装。
	var mapcard := PanelContainer.new()
	mapcard.theme_type_variation = &"MapFrame"
	mapcard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mapcard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(mapcard)
	view = ReactionMapView.new()
	view.custom_minimum_size = Vector2(420, 420)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mapcard.add_child(view)

	# 右：操作コンソールと計測（縦に溢れたらスクロール）。
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	scroll.add_child(side)
	side.add_child(_build_console())
	side.add_child(_build_readout())

func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)

	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	var title := Label.new()
	title.text = "反応ラボ"
	title.theme_type_variation = &"TitleLabel"
	titles.add_child(title)
	_subtitle = Label.new()
	_subtitle.text = "%s · %s × %s / pH" % [map.display_name, map.axis_y, map.axis_x]
	_subtitle.theme_type_variation = &"MutedLabel"
	titles.add_child(_subtitle)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_status_chip = _make_chip("準備中")
	_status_label = _status_chip.get_child(0) as Label
	_status_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_status_chip)

	if embedded:
		var back := Button.new()
		back.text = "フィールドへ戻る  Esc"
		back.theme_type_variation = &"GhostButton"
		back.focus_mode = Control.FOCUS_NONE
		back.pressed.connect(_close)
		header.add_child(back)
	return header

func _build_console() -> Control:
	var card := PanelContainer.new()
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 8)
	card.add_child(panel)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(grid)
	grid.add_child(_section("温度", [
		_btn("加熱", "W", func(): sim.heat(1.0)),
		_btn("冷却", "S", func(): sim.heat(-1.0)),
	]))
	grid.add_child(_section("濃度", [
		_btn("加水", "A", func(): sim.add_water(1.0)),
		_btn("蒸留", "D", func(): sim.distill(1.0)),
	]))
	grid.add_child(_section("中和（組成）", [
		_btn("酸 pH↓", "Q", func(): sim.add_acid(0.5)),
		_btn("塩基 pH↑", "E", func(): sim.add_base(0.5)),
	]))
	grid.add_child(_section("バッチ", [
		_make_undo_button(),
		_ghost("リセット", "R", _new_batch),
	]))

	var mats := VBoxContainer.new()
	mats.add_theme_constant_override("separation", 4)
	mats.add_child(_kicker("素材投入（跳躍）"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for i in MATERIAL_IDS.size():
		row.add_child(_mat_btn(MATERIAL_IDS[i], str(i + 1)))
	mats.add_child(row)
	panel.add_child(mats)
	return card

func _build_readout() -> Control:
	var card := PanelContainer.new()
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 8)
	card.add_child(panel)
	panel.add_child(_kicker("計測"))

	# pH の大きなタイル。
	var ph_tile := PanelContainer.new()
	ph_tile.theme_type_variation = &"Tile"
	panel.add_child(ph_tile)
	var ph_row := HBoxContainer.new()
	ph_row.add_theme_constant_override("separation", 10)
	ph_tile.add_child(ph_row)
	var ph_col := VBoxContainer.new()
	ph_col.add_theme_constant_override("separation", 0)
	ph_row.add_child(ph_col)
	ph_col.add_child(_kicker("pH"))
	_ph_value = Label.new()
	_ph_value.theme_type_variation = &"BigValueLabel"
	ph_col.add_child(_ph_value)
	var ph_spacer := Control.new()
	ph_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph_row.add_child(ph_spacer)
	_ph_scale = Label.new()
	_ph_scale.theme_type_variation = &"MutedLabel"
	_ph_scale.size_flags_vertical = Control.SIZE_SHRINK_END
	ph_row.add_child(_ph_scale)

	# その他の計測値を 3 列のタイルで。
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(grid)
	for key in ["conc", "temp", "net", "yield", "path", "equip"]:
		var tile := _make_tile(_tile_title(key))
		_tiles[key] = tile.get_meta("value") as Label
		grid.add_child(tile)

	# 状態チップ。
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	panel.add_child(chips)
	for key in ["region", "target", "hazard"]:
		var chip := _make_chip("")
		_chips[key] = chip
		chips.add_child(chip)

	# 実験ノート（操作列）。
	var note_head := HBoxContainer.new()
	panel.add_child(note_head)
	note_head.add_child(_kicker("実験ノート（操作列）"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_head.add_child(spacer)
	_op_count = Label.new()
	_op_count.theme_type_variation = &"KickerLabel"
	note_head.add_child(_op_count)

	var log_tile := PanelContainer.new()
	log_tile.theme_type_variation = &"Tile"
	panel.add_child(log_tile)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(0, 84)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_tile.add_child(_log)
	return card

# --- 部品 ----------------------------------------------------------------------

func _tile_title(key: String) -> String:
	match key:
		"conc": return "濃度 x"
		"temp": return "温度 y"
		"net": return "net_acid"
		"yield": return "収率"
		"path": return "経路長"
		"equip": return "設備損傷"
	return key

func _kicker(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"KickerLabel"
	return l

func _section(title: String, buttons: Array) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	box.add_child(_kicker(title))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for b in buttons:
		row.add_child(b)
	box.add_child(row)
	return box

func _btn(text: String, key: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = "%s  %s" % [text, key]
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func(): _op(action))
	return b

func _ghost(text: String, key: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = "%s  %s" % [text, key]
	b.theme_type_variation = &"GhostButton"
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	return b

func _make_undo_button() -> Button:
	_undo_btn = _ghost("一手戻す", "Z", _undo)
	return _undo_btn

## 素材ボタン（ドット絵アイコン付き）。
func _mat_btn(mat_id: StringName, key: String) -> Button:
	var b := Button.new()
	var m: MaterialDef = materials.get(mat_id)
	b.text = "%s  %s" % [m.display_name if m != null else String(mat_id), key]
	b.theme_type_variation = &"MatButton"
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tex: Texture2D = load("res://assets/sprites/item_%s.png" % mat_id)
	if tex != null:
		b.icon = tex
	if m != null:
		b.tooltip_text = m.description
	b.pressed.connect(func(): _add_material(mat_id))
	return b

func _make_tile(title: String) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.theme_type_variation = &"Tile"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	tile.add_child(box)
	box.add_child(_kicker(title))
	var value := Label.new()
	value.theme_type_variation = &"ValueLabel"
	box.add_child(value)
	tile.set_meta("value", value)
	return tile

func _make_chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"Chip"
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"KeyLabel"
	chip.add_child(l)
	return chip

## チップの見た目を状態で切り替える。tone は "" / "good" / "warn" / "crit"。
func _set_chip(chip: PanelContainer, text: String, tone: String) -> void:
	var l := chip.get_child(0) as Label
	l.text = text
	match tone:
		"good":
			chip.theme_type_variation = &"ChipGood"
			l.add_theme_color_override("font_color", _palette(&"good"))
		"warn":
			chip.theme_type_variation = &"ChipWarn"
			l.add_theme_color_override("font_color", _palette(&"warn"))
		"crit":
			chip.theme_type_variation = &"ChipCrit"
			l.add_theme_color_override("font_color", _palette(&"crit"))
		_:
			chip.theme_type_variation = &"Chip"
			l.remove_theme_color_override("font_color")

func _palette(name: StringName) -> Color:
	return get_theme_color(name, &"Palette")

# --- 操作と表示更新 --------------------------------------------------------------

func _add_material(mat_id: StringName) -> void:
	var m: MaterialDef = materials.get(mat_id)
	if m == null:
		return
	_op(func(): sim.add_material(m))

func _op(action: Callable) -> void:
	if sim.batch_lost:
		return
	action.call()
	_trace.append(sim.position)
	_refresh()

func _refresh() -> void:
	view.trace = _trace
	view.refresh()
	var p := sim.ph()
	var tgt := sim.reached_target()
	var reg := sim.current_region()

	_ph_value.text = "%.2f" % p
	_ph_value.add_theme_color_override("font_color", _ph_color(p))
	_ph_scale.text = _ph_scale_text(p)

	_tiles["conc"].text = "%.2f" % sim.position.x
	_tiles["temp"].text = "%.2f" % sim.position.y
	_tiles["net"].text = "%+.2f" % sim.net_acid
	_tiles["path"].text = "%.1f" % sim.path_length
	_tiles["equip"].text = "%.1f" % sim.equipment_damage
	var yield_label: Label = _tiles["yield"]
	if sim.batch_lost:
		yield_label.text = "0%"
		yield_label.add_theme_color_override("font_color", _palette(&"crit"))
	elif tgt != null:
		yield_label.text = "%d%%" % int(round(sim.yield_ratio() * 100.0))
		yield_label.add_theme_color_override("font_color", _palette(&"good"))
	else:
		# 目標外では試算値（設計書 reaction-map.md §収率）。控えめに表示する。
		yield_label.text = "≈%d%%" % int(round(sim.yield_ratio() * 100.0))
		yield_label.add_theme_color_override("font_color", _palette(&"muted"))

	_set_chip(_chips["region"], "領域: %s" % (reg.label if reg != null else "—"), "warn" if (reg != null and tgt == null and not sim.batch_lost) else "")
	_set_chip(_chips["target"], "目標: %s" % (tgt.label if tgt != null else "未到達"), "good" if tgt != null else "")
	_set_chip(_chips["hazard"], "暴走: %s" % ("バッチ全損" if sim.batch_lost else "正常"), "crit" if sim.batch_lost else "good")

	if sim.batch_lost:
		_set_chip(_status_chip, "全損 — リセットして再試行", "crit")
	elif tgt != null:
		_set_chip(_status_chip, "%s に到達 · 収率 %d%%" % [tgt.label, int(round(sim.yield_ratio() * 100.0))], "good")
	elif reg != null:
		_set_chip(_status_chip, "%s の領域内 · pH 条件を満たしていない" % reg.label, "warn")
	else:
		_set_chip(_status_chip, "試行中", "")

	_op_count.text = "%d 手" % sim.operations.size()
	_undo_btn.disabled = sim.operations.is_empty()
	_log.text = _log_text()

func _log_text() -> String:
	if sim.operations.is_empty():
		return "[color=#8a8172]まだ操作していません。W/A/S/D で動かし、1〜4 で素材を投入。[/color]"
	var lines := PackedStringArray()
	for i in sim.operations.size():
		var op: Dictionary = sim.operations[i]
		lines.append("[color=#8a8172]%2d.[/color] %s" % [i + 1, _op_text(op)])
	return "\n".join(lines)

func _op_text(op: Dictionary) -> String:
	var kind: StringName = op.get("op", &"")
	var name: String = OP_LABELS.get(kind, String(kind))
	if kind == &"material":
		var m: MaterialDef = materials.get(op.get("material_id"))
		return "%s %s" % [name, m.display_name if m != null else String(op.get("material_id"))]
	var amount: float = op.get("amount", 0.0)
	if kind == &"heat" and amount < 0.0:
		return "冷却 %.1f" % absf(amount)
	return "%s %+.1f" % [name, amount]

func _ph_scale_text(p: float) -> String:
	if p < 2.0:
		return "強酸性"
	elif p < 6.5:
		return "酸性"
	elif p <= 7.5:
		return "中性"
	elif p < 12.0:
		return "塩基性"
	return "強塩基性"

func _ph_color(p: float) -> Color:
	if p < 4.0:
		return _palette(&"crit")
	elif p < 6.5:
		return _palette(&"warn")
	elif p <= 7.5:
		return _palette(&"good")
	return Color(0.18, 0.48, 0.69)
