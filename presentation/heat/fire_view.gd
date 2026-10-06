## 火ビューの共通部（presentation 層）。炎・燃料ゲージ・温度バッジを描き、FireSim を進める材料を持つ。
##
## 段階ごとの UI は派生クラスに分ける（操作と見た目が違うため）:
##   DirectFireView  … ① 直火   タイミングよく薪を入れる（クリック）
##   FanFireView     … ② 囲い炉 あおぐ（マウスのスライド）
##   BellowsFireView … ③ ふいご炉 ふいごを押し続ける（クリック長押し）
## 派生側は _draw_back / _draw_front（見た目）と _gui_input（ジェスチャ→数値）を実装する。
## 数値モデルは core（FireSim）側。ここは入力の変換と見た目だけ。
class_name FireView
extends Control

signal fed(timing: StringName)

var sim: FireSim
var _flicker := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(fire_sim: FireSim) -> void:
	sim = fire_sim
	_on_setup()
	queue_redraw()

## 派生クラスが状態をリセットするためのフック。
func _on_setup() -> void:
	pass

func _process(delta: float) -> void:
	if sim == null:
		return
	_flicker += delta
	_on_process(delta)
	queue_redraw()

## 派生クラスが毎フレームの入力（長押しなど）やアニメを進めるためのフック。
func _on_process(_delta: float) -> void:
	pass

## 炎の根元の座標。
func fire_origin() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.78)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.11, 0.09, 0.08))
	if sim == null:
		return
	_draw_back()
	_draw_glow()
	_draw_flames()
	_draw_front()
	_draw_fuel_gauge()
	_draw_temperature()

## 装置の奥側（炎の後ろ）。派生クラスで実装。
func _draw_back() -> void:
	pass

## 装置の手前側（炎の前）。派生クラスで実装。
func _draw_front() -> void:
	pass

func _draw_glow() -> void:
	var heat := sim.temperature01()
	draw_circle(fire_origin() + Vector2(0, 10), size.x * 0.3, Color(1.0, 0.55, 0.2, 0.25 * heat))

func _draw_flames() -> void:
	var base := fire_origin()
	draw_line(base + Vector2(-60, 0), base + Vector2(44, -14), Color(0.33, 0.2, 0.1), 10.0)
	draw_line(base + Vector2(-44, -16), base + Vector2(60, 2), Color(0.4, 0.25, 0.12), 10.0)
	if sim.is_out():
		return
	var heat := sim.temperature01()
	var height := (40.0 + 180.0 * sim.drive) * (0.9 + 0.1 * sin(_flicker * 11.0))
	var tongues := 5
	for i in tongues:
		var t := float(i) / float(tongues - 1)
		var x := base.x + (t - 0.5) * 90.0
		var h := height * (1.0 - absf(t - 0.5) * 1.2) * (0.85 + 0.15 * sin(_flicker * 7.0 + i))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 22, base.y), Vector2(x, base.y - h), Vector2(x + 22, base.y)
		]), _flame_color(heat, 0.0))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 10, base.y), Vector2(x, base.y - h * 0.6), Vector2(x + 10, base.y)
		]), _flame_color(heat, 0.5))

func _draw_fuel_gauge() -> void:
	var gauge := Rect2(16, size.y - 28, size.x - 32, 12)
	draw_rect(gauge, Color(0.2, 0.17, 0.15))
	draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * sim.fuel, gauge.size.y)), Color(0.75, 0.45, 0.2))
	_draw_gauge_overlay(gauge)
	draw_string(get_theme_default_font(), Vector2(16, size.y - 36), "燃料", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.72, 0.6))

## 燃料ゲージへの追加描画（直火の熾火帯など）。
func _draw_gauge_overlay(_gauge: Rect2) -> void:
	pass

func _draw_temperature() -> void:
	var font := get_theme_default_font()
	var txt := "%d℃" % int(round(sim.temperature))
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(font, Vector2(size.x - tw - 16, 34), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.95, 0.85))

## 画面中央寄せの案内テキスト。
func _draw_caption(text: String, y: float, color: Color, font_size: int = 16) -> void:
	var font := get_theme_default_font()
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - tw) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

## 温度に応じた炎の色。inner が大きいほど芯側（白っぽい）。
func _flame_color(heat: float, inner: float) -> Color:
	return Color(0.85, 0.3, 0.1).lerp(Color(1.0, 0.95, 0.75), clampf(heat * 0.8 + inner * 0.4, 0.0, 1.0))
