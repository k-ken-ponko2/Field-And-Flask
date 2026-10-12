## 素材棚の背景（木の壁と棚板）。子の ShelfItem を並べる台。
class_name ShelfPanel
extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), LabAssets.WOOD)
	var shelf: Texture2D = LabAssets.TEX[&"shelf"]
	var sw := shelf.get_width() * LabAssets.PX
	for y in [100.0, 228.0]:
		var x := 0.0
		while x < size.x:
			LabAssets.blit(self, shelf, Vector2(x, y))
			x += sw
	var font := get_theme_default_font()
	draw_string(font, Vector2(372, 24), "素材は釜へ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.72, 0.6))
	draw_string(font, Vector2(372, 42), "熱源は火へドラッグ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.72, 0.6))
