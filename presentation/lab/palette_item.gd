## パレットの道具 1 つ（ドラッグ元）。作業台の火の上へドロップして使う。
##
## _get_drag_data が返す辞書 {kind: &"heat_source"|&"vessel", id, path} を、
## FireView 側の _drop_data が受け取り、LabBench（core）の place_* に変換される。
class_name PaletteItem
extends PanelContainer

var kind: StringName
var id: StringName
var path: String
var icon: Texture2D
var label_text: String
var hint_text: String

func setup(p_kind: StringName, p_id: StringName, p_path: String, p_icon: Texture2D, p_label: String, p_hint: String) -> void:
	kind = p_kind
	id = p_id
	path = p_path
	icon = p_icon
	label_text = p_label
	hint_text = p_hint
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var tr := TextureRect.new()
	tr.texture = icon
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(40, 40)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	row.add_child(tr)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var l := Label.new()
	l.text = label_text
	col.add_child(l)
	var h := Label.new()
	h.text = hint_text
	h.add_theme_font_size_override("font_size", 11)
	h.add_theme_color_override("font_color", Color(0.55, 0.5, 0.42))
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(h)

func _get_drag_data(_at: Vector2) -> Variant:
	# ドラッグ中はアイコンを指に付ける。
	var preview := TextureRect.new()
	preview.texture = icon
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.custom_minimum_size = Vector2(56, 56)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(preview)
	return {"kind": kind, "id": id, "path": path}
