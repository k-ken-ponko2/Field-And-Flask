## ② 囲い炉の UI：あおぐ（マウスのスライド）。
##
## 見た目: 土の囲いと煙突に守られた火。うちわがマウスの横位置についてきて、
## 動かした量に応じて風の筋が火へ流れる。手を止めると風が消え火勢が落ちる。
class_name FanFireView
extends FireView

## 1 単位の「あおぐ距離」に相当するピクセル数。
const FAN_PIXELS_PER_UNIT := 100.0

var _fan_x := -1.0          ## うちわの横位置（-1 = 未設定、最初の描画で中央に置く）
var _tilt := 0.0            ## うちわの傾き（動かした方向に応じて）
var _wind := 0.0            ## 風の見た目の強さ（火勢に追従）

func _on_setup() -> void:
	_fan_x = -1.0
	_tilt = 0.0
	_wind = 0.0

func _gui_input(event: InputEvent) -> void:
	if sim == null:
		return
	if event is InputEventMouseMotion:
		var rel: Vector2 = event.relative
		_fan_x = clampf(event.position.x, 60.0, size.x - 60.0)
		_tilt = clampf(_tilt + rel.x * 0.01, -0.5, 0.5)
		sim.fan(rel.length() / FAN_PIXELS_PER_UNIT)

func _on_process(delta: float) -> void:
	_tilt = lerpf(_tilt, 0.0, minf(1.0, delta * 6.0))
	_wind = lerpf(_wind, sim.drive, minf(1.0, delta * 5.0))

func fire_origin() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.66)

func _draw_back() -> void:
	var o := fire_origin()
	# 土の囲い（奥の壁）と煙突。
	draw_rect(Rect2(o.x - 170, o.y - 230, 340, 250), Color(0.3, 0.22, 0.16))
	draw_rect(Rect2(o.x - 150, o.y - 210, 300, 230), Color(0.2, 0.14, 0.1))
	draw_rect(Rect2(o.x - 40, o.y - 330, 80, 110), Color(0.34, 0.25, 0.18))
	draw_rect(Rect2(o.x - 28, o.y - 330, 56, 110), Color(0.12, 0.1, 0.09))
	# 煙（火勢があれば濃く）。
	var smoke_a := 0.08 + 0.25 * _wind
	for i in 3:
		var y := o.y - 340.0 - i * 26.0 - fmod(_flicker * 20.0, 26.0)
		draw_circle(Vector2(o.x + sin(_flicker * 1.5 + i) * 12.0, y), 16.0 + i * 5.0, Color(0.6, 0.6, 0.6, smoke_a * (1.0 - i * 0.25)))

func _draw_front() -> void:
	var o := fire_origin()
	# 囲いの手前の縁（炉口）。
	draw_rect(Rect2(o.x - 170, o.y + 20, 340, 16), Color(0.36, 0.27, 0.19))
	draw_rect(Rect2(o.x - 170, o.y - 230, 24, 250), Color(0.36, 0.27, 0.19))
	draw_rect(Rect2(o.x + 146, o.y - 230, 24, 250), Color(0.36, 0.27, 0.19))
	# 風の筋：うちわから炉口へ。
	if _fan_x < 0.0:
		_fan_x = size.x * 0.5
	var fan_pos := Vector2(_fan_x, size.y * 0.86)
	var streaks := int(round(_wind * 7.0))
	for i in streaks:
		var t := fmod(_flicker * 2.5 + i * 0.37, 1.0)
		var from := fan_pos + Vector2((i - streaks * 0.5) * 10.0, -20.0)
		var to := o + Vector2((i - streaks * 0.5) * 14.0, 10.0)
		var p := from.lerp(to, t)
		draw_line(p, p + (to - from).normalized() * 18.0, Color(0.8, 0.9, 1.0, 0.5 * (1.0 - t)), 2.0)
	# うちわ（マウスに追従、動かした方向に傾く）。
	draw_set_transform(fan_pos, _tilt, Vector2.ONE)
	draw_line(Vector2(0, 0), Vector2(0, 60), Color(0.55, 0.4, 0.25), 6.0)
	draw_set_transform(fan_pos, _tilt, Vector2(1.0, 0.75))
	draw_circle(Vector2(0, -20), 48.0, Color(0.85, 0.72, 0.5))
	draw_circle(Vector2(0, -20), 48.0, Color(0.55, 0.4, 0.25), false, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# あおぎ量のメーター。
	var meter := Rect2(size.x - 36, 60, 14, size.y * 0.45)
	draw_rect(meter, Color(0.2, 0.17, 0.15))
	var h := meter.size.y * _wind
	draw_rect(Rect2(meter.position.x, meter.end.y - h, meter.size.x, h), Color(0.6, 0.8, 1.0))
	draw_string(get_theme_default_font(), Vector2(size.x - 52, meter.end.y + 18), "風", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.72, 0.6))
	var idle := sim.source.idle_drive
	var msg := "火の上でマウスを左右に動かしてあおぐ" if _wind < idle + 0.1 else ("もっと！" if _wind < 0.7 else "いい風だ")
	_draw_caption(msg, 44.0, Color(0.85, 0.9, 1.0), 18)
