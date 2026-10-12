## 錬金ラボ（ポーションクラフト寄せ）の共有アセットと小道具。
## スプライトは tools/gen_lab_sprites.py の出力。Nearest で PX 倍に拡大して使う。
class_name LabAssets
extends RefCounted

const PX := 4.0

const TEX := {
	&"parchment": preload("res://assets/sprites/lab_parchment.png"),
	&"cauldron": preload("res://assets/sprites/lab_cauldron.png"),
	&"bellows_0": preload("res://assets/sprites/lab_bellows_0.png"),
	&"bellows_1": preload("res://assets/sprites/lab_bellows_1.png"),
	&"spoon": preload("res://assets/sprites/lab_spoon.png"),
	&"ladle": preload("res://assets/sprites/lab_ladle.png"),
	&"alembic": preload("res://assets/sprites/lab_alembic.png"),
	&"bottle": preload("res://assets/sprites/lab_bottle.png"),
	&"marker": preload("res://assets/sprites/lab_marker.png"),
	&"target": preload("res://assets/sprites/lab_target.png"),
	&"hazard": preload("res://assets/sprites/lab_hazard.png"),
	&"shelf": preload("res://assets/sprites/lab_shelf.png"),
	&"flame_0": preload("res://assets/sprites/lab_flame_0.png"),
	&"flame_1": preload("res://assets/sprites/lab_flame_1.png"),
	&"ing_vitriol": preload("res://assets/sprites/lab_ing_vitriol.png"),
	&"ing_lime": preload("res://assets/sprites/lab_ing_lime.png"),
	&"ing_water": preload("res://assets/sprites/lab_ing_water.png"),
	&"ing_sulfur": preload("res://assets/sprites/lab_ing_sulfur.png"),
	&"log": preload("res://assets/sprites/fire_log.png"),
	&"uchiwa": preload("res://assets/sprites/fire_uchiwa.png"),
	&"hearth": preload("res://assets/sprites/fire_hearth.png"),
}

## インク色（輪郭・文字）。
const INK := Color(0.17, 0.11, 0.08)
const INK_SOFT := Color(0.17, 0.11, 0.08, 0.55)
const PAPER := Color(0.91, 0.84, 0.68)
const WOOD := Color(0.23, 0.15, 0.09)
const WOOD_LINE := Color(0.18, 0.11, 0.07)

static func snap(p: Vector2) -> Vector2:
	return (p / PX).floor() * PX

## 左上基準でスプライトを描く。
static func blit(ci: CanvasItem, tex: Texture2D, pos: Vector2, flip_h: bool = false, modulate: Color = Color.WHITE) -> void:
	var sz := tex.get_size() * PX
	var p := snap(pos)
	if flip_h:
		ci.draw_set_transform(p + Vector2(sz.x, 0), 0.0, Vector2(-1, 1))
		ci.draw_texture_rect(tex, Rect2(Vector2.ZERO, sz), false, modulate)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		ci.draw_texture_rect(tex, Rect2(p, sz), false, modulate)

## 中心基準でスプライトを描く。
static func blit_center(ci: CanvasItem, tex: Texture2D, center: Vector2, flip_h: bool = false, modulate: Color = Color.WHITE) -> void:
	blit(ci, tex, center - tex.get_size() * PX * 0.5, flip_h, modulate)

## 下端中央基準。
static func blit_bottom(ci: CanvasItem, tex: Texture2D, bottom_center: Vector2, flip_h: bool = false, modulate: Color = Color.WHITE) -> void:
	var sz := tex.get_size() * PX
	blit(ci, tex, bottom_center - Vector2(sz.x * 0.5, sz.y), flip_h, modulate)

## 羊皮紙を敷き詰める。
static func tile_parchment(ci: CanvasItem, rect: Rect2) -> void:
	var tex: Texture2D = TEX[&"parchment"]
	var sz := tex.get_size() * PX
	var y := rect.position.y
	while y < rect.end.y:
		var x := rect.position.x
		while x < rect.end.x:
			var w := minf(sz.x, rect.end.x - x)
			var h := minf(sz.y, rect.end.y - y)
			ci.draw_texture_rect_region(tex, Rect2(Vector2(x, y), Vector2(w, h)), Rect2(Vector2.ZERO, Vector2(w, h) / PX))
			x += sz.x
		y += sz.y

## インクの点線（ドット刻み）。
static func dotted_line(ci: CanvasItem, from: Vector2, to: Vector2, color: Color, spacing: float = 10.0, dot: float = 3.0) -> void:
	var d := from.distance_to(to)
	if d <= 0.0:
		return
	var dir := (to - from) / d
	var t := 0.0
	while t < d:
		var p := from + dir * t
		ci.draw_rect(Rect2(p - Vector2(dot, dot) * 0.5, Vector2(dot, dot)), color)
		t += spacing

## インクの点線の円。
static func dotted_circle(ci: CanvasItem, center: Vector2, radius: float, color: Color, dots: int = 36, dot: float = 3.0) -> void:
	for i in dots:
		var a := TAU * float(i) / dots
		var p := center + Vector2(cos(a), sin(a)) * radius
		ci.draw_rect(Rect2(p - Vector2(dot, dot) * 0.5, Vector2(dot, dot)), color)

## pH → リトマス色（液体の色）。
static func litmus(p: float) -> Color:
	var stops := [
		[0.0, Color8(193, 41, 63)], [2.0, Color8(201, 80, 54)], [3.5, Color8(221, 138, 58)],
		[5.0, Color8(176, 163, 74)], [7.0, Color8(78, 154, 78)], [9.0, Color8(70, 150, 150)],
		[11.0, Color8(58, 131, 192)], [14.0, Color8(59, 63, 160)],
	]
	for i in stops.size() - 1:
		var a: Array = stops[i]
		var b: Array = stops[i + 1]
		if p <= b[0]:
			var f: float = clampf((p - a[0]) / (b[0] - a[0]), 0.0, 1.0)
			return (a[1] as Color).lerp(b[1] as Color, f)
	return stops[stops.size() - 1][1]
