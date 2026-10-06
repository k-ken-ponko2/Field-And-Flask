## ② 囲い炉の UI（ドット絵）：あおぐ（マウスのスライド）。
##
## 見た目: 土の囲いと煙突に守られた火。うちわがマウスの横位置についてきて、
## 動かした量に応じて風のドットが炉口へ流れる。手を止めると風が消え火勢が落ちる。
class_name FanFireView
extends FireView

## 1 単位の「あおぐ距離」に相当するピクセル数。
const FAN_PIXELS_PER_UNIT := 100.0

var _fan_x := -1.0          ## うちわの横位置（-1 = 未設定、最初の描画で中央に置く）
var _lean := 0.0            ## 最後に動かした向き（-1..1、うちわの反転に使う）
var _wind := 0.0            ## 風の見た目の強さ（火勢に追従）

func _on_setup() -> void:
	_fan_x = -1.0
	_lean = 0.0
	_wind = 0.0

func _gui_input(event: InputEvent) -> void:
	if sim == null:
		return
	if event is InputEventMouseMotion:
		var rel: Vector2 = event.relative
		_fan_x = clampf(event.position.x, 60.0, size.x - 60.0)
		if absf(rel.x) > 0.5:
			_lean = signf(rel.x)
		sim.fan(rel.length() / FAN_PIXELS_PER_UNIT)

func _on_process(delta: float) -> void:
	_wind = lerpf(_wind, sim.drive, minf(1.0, delta * 5.0))

func fire_origin() -> Vector2:
	# 囲いの炉口の床（囲いスプライトの下端から床の厚みぶん上）。
	return _hearth_top_left() + Vector2(TEX[&"hearth"].get_width() * PX * 0.5, (TEX[&"hearth"].get_height() - 4) * PX)

func _hearth_top_left() -> Vector2:
	var sz: Vector2 = TEX[&"hearth"].get_size() * PX
	return Vector2(size.x * 0.5 - sz.x * 0.5, size.y * 0.66 - sz.y + 4 * PX)

func _draw_back() -> void:
	_blit(TEX[&"hearth"], _hearth_top_left())
	# 煙（火勢があれば濃く）。煙突の上から立ち上る。
	var chimney := _hearth_top_left() + Vector2(TEX[&"hearth"].get_width() * PX * 0.5, 0)
	var alpha := 0.25 + 0.6 * _wind
	for i in 3:
		var rise := fmod(_flicker * 24.0 + i * 30.0, 90.0)
		var tex: Texture2D = TEX[&"smoke_%d" % i]
		var sway := sin(_flicker * 1.5 + i) * 10.0
		_blit_bottom(tex, chimney + Vector2(sway, -rise), false, Color(1, 1, 1, alpha * (1.0 - rise / 90.0)))

func _draw_front() -> void:
	if _fan_x < 0.0:
		_fan_x = size.x * 0.5
	var fan_pos := Vector2(_fan_x, size.y * 0.9)
	var mouth := fire_origin() + Vector2(0, -20.0)
	# 風のドット：うちわから炉口へ流れる。
	var streaks := int(round(_wind * 7.0))
	for i in streaks:
		var t := fmod(_flicker * 2.5 + i * 0.37, 1.0)
		var from := fan_pos + Vector2((i - streaks * 0.5) * 10.0, -80.0)
		var to := mouth + Vector2((i - streaks * 0.5) * 14.0, 0.0)
		var p := from.lerp(to, t)
		_dot(p, 2, 1, Color(0.8, 0.9, 1.0, 0.7 * (1.0 - t)))
	# うちわ（マウスに追従、動かした向きに反転）。
	_blit_bottom(TEX[&"uchiwa"], fan_pos, _lean < 0.0)
	# あおぎ量のメーター（縦のセグメント）。
	var segs := 16
	var x := size.x - 40.0
	var y1 := size.y * 0.55
	for i in segs:
		var filled := float(i) / segs < _wind
		_dot(Vector2(x, y1 - i * 3 * PX), 3, 2, Color(0.6, 0.8, 1.0) if filled else Color(0.2, 0.17, 0.15))
	draw_string(get_theme_default_font(), Vector2(x - 4, y1 + 26), "風", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.72, 0.6))
	var idle := sim.source.idle_drive
	var msg := "火の上でマウスを左右に動かしてあおぐ" if _wind < idle + 0.1 else ("もっと！" if _wind < 0.7 else "いい風だ")
	_draw_caption(msg, 44.0, Color(0.85, 0.9, 1.0), 18)
