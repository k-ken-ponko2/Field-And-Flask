## ③ ふいご炉の UI（ドット絵）：ふいごを押し続ける（クリック長押し）。
##
## 見た目: 粘土の炉と、横から羽口で繋がったふいご。押している間ふいごが縮み（3コマ）、
## 羽口から空気のドットが噴き出して火勢が積み上がる。離すと戻り、火勢が衰える。
class_name BellowsFireView
extends FireView

var _holding := false
var _squeeze := 0.0         ## ふいごの縮み（0=開、1=押し切り）
var _puff := 0.0            ## 羽口の噴き出しの見た目

func _on_setup() -> void:
	_holding = false
	_squeeze = 0.0
	_puff = 0.0

func _gui_input(event: InputEvent) -> void:
	if sim == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_holding = event.pressed

func _on_process(delta: float) -> void:
	if _holding:
		sim.pump(delta)
	_squeeze = lerpf(_squeeze, 1.0 if _holding else 0.0, minf(1.0, delta * (4.0 if _holding else 2.5)))
	_puff = lerpf(_puff, sim.drive, minf(1.0, delta * 6.0))

func _furnace_top_left() -> Vector2:
	var sz: Vector2 = TEX[&"furnace"].get_size() * PX
	return Vector2(size.x * 0.62 - sz.x * 0.5, size.y * 0.8 - sz.y)

func fire_origin() -> Vector2:
	# 炉口の床。
	return _furnace_top_left() + Vector2(TEX[&"furnace"].get_width() * PX * 0.5, (TEX[&"furnace"].get_height() - 4) * PX)

func _bellows_bottom() -> Vector2:
	return Vector2(size.x * 0.2, size.y * 0.72)

func _draw_back() -> void:
	_blit(TEX[&"furnace"], _furnace_top_left())
	# 羽口（ふいごの送風口 → 炉の穴）。
	var from := _bellows_bottom() + Vector2(14 * PX, -7 * PX)
	var hole := _furnace_top_left() + Vector2(2 * PX, 42 * PX)
	var seg: Vector2 = TEX[&"tuyere"].get_size() * PX
	var n := int(ceil((hole.x - from.x) / seg.x))
	for i in n:
		_blit(TEX[&"tuyere"], Vector2(from.x + i * seg.x, from.y - seg.y * 0.5))

func _draw_front() -> void:
	var b := _bellows_bottom()
	# 羽口からの噴き出し（炉の中へ）。
	var hole := _furnace_top_left() + Vector2(8 * PX, 42 * PX)
	var jets := int(round(_puff * 6.0))
	for i in jets:
		var t := fmod(_flicker * 3.0 + i * 0.3, 1.0)
		var from := hole + Vector2(0, (i - jets * 0.5) * 3.0)
		var to := fire_origin() + Vector2(-6 * PX, -20.0 + (i - jets * 0.5) * 8.0)
		_blit_bottom(TEX[&"air"], from.lerp(to, t), false, Color(1, 1, 1, 1.0 - t))
	# ふいご（縮みで3コマ）。
	var frame := 0 if _squeeze < 0.33 else (1 if _squeeze < 0.75 else 2)
	_blit_bottom(TEX[&"bellows_%d" % frame], b)
	draw_string(get_theme_default_font(), b + Vector2(-20, 24), "ふいご", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.72, 0.6))
	# 押し込みの輪（ドット）：押している間に満ちる。
	var ring_c := b + Vector2(0, -150)
	_draw_dot_ring(ring_c, 26.0, 16, _squeeze, Color(0.6, 0.8, 1.0), Color(0.3, 0.27, 0.25))
	var msg := "押し続けている… 火勢 %d%%" % int(round(sim.drive * 100.0)) if _holding else "火の上でクリックを押し続けてふいごを踏む"
	_draw_caption(msg, 44.0, Color(0.85, 0.9, 1.0), 18)
