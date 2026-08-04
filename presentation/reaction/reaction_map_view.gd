## 反応マップの描画（presentation 層・仮UI）。
##
## core の ReactionSim / PHModel / ReactionRegion を使って、pH 場・領域・経路・マーカーを描く。
## ロジックは一切持たず、状態を受け取って描画するだけ（設計書 §8 の層分離）。
class_name ReactionMapView
extends Control

## pH 場を焼き込む解像度（低解像度で作り、リニア補間で拡大＝連続グラデ）。
const FIELD_RES := 96
const AXIS_MAX := 10.0

var sim: ReactionSim
var trace: PackedVector2Array = PackedVector2Array()

var _tex: ImageTexture
var _tex_net := INF
var _stops: Array = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_stops = [
		[0.0, Color8(193, 41, 63)], [2.0, Color8(201, 80, 54)], [3.5, Color8(221, 138, 58)],
		[5.0, Color8(176, 163, 74)], [7.0, Color8(78, 154, 78)], [9.0, Color8(70, 150, 150)],
		[11.0, Color8(58, 131, 192)], [14.0, Color8(59, 63, 160)],
	]

## シミュレータを差し込む。
func setup(s: ReactionSim) -> void:
	sim = s
	_tex_net = INF
	queue_redraw()

func refresh() -> void:
	queue_redraw()

func _draw() -> void:
	if sim == null:
		return
	var sz := size
	_ensure_field()
	if _tex != null:
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, sz), false)
	_draw_regions(sz)
	_draw_path(sz)
	_draw_markers(sz)

## net_acid が変わったときだけ pH 場を焼き直す。
func _ensure_field() -> void:
	if _tex != null and is_equal_approx(_tex_net, sim.net_acid):
		return
	var img := Image.create(FIELD_RES, FIELD_RES, false, Image.FORMAT_RGB8)
	for y in FIELD_RES:
		var t01 := 1.0 - float(y) / float(FIELD_RES - 1)
		for x in FIELD_RES:
			var c01 := float(x) / float(FIELD_RES - 1)
			img.set_pixel(x, y, _litmus(PHModel.compute(sim.net_acid, c01, t01)))
	_tex = ImageTexture.create_from_image(img)
	_tex_net = sim.net_acid

func _map_to_screen(p: Vector2, sz: Vector2) -> Vector2:
	return Vector2(p.x / AXIS_MAX * sz.x, (1.0 - p.y / AXIS_MAX) * sz.y)

func _draw_regions(sz: Vector2) -> void:
	var font := ThemeDB.fallback_font
	for r in sim.map.regions:
		var c := _map_to_screen(r.center, sz)
		var rad := r.radius / AXIS_MAX * sz.x
		if r.kind == ReactionRegion.Kind.HAZARD:
			draw_circle(c, rad, Color(0.75, 0.22, 0.17, 0.18))
			draw_arc(c, rad, 0.0, TAU, 48, Color8(192, 57, 43), 1.5)
		else:
			draw_arc(c, rad, 0.0, TAU, 48, Color8(200, 130, 40), 2.0)
		var label_col := Color(0.1, 0.12, 0.1)
		draw_string(font, c + Vector2(-rad, -4), r.label, HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, 13, label_col)
		if r.requires_ph:
			var ph_txt := "pH %.0f–%.0f" % [r.ph_min, r.ph_max]
			draw_string(font, c + Vector2(-rad, 12), ph_txt, HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, 10, Color(0.1, 0.12, 0.1, 0.7))

func _draw_path(sz: Vector2) -> void:
	if trace.size() < 2:
		return
	var pts := PackedVector2Array()
	for p in trace:
		pts.append(_map_to_screen(p, sz))
	draw_polyline(pts, Color(0.08, 0.1, 0.08, 0.5), 1.5)

func _draw_markers(sz: Vector2) -> void:
	if trace.size() > 0:
		draw_circle(_map_to_screen(trace[0], sz), 3.0, Color(0.08, 0.1, 0.08, 0.4))
	var m := _map_to_screen(sim.position, sz)
	draw_circle(m, 7.0, Color8(200, 130, 40))
	draw_arc(m, 7.0, 0.0, TAU, 24, Color.WHITE, 2.0)

func _litmus(p: float) -> Color:
	for i in _stops.size() - 1:
		var a: Array = _stops[i]
		var b: Array = _stops[i + 1]
		if p <= b[0]:
			var f: float = clampf((p - a[0]) / (b[0] - a[0]), 0.0, 1.0)
			return (a[1] as Color).lerp(b[1] as Color, f)
	return _stops[_stops.size() - 1][1]
