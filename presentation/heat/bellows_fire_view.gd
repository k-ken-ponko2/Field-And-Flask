## ③ ふいご炉の UI：ふいごを押し続ける（クリック長押し）。
##
## 見た目: 粘土の炉と、横から羽口で繋がったふいご。押している間ふいごが縮み、
## 羽口から空気が噴き出して火勢が積み上がる。離すと戻り、火勢が衰える。
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

func fire_origin() -> Vector2:
	return Vector2(size.x * 0.62, size.y * 0.7)

func _bellows_origin() -> Vector2:
	return Vector2(size.x * 0.17, size.y * 0.62)

func _draw_back() -> void:
	var o := fire_origin()
	# 粘土の炉（ドーム）と炉口。
	draw_set_transform(o + Vector2(0, 10), 0.0, Vector2(1.0, 1.15))
	draw_circle(Vector2.ZERO, 150.0, Color(0.42, 0.3, 0.2))
	draw_circle(Vector2.ZERO, 128.0, Color(0.18, 0.12, 0.09))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 羽口（ふいご → 炉）。
	var b := _bellows_origin()
	draw_line(b + Vector2(70, 0), o + Vector2(-120, 0), Color(0.3, 0.3, 0.32), 14.0)
	draw_line(b + Vector2(70, 0), o + Vector2(-120, 0), Color(0.45, 0.45, 0.48), 8.0)

func _draw_front() -> void:
	var o := fire_origin()
	var b := _bellows_origin()
	# 炉の手前の床。
	draw_rect(Rect2(o.x - 170, o.y + 24, 340, 18), Color(0.36, 0.27, 0.19))
	# 羽口からの噴き出し。
	var jets := int(round(_puff * 6.0))
	for i in jets:
		var t := fmod(_flicker * 3.0 + i * 0.3, 1.0)
		var from := o + Vector2(-118, (i - jets * 0.5) * 4.0)
		var to := o + Vector2(-20, -30.0 + (i - jets * 0.5) * 10.0)
		var p := from.lerp(to, t)
		draw_line(p, p + (to - from).normalized() * 14.0, Color(0.8, 0.9, 1.0, 0.6 * (1.0 - t)), 2.0)
	# ふいご本体：上下の板と蛇腹。押すほど上板が下がる。
	var open_h := 110.0
	var gap := open_h * (1.0 - 0.8 * _squeeze)
	var w := 130.0
	var bottom := b + Vector2(0, 30)
	var top := bottom - Vector2(0, gap)
	# 蛇腹。
	var folds := 6
	var pts := PackedVector2Array()
	for i in folds + 1:
		var y := lerpf(bottom.y, top.y, float(i) / folds)
		var bulge := 18.0 if i % 2 == 1 else 0.0
		pts.append(Vector2(bottom.x - w * 0.5 - bulge, y))
	for i in folds + 1:
		var y := lerpf(top.y, bottom.y, float(i) / folds)
		var bulge := 18.0 if i % 2 == 1 else 0.0
		pts.append(Vector2(bottom.x + w * 0.5 + bulge, y))
	draw_colored_polygon(pts, Color(0.5, 0.3, 0.2))
	draw_polyline(pts, Color(0.3, 0.18, 0.12), 2.0)
	# 板と取っ手。
	draw_rect(Rect2(bottom.x - w * 0.5 - 8, bottom.y - 6, w + 16, 12), Color(0.6, 0.45, 0.28))
	draw_rect(Rect2(top.x - w * 0.5 - 8, top.y - 6, w + 16, 12), Color(0.68, 0.52, 0.32))
	draw_line(top + Vector2(0, -6), top + Vector2(0, -34), Color(0.75, 0.6, 0.4), 8.0)
	# 押し込みの輪ゲージ（押している間に満ちる）。
	var ring_c := b + Vector2(0, -120)
	draw_arc(ring_c, 26.0, 0.0, TAU, 48, Color(0.3, 0.27, 0.25), 5.0)
	if _squeeze > 0.01:
		draw_arc(ring_c, 26.0, -PI * 0.5, -PI * 0.5 + TAU * _squeeze, 48, Color(0.6, 0.8, 1.0), 5.0)
	draw_string(get_theme_default_font(), b + Vector2(-26, 70), "ふいご", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.72, 0.6))
	var msg := "押し続けている… 火勢 %d%%" % int(round(sim.drive * 100.0)) if _holding else "火の上でクリックを押し続けてふいごを踏む"
	_draw_caption(msg, 44.0, Color(0.85, 0.9, 1.0), 18)
