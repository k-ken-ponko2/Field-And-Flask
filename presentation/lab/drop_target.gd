## 何も据えていない作業台の受け皿。熱源のドロップだけを受け付ける。
class_name DropTarget
extends Control

signal item_dropped(data: Dictionary, at: Vector2)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == &"heat_source"

func _drop_data(at: Vector2, data: Variant) -> void:
	item_dropped.emit(data, at)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.11, 0.09, 0.08))
	draw_rect(Rect2(Vector2(24, 24), size - Vector2(48, 48)), Color(0.35, 0.3, 0.25), false, 2.0)
