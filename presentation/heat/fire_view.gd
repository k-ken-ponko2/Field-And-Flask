## 火ビューの共通部（presentation 層）。ドット絵スプライトで炎・燃料ゲージ・温度を描き、FireSim を進める材料を持つ。
##
## スプライトは tools/gen_fire_sprites.py で生成した assets/sprites/fire_*.png を Nearest で PX 倍に拡大する。
## 段階ごとの UI は派生クラスに分ける（操作と見た目が違うため）:
##   DirectFireView  … ① 直火   タイミングよく薪を入れる（クリック）
##   FanFireView     … ② 囲い炉 あおぐ（マウスのスライド）
##   BellowsFireView … ③ ふいご炉 ふいごを押し続ける（クリック長押し）
## 派生側は _draw_back / _draw_front（見た目）と _gui_input（ジェスチャ→数値）を実装する。
## 数値モデルは core（FireSim）側。ここは入力の変換と見た目だけ。
class_name FireView
extends Control

signal fed(timing: StringName)

## ドット絵の拡大率（整数倍でくっきり）。
const PX := 4.0

const TEX := {
	&"log": preload("res://assets/sprites/fire_log.png"),
	&"stone": preload("res://assets/sprites/fire_stone.png"),
	&"uchiwa": preload("res://assets/sprites/fire_uchiwa.png"),
	&"ember": preload("res://assets/sprites/fire_ember.png"),
	&"hearth": preload("res://assets/sprites/fire_hearth.png"),
	&"furnace": preload("res://assets/sprites/fire_furnace.png"),
	&"tuyere": preload("res://assets/sprites/fire_tuyere.png"),
	&"air": preload("res://assets/sprites/fire_air.png"),
	&"smoke_0": preload("res://assets/sprites/fire_smoke_0.png"),
	&"smoke_1": preload("res://assets/sprites/fire_smoke_1.png"),
	&"smoke_2": preload("res://assets/sprites/fire_smoke_2.png"),
	&"bellows_0": preload("res://assets/sprites/fire_bellows_0.png"),
	&"bellows_1": preload("res://assets/sprites/fire_bellows_1.png"),
	&"bellows_2": preload("res://assets/sprites/fire_bellows_2.png"),
}
const FLAMES := {
	&"s": [preload("res://assets/sprites/fire_flame_s_0.png"), preload("res://assets/sprites/fire_flame_s_1.png"),
		preload("res://assets/sprites/fire_flame_s_2.png"), preload("res://assets/sprites/fire_flame_s_3.png")],
	&"m": [preload("res://assets/sprites/fire_flame_m_0.png"), preload("res://assets/sprites/fire_flame_m_1.png"),
		preload("res://assets/sprites/fire_flame_m_2.png"), preload("res://assets/sprites/fire_flame_m_3.png")],
	&"l": [preload("res://assets/sprites/fire_flame_l_0.png"), preload("res://assets/sprites/fire_flame_l_1.png"),
		preload("res://assets/sprites/fire_flame_l_2.png"), preload("res://assets/sprites/fire_flame_l_3.png")],
}

var sim: FireSim
var _flicker := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

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

## 炎の根元（下端中央）の座標。
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

## スプライトを PX 倍で描く。pos は左上。flip_h で左右反転。
func _blit(tex: Texture2D, pos: Vector2, flip_h: bool = false, modulate: Color = Color.WHITE) -> void:
	var sz := tex.get_size() * PX
	var p := _snap(pos)
	if flip_h:
		draw_set_transform(p + Vector2(sz.x, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect(tex, Rect2(Vector2.ZERO, sz), false, modulate)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(tex, Rect2(p, sz), false, modulate)

## 下端中央を基準にスプライトを描く。
func _blit_bottom(tex: Texture2D, bottom_center: Vector2, flip_h: bool = false, modulate: Color = Color.WHITE) -> void:
	var sz := tex.get_size() * PX
	_blit(tex, bottom_center - Vector2(sz.x * 0.5, sz.y), flip_h, modulate)

## ドットの格子に合わせる。
func _snap(p: Vector2) -> Vector2:
	return (p / PX).floor() * PX

## PX 単位の四角（風の筋・ゲージなどの「描画ドット」）。
func _dot(p: Vector2, w: int, h: int, color: Color) -> void:
	draw_rect(Rect2(_snap(p), Vector2(w * PX, h * PX)), color)

func _draw_glow() -> void:
	var heat := sim.temperature01()
	draw_circle(fire_origin() + Vector2(0, 10), size.x * 0.3, Color(1.0, 0.55, 0.2, 0.22 * heat))

func _draw_flames() -> void:
	var base := fire_origin()
	if sim.is_out():
		_blit_bottom(TEX[&"ember"], base, false, Color(1, 1, 1, 0.6))
		return
	var frame := int(_flicker * 8.0) % 4
	var flip := int(_flicker * 4.0) % 2 == 1
	var tint := Color.WHITE.lerp(Color(1.0, 1.0, 0.9), sim.temperature01())
	if sim.drive < 0.3:
		_blit_bottom(TEX[&"ember"], base)
		_blit_bottom(FLAMES[&"s"][frame], base, flip, tint)
	elif sim.drive < 0.65:
		_blit_bottom(FLAMES[&"m"][frame], base, flip, tint)
	else:
		_blit_bottom(FLAMES[&"l"][frame], base, flip, tint)
		_blit_bottom(FLAMES[&"s"][(frame + 2) % 4], base + Vector2(-9 * PX, 0), not flip, tint)
		_blit_bottom(FLAMES[&"s"][(frame + 1) % 4], base + Vector2(9 * PX, 0), flip, tint)

## 燃料ゲージ（ドット刻みのセグメントバー）。
func _draw_fuel_gauge() -> void:
	var segs := 24
	var x0 := 16.0
	var y := size.y - 28.0
	var seg_w := 3
	for i in segs:
		var filled := float(i) / segs < sim.fuel
		var x := x0 + i * (seg_w + 1) * PX
		_dot(Vector2(x, y), seg_w, 3, Color(0.75, 0.45, 0.2) if filled else Color(0.2, 0.17, 0.15))
	_draw_gauge_overlay(Rect2(x0, y, segs * (seg_w + 1) * PX, 3 * PX), segs, seg_w)
	draw_string(get_theme_default_font(), Vector2(x0, y - 8), "燃料", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.72, 0.6))

## 燃料ゲージへの追加描画（直火の熾火帯など）。
func _draw_gauge_overlay(_gauge: Rect2, _segs: int, _seg_w: int) -> void:
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

## ドットで描く輪（進捗やタイミングの表示用）。fraction は塗る割合（0〜1）、上から時計回り。
func _draw_dot_ring(center: Vector2, radius: float, dots: int, fraction: float, on: Color, off: Color) -> void:
	for i in dots:
		var a := -PI * 0.5 + TAU * float(i) / dots
		var p := center + Vector2(cos(a), sin(a)) * radius
		var lit := float(i) / dots < fraction
		_dot(p - Vector2(PX, PX) * 0.5, 1, 1, on if lit else off)
