## 反応マップの描画（presentation 層・仮UI）。
##
## core の ReactionSim / PHModel / ReactionRegion を使って、pH 場・軸・目盛・領域・経路・
## マーカー・pH 凡例を描く。ロジックは一切持たず、状態を受け取って描画するだけ
## （設計書 §8 の層分離）。色はテーマの `ReactionMapView` 型から取る。
class_name ReactionMapView
extends Control

## pH 場を焼き込む解像度（低解像度で作り、リニア補間で拡大＝連続グラデ）。
const FIELD_RES := 96
const AXIS_MAX := 10.0
const GRID_STEP := 1.0
const TICK_STEP := 2.0

## プロット領域の外側に取る余白（軸タイトル・目盛・凡例ぶん）。
const PAD_LEFT := 44.0
const PAD_RIGHT := 14.0
const PAD_TOP := 12.0
const PAD_BOTTOM := 70.0
const LEGEND_HEIGHT := 10.0

var sim: ReactionSim
var trace: PackedVector2Array = PackedVector2Array()

var _tex: ImageTexture
var _tex_net := INF
var _legend_tex: ImageTexture
var _stops: Array = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_stops = [
		[0.0, Color8(193, 41, 63)], [2.0, Color8(201, 80, 54)], [3.5, Color8(221, 138, 58)],
		[5.0, Color8(176, 163, 74)], [7.0, Color8(78, 154, 78)], [9.0, Color8(70, 150, 150)],
		[11.0, Color8(58, 131, 192)], [14.0, Color8(59, 63, 160)],
	]
	_legend_tex = _make_legend_texture()

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
	var plot := _plot_rect()
	_ensure_field()
	if _tex != null:
		draw_texture_rect(_tex, plot, false)
	_draw_grid(plot)
	_draw_regions(plot)
	_draw_path(plot)
	_draw_markers(plot)
	_draw_axes(plot)
	_draw_legend(plot)

# --- レイアウト -----------------------------------------------------------------

func _plot_rect() -> Rect2:
	var inner := Vector2(
		maxf(size.x - PAD_LEFT - PAD_RIGHT, 10.0),
		maxf(size.y - PAD_TOP - PAD_BOTTOM, 10.0)
	)
	# 正方形に揃えて中央寄せ（軸の 1 単位が縦横で同じ長さになる）。
	var side := minf(inner.x, inner.y)
	var origin := Vector2(PAD_LEFT + (inner.x - side) * 0.5, PAD_TOP + (inner.y - side) * 0.5)
	return Rect2(origin, Vector2(side, side))

func _map_to_screen(p: Vector2, plot: Rect2) -> Vector2:
	return plot.position + Vector2(p.x / AXIS_MAX * plot.size.x, (1.0 - p.y / AXIS_MAX) * plot.size.y)

func _c(name: StringName) -> Color:
	return get_theme_color(name, &"ReactionMapView")

# --- pH 場 -------------------------------------------------------------------

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

func _make_legend_texture() -> ImageTexture:
	var w := 128
	var img := Image.create(w, 1, false, Image.FORMAT_RGB8)
	for x in w:
		img.set_pixel(x, 0, _litmus(14.0 * float(x) / float(w - 1)))
	return ImageTexture.create_from_image(img)

# --- グリッド・軸 --------------------------------------------------------------

func _draw_grid(plot: Rect2) -> void:
	var col := _c(&"grid")
	var n := int(AXIS_MAX / GRID_STEP)
	for i in range(1, n):
		var f := float(i) / float(n)
		var x := plot.position.x + plot.size.x * f
		var y := plot.position.y + plot.size.y * f
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), col, 1.0)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), col, 1.0)
	draw_rect(plot, Color(1, 1, 1, 0.35), false, 1.0)

func _draw_axes(plot: Rect2) -> void:
	var font := get_theme_default_font()
	var axis_col := _c(&"axis")
	var ticks := int(AXIS_MAX / TICK_STEP)
	for i in range(0, ticks + 1):
		var v := TICK_STEP * float(i)
		var f := v / AXIS_MAX
		# 横軸の目盛（下）。
		var x := plot.position.x + plot.size.x * f
		draw_line(Vector2(x, plot.end.y), Vector2(x, plot.end.y + 4.0), axis_col, 1.0)
		draw_string(font, Vector2(x - 12.0, plot.end.y + 17.0), "%d" % int(v), HORIZONTAL_ALIGNMENT_CENTER, 24.0, 11, axis_col)
		# 縦軸の目盛（左）。
		var y := plot.end.y - plot.size.y * f
		draw_line(Vector2(plot.position.x - 4.0, y), Vector2(plot.position.x, y), axis_col, 1.0)
		draw_string(font, Vector2(plot.position.x - 26.0, y + 4.0), "%d" % int(v), HORIZONTAL_ALIGNMENT_RIGHT, 20.0, 11, axis_col)

	var x_title := "%s →" % (sim.map.axis_x if sim.map != null else "x")
	draw_string(font, Vector2(plot.position.x, plot.end.y + 33.0), x_title, HORIZONTAL_ALIGNMENT_CENTER, plot.size.x, 12, axis_col)

	var y_title := "%s →" % (sim.map.axis_y if sim.map != null else "y")
	draw_set_transform(Vector2(plot.position.x - 30.0, plot.end.y), -PI * 0.5, Vector2.ONE)
	draw_string(font, Vector2(0.0, 0.0), y_title, HORIZONTAL_ALIGNMENT_CENTER, plot.size.y, 12, axis_col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- 凡例 ----------------------------------------------------------------------

func _draw_legend(plot: Rect2) -> void:
	var font := get_theme_default_font()
	var axis_col := _c(&"axis")
	var y := plot.end.y + 46.0
	var left := plot.position.x + 34.0
	var right := plot.end.x - 22.0
	var bar := Rect2(Vector2(left, y), Vector2(right - left, LEGEND_HEIGHT))
	if _legend_tex != null:
		draw_texture_rect(_legend_tex, bar, false)
	draw_rect(bar, Color(1, 1, 1, 0.5), false, 1.0)
	draw_string(font, Vector2(plot.position.x, y + 9.0), "pH 0", HORIZONTAL_ALIGNMENT_LEFT, 32.0, 10, axis_col)
	draw_string(font, Vector2(right + 4.0, y + 9.0), "14", HORIZONTAL_ALIGNMENT_LEFT, 20.0, 10, axis_col)
	# 現在の pH を凡例上に小さな三角で示す。
	var p := clampf(sim.ph(), 0.0, 14.0)
	var px := left + (right - left) * p / 14.0
	var tri := PackedVector2Array([
		Vector2(px, y - 2.0), Vector2(px - 4.0, y - 8.0), Vector2(px + 4.0, y - 8.0),
	])
	draw_colored_polygon(tri, _c(&"label"))

# --- 領域・経路・マーカー -----------------------------------------------------

func _draw_regions(plot: Rect2) -> void:
	var font := get_theme_default_font()
	var reached := sim.reached_target()
	var target_col := _c(&"target")
	var hazard_col := _c(&"hazard")
	var label_col := _c(&"label")
	for r in sim.map.regions:
		var c := _map_to_screen(r.center, plot)
		var rad := r.radius / AXIS_MAX * plot.size.x
		if r.kind == ReactionRegion.Kind.HAZARD:
			draw_circle(c, rad, Color(hazard_col, 0.20))
			draw_arc(c, rad, 0.0, TAU, 56, hazard_col, 1.5)
			draw_arc(c, rad + 6.0, 0.0, TAU, 56, Color(hazard_col, 0.35), 1.0)
		elif r == reached:
			draw_circle(c, rad, Color(target_col, 0.30))
			draw_arc(c, rad, 0.0, TAU, 56, target_col, 3.0)
			draw_arc(c, rad + 5.0, 0.0, TAU, 56, Color(target_col, 0.5), 1.0)
		else:
			draw_circle(c, rad, Color(target_col, 0.10))
			draw_arc(c, rad, 0.0, TAU, 56, target_col, 2.0)
		draw_string(font, c + Vector2(-rad, -4), r.label, HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, 13, label_col)
		if r.requires_ph:
			var ph_txt := "pH %.0f–%.0f" % [r.ph_min, r.ph_max]
			draw_string(font, c + Vector2(-rad, 12), ph_txt, HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, 10, Color(label_col, 0.7))
		if r == reached:
			draw_string(font, c + Vector2(-rad, 28), "✓ 到達", HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, 11, label_col)

func _draw_path(plot: Rect2) -> void:
	if trace.size() < 2:
		return
	var col := _c(&"trace")
	var pts := PackedVector2Array()
	for p in trace:
		pts.append(_map_to_screen(p, plot))
	draw_polyline(pts, Color(col, 0.55), 2.0, true)
	for i in range(1, pts.size() - 1):
		draw_circle(pts[i], 2.5, Color(col, 0.45))

func _draw_markers(plot: Rect2) -> void:
	var col := _c(&"marker")
	if sim.batch_lost:
		col = _c(&"hazard")
	if trace.size() > 0:
		var s := _map_to_screen(trace[0], plot)
		draw_arc(s, 4.0, 0.0, TAU, 20, Color(_c(&"trace"), 0.5), 1.5)
	var m := _map_to_screen(sim.position, plot)
	draw_circle(m, 14.0, Color(col, 0.22))
	draw_circle(m, 7.0, col)
	draw_arc(m, 7.0, 0.0, TAU, 24, Color.WHITE, 2.0)

func _litmus(p: float) -> Color:
	for i in _stops.size() - 1:
		var a: Array = _stops[i]
		var b: Array = _stops[i + 1]
		if p <= b[0]:
			var f: float = clampf((p - a[0]) / (b[0] - a[0]), 0.0, 1.0)
			return (a[1] as Color).lerp(b[1] as Color, f)
	return _stops[_stops.size() - 1][1]
