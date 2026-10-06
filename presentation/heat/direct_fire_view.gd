## ① 直火の UI（ドット絵）：タイミングよく薪を入れる（クリック）。
##
## 見た目: 石で囲った焚き火と、脇の薪の山。クリックで薪が飛んで火に入る。
## タイミングの手がかり: 燃料ゲージの熾火帯 ＋ 火を囲むドットの輪（好機なら明るく回る）＋ 一言。
class_name DirectFireView
extends FireView

## 薪が飛ぶアニメの長さ（秒）。
const LOG_FLIGHT := 0.28
## 石の輪の半径（奥は縦に潰す）。
const RING_RX := 120.0
const RING_RY := 44.0

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

func _stone_at(angle: float) -> Vector2:
	return fire_origin() + Vector2(cos(angle) * RING_RX, sin(angle) * RING_RY + 10.0)

func _draw_back() -> void:
	var c := fire_origin() + Vector2(0, 10)
	# 地面（焚き火の跡）。
	draw_set_transform(c, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, RING_RX - 8.0, Color(0.16, 0.13, 0.11))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 石の囲い（奥半分）。
	for i in 7:
		_blit_bottom(TEX[&"stone"], _stone_at(PI + PI * float(i) / 6.0))
	# タイミングの輪：好機なら明るいドットが回る、それ以外は暗い輪。
	var good := _is_good_moment()
	var spin := fmod(_flicker * 1.5, 1.0)
	var dots := 28
	for i in dots:
		var a := -PI * 0.5 + TAU * float(i) / dots
		var p := c + Vector2(cos(a) * (RING_RX + 24.0), sin(a) * (RING_RY + 16.0))
		var lit := good and fmod(float(i) / dots - spin + 1.0, 1.0) < 0.25
		var col := Color(1.0, 0.8, 0.3) if lit else (Color(0.6, 0.45, 0.25) if good else Color(0.3, 0.27, 0.25))
		_dot(p, 1, 1, col)

func _draw_front() -> void:
	# 石の囲い（手前半分）。
	for i in 6:
		_blit_bottom(TEX[&"stone"], _stone_at(PI * float(i) / 5.0))
	# 薪の山（段ごとに互い違い）。
	var p := _pile_origin()
	for i in 4:
		_blit_bottom(TEX[&"log"], p + Vector2((i % 2) * 2 * PX - PX, -i * 5 * PX), i % 2 == 1)
	draw_string(get_theme_default_font(), p + Vector2(-10, 24), "薪", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.72, 0.6))
	# 飛んでいる薪（放物線。ドット絵なので回転ではなく反転で転がす）。
	if _log_t >= 0.0:
		var t := _log_t
		var pos := p.lerp(fire_origin(), t) + Vector2(0, -120.0 * sin(t * PI))
		_blit_bottom(TEX[&"log"], pos, int(t * 6.0) % 2 == 1)
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

func _draw_gauge_overlay(gauge: Rect2, segs: int, seg_w: int) -> void:
	# 熾火帯：薪を入れる好機のセグメントを枠で囲む。
	var n := int(ceil(segs * FireSim.FEED_WINDOW_HIGH))
	var w := n * (seg_w + 1) * PX - PX
	var band := Rect2(gauge.position - Vector2(PX, PX), Vector2(w + PX * 2, gauge.size.y + PX * 2))
	draw_rect(band, Color(1.0, 0.7, 0.3, 0.9), false, 2.0)
	draw_string(get_theme_default_font(), gauge.position + Vector2(w + 12, -8), "← 熾火（薪の好機）", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.8, 0.5))
