## 採取マップの HUD（presentation 層・仮UI）。
##
## 季節と日付のカード、素材ポーチ（所持数）、操作ヒント、作業台に近づいたときの
## プロンプト、短いトーストを表示する。状態は field.gd から渡されるだけで、
## ここは描画と演出のみ（設計書 §8）。見た目はテーマの type variation で統一する。
extends CanvasLayer

const SEASON_NAMES := ["春", "夏", "秋", "冬"]
const SEASON_TOKENS: Array[StringName] = [&"season_spring", &"season_summer", &"season_autumn", &"season_winter"]
const MARGIN := 16
const TOAST_SECONDS := 3.2

var _root: Control
var _season_swatch: ColorRect
var _date_label: Label
var _year_label: Label
var _count_labels: Dictionary = {}
var _prompt: PanelContainer
var _prompt_label: Label
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_calendar_card()
	_build_hint_card()
	_build_prompt()
	_build_toast()

# --- 公開 API ------------------------------------------------------------------

func set_calendar(cal: GameCalendar) -> void:
	var season := int(cal.season())
	_season_swatch.color = _palette(SEASON_TOKENS[season])
	_date_label.text = "%s %d日目" % [SEASON_NAMES[season], cal.day_of_season()]
	_year_label.text = "%d年目" % cal.year()

## 所持素材を表示する。items の各要素は { "id": StringName, "name": String, "count": int, "icon": Texture2D }。
func set_inventory(items: Array) -> void:
	var old := _root.get_node_or_null("Pouch")
	if old != null:
		old.queue_free()
	_count_labels.clear()

	var card := PanelContainer.new()
	card.name = "Pouch"
	card.theme_type_variation = &"HudCard"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	for item in items:
		row.add_child(_make_slot(item))
	_root.add_child(card)
	_place(card, Control.PRESET_CENTER_BOTTOM)

func set_prompt(text: String, shown: bool) -> void:
	if text != "":
		_prompt_label.text = text
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_prompt, "modulate:a", 1.0 if shown else 0.0, 0.15)

func toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)

# --- 構築 ----------------------------------------------------------------------

func _build_calendar_card() -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"HudCard"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	_season_swatch = ColorRect.new()
	_season_swatch.custom_minimum_size = Vector2(12, 12)
	_season_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_season_swatch)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	_date_label = Label.new()
	_date_label.theme_type_variation = &"ValueLabel"
	col.add_child(_date_label)
	_year_label = Label.new()
	_year_label.theme_type_variation = &"KickerLabel"
	col.add_child(_year_label)

	_root.add_child(card)
	_place(card, Control.PRESET_TOP_LEFT)

func _build_hint_card() -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"HudCard"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(_key_hint("WASD", "移動"))
	row.add_child(_key_hint("E", "調べる"))
	_root.add_child(card)
	_place(card, Control.PRESET_TOP_RIGHT)

func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt.theme_type_variation = &"HudCard"
	_prompt.modulate.a = 0.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_prompt.add_child(row)
	row.add_child(_key_chip("E"))
	_prompt_label = Label.new()
	_prompt_label.text = "調べる"
	row.add_child(_prompt_label)
	_root.add_child(_prompt)
	_place(_prompt, Control.PRESET_CENTER_BOTTOM, 104)

func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.theme_type_variation = &"HudCard"
	_toast.modulate.a = 0.0
	_toast_label = Label.new()
	_toast.add_child(_toast_label)
	_root.add_child(_toast)
	_place(_toast, Control.PRESET_CENTER_TOP)

func _make_slot(item: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var slot := PanelContainer.new()
	slot.theme_type_variation = &"HudSlot"
	box.add_child(slot)
	var inner := Control.new()
	inner.custom_minimum_size = Vector2(40, 40)
	slot.add_child(inner)

	# 親（inner）のサイズが後から確定しても崩れないよう、辺に対する固定オフセットで置く。
	var icon := TextureRect.new()
	icon.texture = item.get("icon")
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	inner.add_child(icon)

	var count := Label.new()
	count.text = str(item.get("count", 0))
	count.theme_type_variation = &"KeyLabel"
	count.add_theme_color_override("font_color", _palette(&"ink"))
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -20
	count.offset_top = -16
	count.offset_right = -2
	count.offset_bottom = -1
	inner.add_child(count)
	_count_labels[item.get("id")] = count

	var name_label := Label.new()
	name_label.text = String(item.get("name", ""))
	name_label.theme_type_variation = &"KickerLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	return box

func _key_hint(key: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_key_chip(key))
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"MutedLabel"
	row.add_child(l)
	return row

func _key_chip(key: String) -> Control:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"Chip"
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = key
	l.theme_type_variation = &"KeyLabel"
	chip.add_child(l)
	return chip

## コンテナ外のカードを画面端に置く。中身が増減してもアンカー側へ伸びるようにする。
func _place(ctrl: Control, preset: Control.LayoutPreset, margin: int = MARGIN) -> void:
	ctrl.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)
	match preset:
		Control.PRESET_TOP_LEFT:
			ctrl.grow_horizontal = Control.GROW_DIRECTION_END
			ctrl.grow_vertical = Control.GROW_DIRECTION_END
		Control.PRESET_TOP_RIGHT:
			ctrl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			ctrl.grow_vertical = Control.GROW_DIRECTION_END
		Control.PRESET_CENTER_TOP:
			ctrl.grow_horizontal = Control.GROW_DIRECTION_BOTH
			ctrl.grow_vertical = Control.GROW_DIRECTION_END
		Control.PRESET_CENTER_BOTTOM:
			ctrl.grow_horizontal = Control.GROW_DIRECTION_BOTH
			ctrl.grow_vertical = Control.GROW_DIRECTION_BEGIN

func _palette(name: StringName) -> Color:
	return _root.get_theme_color(name, &"Palette")
