## 素材棚の 1 品（ドラッグ元）。アイコンと名前だけの小さな札。
## _get_drag_data は {kind: &"material"|&"heat_source", id, path} を返し、CauldronStation が受け取る。
class_name ShelfItem
extends Control

var kind: StringName
var id: StringName
var path: String
var icon: Texture2D
var label_text: String

func setup(p_kind: StringName, p_id: StringName, p_path: String, p_icon: Texture2D, p_label: String) -> void:
	kind = p_kind
	id = p_id
	path = p_path
	icon = p_icon
	label_text = p_label
	custom_minimum_size = Vector2(88, 100)
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = p_label
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## アイコンの拡大率（最大 64px に収まる整数倍、最低 1）。
func _scale() -> float:
	var m := maxf(icon.get_width(), icon.get_height())
	return maxf(1.0, floorf(64.0 / m))

func _draw() -> void:
	var sz := icon.get_size() * _scale()
	draw_texture_rect(icon, Rect2(Vector2((size.x - sz.x) * 0.5, 6 + (64.0 - sz.y) * 0.5), sz), false)
	var font := get_theme_default_font()
	var tw := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, Vector2((size.x - tw) * 0.5, size.y - 10), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.93, 0.86, 0.72))

func _get_drag_data(_at: Vector2) -> Variant:
	var preview := TextureRect.new()
	preview.texture = icon
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.custom_minimum_size = icon.get_size() * _scale()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1, 1, 1, 0.9)
	set_drag_preview(preview)
	return {"kind": kind, "id": id, "path": path}
