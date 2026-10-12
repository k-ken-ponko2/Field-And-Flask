## 羊皮紙の反応マップ（ポーションクラフト寄せ）。描画のみ、ロジックは ReactionSim。
##
## 描くもの: 羊皮紙、インクの軸と目盛り、目標（八芒星＋点線の円）、暴走（ドクロ＋赤いハッチ）、
## 熱源の天井（点線）、たどった軌跡、投入済み素材の予告経路（点線）、ドラッグ中のかざし予告、マーカー（泡）。
## マーカーは sim.position へ滑らかに追従する。
class_name AlchemyMapView
extends Control

var sim: ReactionSim
var trail: PackedVector2Array = PackedVector2Array()
## ドラッグ中に釜の上へかざしている素材の予告（null なら無し）。
var hover_material: MaterialDef = null
## 熱源の天井（℃）。0 以下なら描かない。
var heat_ceiling_celsius: float = 0.0

var _shown := Vector2.ZERO
var _pulse := 0.0
const MARGIN := 44.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(s: ReactionSim) -> void:
	sim = s
	_shown = s.position
	trail = PackedVector2Array([s.position])
	queue_redraw()

func _process(delta: float) -> void:
	if sim == null:
		return
	_pulse += delta
	_shown = _shown.lerp(sim.position, minf(1.0, delta * 10.0))
	if trail.is_empty() or trail[trail.size() - 1].distance_to(sim.position) > 0.05:
		trail.append(sim.position)
	queue_redraw()

func _plot() -> Rect2:
	return Rect2(Vector2(MARGIN, 24), size - Vector2(MARGIN + 20, 24 + MARGIN))

func to_screen(p: Vector2) -> Vector2:
	var b := sim.map.bounds
	var r := _plot()
	var nx := (p.x - b.position.x) / b.size.x
	var ny := (p.y - b.position.y) / b.size.y
	return Vector2(r.position.x + nx * r.size.x, r.end.y - ny * r.size.y)

func _draw() -> void:
	LabAssets.tile_parchment(self, Rect2(Vector2.ZERO, size))
	# 縁の飾り（インクの二重線）
	draw_rect(Rect2(Vector2(8, 8), size - Vector2(16, 16)), LabAssets.INK_SOFT, false, 2.0)
	draw_rect(Rect2(Vector2(14, 14), size - Vector2(28, 28)), LabAssets.INK_SOFT, false, 1.0)
	if sim == null:
		return
	var font := get_theme_default_font()
	var r := _plot()
	# 軸
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), LabAssets.INK, 2.0)
	draw_line(Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), LabAssets.INK, 2.0)
	draw_string(font, Vector2(r.end.x - 60, r.end.y + 20), sim.map.axis_x + " →", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, LabAssets.INK)
	draw_string(font, Vector2(r.position.x + 10, r.position.y + 16), "↑ " + sim.map.axis_y, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, LabAssets.INK)
	# 温度の目盛り（℃）
	for t in [200, 400, 600, 800, 1000]:
		var y := to_screen(Vector2(0, sim.map.temperature_to_y(t))).y
		if y < r.position.y or y > r.end.y:
			continue
		draw_line(Vector2(r.position.x - 6, y), Vector2(r.position.x, y), LabAssets.INK, 1.5)
		draw_string(font, Vector2(2, y + 4), "%d" % t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LabAssets.INK_SOFT)
	# 熱源の天井
	if heat_ceiling_celsius > 0.0:
		var cy := to_screen(Vector2(0, sim.map.temperature_to_y(heat_ceiling_celsius))).y
		LabAssets.dotted_line(self, Vector2(r.position.x, cy), Vector2(r.end.x, cy), Color(0.6, 0.25, 0.15, 0.8), 12.0, 2.0)
		draw_string(font, Vector2(r.end.x - 150, cy - 6), "この炉の天井 %d℃" % int(heat_ceiling_celsius), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.25, 0.15))
	# 領域
	for reg in sim.map.regions:
		var c := to_screen(reg.center)
		var rad := reg.radius / sim.map.bounds.size.x * r.size.x
		if reg.kind == ReactionRegion.Kind.HAZARD:
			draw_circle(c, rad, Color(0.65, 0.2, 0.15, 0.12))
			LabAssets.dotted_circle(self, c, rad, Color(0.6, 0.2, 0.15, 0.9), 40, 3.0)
			LabAssets.blit_center(self, LabAssets.TEX[&"hazard"], c)
		else:
			LabAssets.dotted_circle(self, c, rad, LabAssets.INK_SOFT, 36, 3.0)
			LabAssets.blit_center(self, LabAssets.TEX[&"target"], c)
		draw_string(font, c + Vector2(-rad, rad + 16), reg.label, HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, 13, LabAssets.INK)
		if reg.requires_ph:
			draw_string(font, c + Vector2(-rad, rad + 30), "pH %.0f–%.0f" % [reg.ph_min, reg.ph_max], HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, 10, LabAssets.INK_SOFT)
	# 軌跡（インクの細線）
	if trail.size() >= 2:
		var pts := PackedVector2Array()
		for p in trail:
			pts.append(to_screen(p))
		draw_polyline(pts, Color(0.17, 0.11, 0.08, 0.45), 2.0)
	# 予告経路（投入済み）
	var pending := sim.pending_points()
	for i in pending.size() - 1:
		LabAssets.dotted_line(self, to_screen(pending[i]), to_screen(pending[i + 1]), LabAssets.INK, 10.0, 3.0)
	if pending.size() >= 2:
		var endp := to_screen(pending[pending.size() - 1])
		LabAssets.dotted_circle(self, endp, 10.0, LabAssets.INK, 10, 2.0)
	# かざし予告（ドラッグ中）
	if hover_material != null:
		var tail: Vector2 = pending[pending.size() - 1]
		var to := tail + hover_material.jump_vector * hover_material.jump_magnitude
		var blink := 0.5 + 0.5 * sin(_pulse * 8.0)
		LabAssets.dotted_line(self, to_screen(tail), to_screen(to), Color(0.55, 0.3, 0.1, 0.4 + 0.5 * blink), 10.0, 3.0)
		draw_string(font, to_screen(to) + Vector2(10, -6), hover_material.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.3, 0.1))
	# マーカー
	var m := to_screen(_shown)
	draw_circle(m + Vector2(2, 3), 14.0, Color(0, 0, 0, 0.12))
	LabAssets.blit_center(self, LabAssets.TEX[&"marker"], m)
	if sim.batch_lost:
		draw_string(font, m + Vector2(14, -10), "暴走！", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.15, 0.1))
	# 読み出し（右上、インク文字）
	var ph := sim.ph()
	var lines := [
		"温度 %d℃" % int(round(sim.map.y_to_temperature(sim.position.y))),
		"pH %.1f" % ph,
	]
	var tgt := sim.reached_target()
	if tgt != null:
		lines.append("→ %s 収率 %d%%" % [tgt.label, int(round(sim.yield_ratio() * 100.0))])
	for i in lines.size():
		draw_string(font, Vector2(r.end.x - 200, r.end.y - 14 - (lines.size() - 1 - i) * 18), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, LabAssets.INK)
