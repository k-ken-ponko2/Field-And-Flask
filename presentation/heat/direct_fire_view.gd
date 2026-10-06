## ① 直火の UI：タイミングよく薪を入れる（クリック）。
##
## 見た目: 石で囲った焚き火と、脇の薪の山。クリックで薪が飛んで火に入る。
## タイミングの手がかり: 燃料ゲージの熾火帯 ＋ 火の周りのリング（好機なら明るく脈打つ）＋ 一言。
class_name DirectFireView
extends FireView

## 薪が飛ぶアニメの長さ（秒）。
const LOG_FLIGHT := 0.28

var _log_t := -1.0          ## 飛行中の薪の進行度（-1 = 無し）
var _flash_text := ""
var _flash_color := Color.WHITE
var _flash_t := 0.0

func _on_setup() -> void:
	_log_t = -1.0
	_flash_t = 0.0

func _gui_input(event: InputEvent) -> void:
	if sim == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var r := sim.feed()
		if r["ok"]:
			_log_t = 0.0
			_flash(r["timing"])
			fed.emit(r["timing"])

func _flash(timing: StringName) -> void:
	_flash_t = 1.2
	match timing:
		&"good":
			_flash_text = "いい頃合い！"
			_flash_color = Color(1.0, 0.85, 0.4)
		&"early":
			_flash_text = "早すぎた… 窒息"
			_flash_color = Color(0.7, 0.7, 0.75)
		_:
			_flash_text = "点け直し…"
			_flash_color = Color(0.9, 0.6, 0.5)

func _on_process(delta: float) -> void:
	if _log_t >= 0.0:
		_log_t += delta / LOG_FLIGHT
		if _log_t >= 1.0:
			_log_t = -1.0
	_flash_t = maxf(0.0, _flash_t - delta)

func _is_good_moment() -> bool:
	return not sim.is_out() and sim.fuel <= FireSim.FEED_WINDOW_HIGH

func _pile_origin() -> Vector2:
	return Vector2(size.x * 0.16, size.y * 0.84)

func _draw_back() -> void:
	# 地面と石の囲い（奥半分）。
	draw_circle(fire_origin() + Vector2(0, 14), 110.0, Color(0.16, 0.13, 0.11))
	for i in 7:
		var a := PI + PI * float(i) / 6.0
		_draw_stone(fire_origin() + Vector2(cos(a) * 112.0, sin(a) * 40.0 + 14.0))
	# タイミングのリング。
	var good := _is_good_moment()
	var pulse := 0.5 + 0.5 * sin(_flicker * 6.0)
	var ring_col := Color(1.0, 0.8, 0.3, 0.35 + 0.5 * pulse) if good else Color(0.5, 0.45, 0.4, 0.25)
	draw_arc(fire_origin() + Vector2(0, 14), 128.0 + (6.0 * pulse if good else 0.0), 0.0, TAU, 64, ring_col, 3.0)

func _draw_front() -> void:
	# 石の囲い（手前半分）。
	for i in 6:
		var a := PI * float(i) / 5.0
		_draw_stone(fire_origin() + Vector2(cos(a) * 112.0, sin(a) * 40.0 + 14.0))
	# 薪の山。
	var p := _pile_origin()
	for i in 4:
		var y := p.y - i * 12.0
		var x := p.x + (i % 2) * 8.0 - 4.0
		draw_line(Vector2(x - 34, y), Vector2(x + 34, y), Color(0.42, 0.27, 0.13), 10.0)
		draw_circle(Vector2(x + 34, y), 5.0, Color(0.72, 0.55, 0.32))
	draw_string(get_theme_default_font(), p + Vector2(-20, 28), "薪", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.72, 0.6))
	# 飛んでいる薪。
	if _log_t >= 0.0:
		var t := _log_t
		var pos := p.lerp(fire_origin(), t) + Vector2(0, -120.0 * sin(t * PI))
		var ang := t * TAU
		draw_set_transform(pos, ang, Vector2.ONE)
		draw_line(Vector2(-26, 0), Vector2(26, 0), Color(0.5, 0.32, 0.16), 9.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 一言（状況の案内とクリックの結果）。
	var msg: String
	var col: Color
	if _flash_t > 0.0:
		msg = _flash_text
		col = _flash_color
	elif sim.is_out():
		msg = "火が消えた — クリックで薪を入れて点け直す"
		col = Color(0.9, 0.6, 0.5)
	elif _is_good_moment():
		msg = "今だ！ クリックで薪を入れる"
		col = Color(1.0, 0.85, 0.4)
	else:
		msg = "まだ燃えている… 熾火になるまで待つ"
		col = Color(0.75, 0.7, 0.65)
	_draw_caption(msg, 70.0, col, 18)

func _draw_gauge_overlay(gauge: Rect2) -> void:
	var w := gauge.size.x * FireSim.FEED_WINDOW_HIGH
	var band := Rect2(gauge.position - Vector2(0, 4), Vector2(w, gauge.size.y + 8))
	draw_rect(band, Color(1.0, 0.7, 0.3, 0.25))
	draw_rect(band, Color(1.0, 0.7, 0.3, 0.9), false, 1.5)
	draw_string(get_theme_default_font(), gauge.position + Vector2(w + 6, -8), "← 熾火（薪の好機）", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.8, 0.5))

func _draw_stone(at: Vector2) -> void:
	draw_set_transform(at, 0.0, Vector2(1.0, 0.7))
	draw_circle(Vector2.ZERO, 20.0, Color(0.36, 0.34, 0.33))
	draw_circle(Vector2(-5, -5), 12.0, Color(0.44, 0.42, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
