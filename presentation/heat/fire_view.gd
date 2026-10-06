## 火の描画と、ジェスチャ → FireSim への変換（presentation 層）。
##
## 熱源の input_mode に応じて、同じ領域で受け付ける操作が変わる:
##   FEED_TIMING  … クリック            → sim.feed()
##   FAN_SLIDE    … マウスのスライド    → sim.fan(距離)
##   BELLOWS_HOLD … クリック長押し      → sim.pump(押下時間) を _process で流す
## 数値モデルは core（FireSim）側。ここは入力の変換と見た目だけ。
class_name FireView
extends Control

## 1 単位の「あおぐ距離」に相当するピクセル数。
const FAN_PIXELS_PER_UNIT := 100.0

signal fed(timing: StringName)

var sim: FireSim
var _holding := false
var _flicker := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(fire_sim: FireSim) -> void:
	sim = fire_sim
	_holding = false
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if sim == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if sim.accepts(HeatSource.InputMode.FEED_TIMING) and event.pressed:
			var r := sim.feed()
			if r["ok"]:
				fed.emit(r["timing"])
		elif sim.accepts(HeatSource.InputMode.BELLOWS_HOLD):
			_holding = event.pressed
	elif event is InputEventMouseMotion and sim.accepts(HeatSource.InputMode.FAN_SLIDE):
		sim.fan(event.relative.length() / FAN_PIXELS_PER_UNIT)

func _process(delta: float) -> void:
	if sim == null:
		return
	if _holding:
		sim.pump(delta)
	_flicker += delta
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.11, 0.09, 0.08))
	if sim == null:
		return
	var heat := sim.temperature01()
	# 地面の照り返し。
	var glow := Color(1.0, 0.55, 0.2, 0.25 * heat)
	draw_circle(Vector2(size.x * 0.5, size.y * 0.82), size.x * 0.32, glow)
	# 薪。
	var base := Vector2(size.x * 0.5, size.y * 0.8)
	draw_line(base + Vector2(-70, 0), base + Vector2(50, -16), Color(0.33, 0.2, 0.1), 10.0)
	draw_line(base + Vector2(-50, -18), base + Vector2(70, 2), Color(0.4, 0.25, 0.12), 10.0)
	# 炎。火勢で高さ、温度で色。
	if not sim.is_out():
		var height := (40.0 + 180.0 * sim.drive) * (0.9 + 0.1 * sin(_flicker * 11.0))
		var tongues := 5
		for i in tongues:
			var t := float(i) / float(tongues - 1)
			var x := base.x + (t - 0.5) * 90.0
			var h := height * (1.0 - absf(t - 0.5) * 1.2) * (0.85 + 0.15 * sin(_flicker * 7.0 + i))
			var pts := PackedVector2Array([
				Vector2(x - 22, base.y), Vector2(x, base.y - h), Vector2(x + 22, base.y)
			])
			draw_colored_polygon(pts, _flame_color(heat, 0.0))
			var inner := PackedVector2Array([
				Vector2(x - 10, base.y), Vector2(x, base.y - h * 0.6), Vector2(x + 10, base.y)
			])
			draw_colored_polygon(inner, _flame_color(heat, 0.5))
	# 燃料ゲージ（直火は熾火の帯＝薪を入れるべきタイミングを示す）。
	var gauge := Rect2(16, size.y - 28, size.x - 32, 12)
	draw_rect(gauge, Color(0.2, 0.17, 0.15))
	draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * sim.fuel, gauge.size.y)), Color(0.75, 0.45, 0.2))
	if sim.accepts(HeatSource.InputMode.FEED_TIMING):
		# 熾火の帯＝薪を入れる好機。燃料バーの上に重ねて、境界に目印を立てる。
		var w := gauge.size.x * FireSim.FEED_WINDOW_HIGH
		var band := Rect2(gauge.position - Vector2(0, 4), Vector2(w, gauge.size.y + 8))
		draw_rect(band, Color(1.0, 0.7, 0.3, 0.25))
		draw_rect(band, Color(1.0, 0.7, 0.3, 0.9), false, 1.5)
	# 温度バッジ。
	var font := get_theme_default_font()
	var fsz := 22
	var txt := "%d℃" % int(round(sim.temperature))
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	draw_string(font, Vector2(size.x - tw - 16, 34), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(1, 0.95, 0.85))
	draw_string(font, Vector2(16, size.y - 36), "燃料", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.72, 0.6))

## 温度に応じた炎の色。inner が大きいほど芯側（白っぽい）。
func _flame_color(heat: float, inner: float) -> Color:
	var cold := Color(0.85, 0.3, 0.1)
	var hot := Color(1.0, 0.95, 0.75)
	return cold.lerp(hot, clampf(heat * 0.8 + inner * 0.4, 0.0, 1.0))
