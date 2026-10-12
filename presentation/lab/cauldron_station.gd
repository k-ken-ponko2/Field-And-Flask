## 大釜ステーション（ポーションクラフト寄せ）。炎の上の大釜と、掛けてある道具。
##
## 直接操作:
##   道具（かき混ぜ棒／ひしゃく／蒸留器／瓶）… 掴んで釜へ運ぶ。
##     かき混ぜ棒: 釜の中で円を描く → stirred(距離)   ひしゃく: 釜の上で保持 → watering(dt)
##     蒸留器:     釜の上で保持 → distilling(dt)       瓶:      釜の上で放す → bottle_requested
##   火（下の帯）… 据えた熱源の操作。直火=クリックで薪 / 囲い炉=スライド / ふいご炉=ふいごを長押し
##   ドロップ … 棚からの素材・熱源を受け取る（item_dropped / hover 予告は hover_material）
## 数値モデルは core（FireSim / LabBench / ReactionSim）。ここは入力の変換と見た目だけ。
class_name CauldronStation
extends Control

signal stirred(distance: float)
signal watering(dt: float)
signal distilling(dt: float)
signal bottle_requested()
signal item_dropped(data: Dictionary)
signal hover_changed(material: MaterialDef)
signal fed(timing: StringName)

## 1 周かき混ぜるとマップ座標でこれだけ進む。
const STIR_PER_TURN := 1.5
## ひしゃく／蒸留器を保持したときの速さ（マップ座標/秒）。
const WATER_RATE := 0.5
const DISTILL_RATE := 0.6
## 釜の「上」と見なす半径。
const OVER_RADIUS := 110.0
const FAN_PIXELS_PER_UNIT := 100.0

var bench: LabBench
var sim: ReactionSim
## 中身の色（暴走で黒ずむ）。pH は縁の色で示す。
var liquid_color := Color(0.5, 0.69, 0.54)
## 現在の pH（釜の縁をリトマス色で塗る）。負なら表示しない。
var ph := 7.0
## 瓶詰めできる状態か（掛けてある瓶が金色に明滅し「瓶詰めできる」の札が出る）。
var bottle_ready := false

var _held: StringName = &""          ## 掴んでいる道具
var _held_pos := Vector2.ZERO
var _last_angle := 0.0
var _stir_ripple := 0.0
var _pumping := false
var _squeeze := 0.0
var _flicker := 0.0
var _hover_mat: MaterialDef = null
var _fan_x := -1.0

const TOOL_HOOKS := {
	&"spoon": Vector2(52, 60),
	&"ladle": Vector2(436, 60),
	&"alembic": Vector2(428, 190),
	&"bottle": Vector2(60, 200),
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func cauldron_center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.56)

func fire_zone() -> Rect2:
	return Rect2(0, size.y * 0.72, size.x, size.y * 0.28)

func _tool_tex(id: StringName) -> Texture2D:
	return LabAssets.TEX[id]

func _tool_rect(id: StringName) -> Rect2:
	var tex := _tool_tex(id)
	var sz := tex.get_size() * LabAssets.PX
	return Rect2(TOOL_HOOKS[id] - sz * 0.5, sz)

func _over_cauldron(p: Vector2) -> bool:
	return p.distance_to(cauldron_center()) <= OVER_RADIUS

# --- 入力 ----------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)
	elif event is InputEventMouseMotion:
		_motion(event.position, event.relative)

func _press(p: Vector2) -> void:
	for id in TOOL_HOOKS:
		if _tool_rect(id).has_point(p):
			_held = id
			_held_pos = p
			_last_angle = (p - cauldron_center()).angle()
			return
	if bench == null or bench.fire == null:
		return
	if _bellows_rect().has_point(p) and bench.fire.accepts(HeatSource.InputMode.BELLOWS_HOLD):
		_pumping = true
	elif fire_zone().has_point(p) and bench.fire.accepts(HeatSource.InputMode.FEED_TIMING):
		var r := bench.fire.feed()
		if r["ok"]:
			fed.emit(r["timing"])

func _motion(p: Vector2, rel: Vector2) -> void:
	if _held != &"":
		_held_pos = p
		if _held == &"spoon" and _over_cauldron(p):
			var a := (p - cauldron_center()).angle()
			var da := absf(wrapf(a - _last_angle, -PI, PI))
			_last_angle = a
			if da > 0.0:
				_stir_ripple = 1.0
				stirred.emit(da / TAU * STIR_PER_TURN)
		return
	if bench != null and bench.fire != null and fire_zone().has_point(p) and bench.fire.accepts(HeatSource.InputMode.FAN_SLIDE):
		_fan_x = p.x
		bench.fire.fan(rel.length() / FAN_PIXELS_PER_UNIT)

func _release(p: Vector2) -> void:
	_pumping = false
	if _held == &"bottle" and _over_cauldron(p):
		bottle_requested.emit()
	_held = &""

func _process(delta: float) -> void:
	_flicker += delta
	_stir_ripple = maxf(0.0, _stir_ripple - delta * 2.0)
	# 描画が重い環境でフレームが長くなっても、1 フレームで注ぐ量は上限を持つ。
	var dt := minf(delta, 0.1)
	if _held == &"ladle" and _over_cauldron(_held_pos):
		watering.emit(dt)
	elif _held == &"alembic" and _over_cauldron(_held_pos):
		distilling.emit(dt)
	if _pumping and bench != null and bench.fire != null:
		bench.fire.pump(delta)
	_squeeze = lerpf(_squeeze, 1.0 if _pumping else 0.0, minf(1.0, delta * (5.0 if _pumping else 3.0)))
	queue_redraw()

## ドラッグが（どこで）終わっても、かざし予告は消す。
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _hover_mat != null:
		_hover_mat = null
		hover_changed.emit(null)

# --- ドロップ（棚から） ------------------------------------------------------------

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("kind")):
		return false
	if data["kind"] == &"material":
		var m: MaterialDef = load(data["path"])
		var over := _over_cauldron(at)
		var next: MaterialDef = m if over else null
		if next != _hover_mat:
			_hover_mat = next
			hover_changed.emit(next)
		return over
	return true

func _drop_data(_at: Vector2, data: Variant) -> void:
	_hover_mat = null
	hover_changed.emit(null)
	item_dropped.emit(data)

# --- 描画 ----------------------------------------------------------------------

func _bellows_rect() -> Rect2:
	var sz: Vector2 = LabAssets.TEX[&"bellows_0"].get_size() * LabAssets.PX
	return Rect2(Vector2(16, size.y - sz.y - 8), sz)

func _draw() -> void:
	# 木の壁と棚板
	draw_rect(Rect2(Vector2.ZERO, size), LabAssets.WOOD)
	for y in range(0, int(size.y), 48):
		draw_line(Vector2(0, y), Vector2(size.x, y), LabAssets.WOOD_LINE, 2.0)
	var fz := fire_zone()
	draw_rect(fz, Color(0.12, 0.09, 0.07))
	draw_line(fz.position, Vector2(fz.end.x, fz.position.y), LabAssets.INK, 3.0)
	if bench == null:
		return
	var c := cauldron_center()
	# 火と熱源の道具
	_draw_fire(c)
	# 大釜（液面の色は pH）
	var tex: Texture2D = LabAssets.TEX[&"cauldron"]
	LabAssets.blit_center(self, tex, c)
	# 縁（リトマス色＝pH）。スプライトの縁の行を塗り直す。上の 1 行はハイライト
	var px := LabAssets.PX
	var rim := LabAssets.litmus(ph)
	draw_rect(Rect2(c + Vector2(-21 * px, -13 * px), Vector2(42 * px, 4 * px)), rim)
	draw_rect(Rect2(c + Vector2(-21 * px, -13 * px), Vector2(42 * px, px)), rim.lightened(0.35))
	draw_rect(Rect2(c + Vector2(-21 * px, -10 * px), Vector2(42 * px, px)), rim.darkened(0.25))
	_draw_ph_scale(Vector2(size.x * 0.5 - 90, 40))
	# 液面（中身の色。楕円に沿って段をつける）
	for row in [[-12, 10], [-11, 15], [-10, 17], [-9, 17], [-8, 15], [-7, 10]]:
		draw_rect(Rect2(c + Vector2(-row[1] * px, row[0] * px), Vector2(row[1] * 2 * px, px)), liquid_color)
	draw_rect(Rect2(c + Vector2(-15 * px, -11 * px), Vector2(30 * px, px)), liquid_color.lightened(0.25))
	var surf_center := c + Vector2(0, -9.5 * px)
	if _stir_ripple > 0.0:
		LabAssets.dotted_circle(self, surf_center, 30.0 + 20.0 * (1.0 - _stir_ripple), Color(1, 1, 1, 0.5 * _stir_ripple), 12, 3.0)
	if bench.fire != null and bench.vessel_temperature > 100.0:
		# 湯気
		for i in 3:
			var rise := fmod(_flicker * 30.0 + i * 25.0, 70.0)
			draw_circle(c + Vector2(-30 + i * 30 + sin(_flicker * 2.0 + i) * 6.0, -50 - rise), 6.0, Color(1, 1, 1, 0.25 * (1.0 - rise / 70.0)))
	if bench.vessel_cracked:
		draw_string(get_theme_default_font(), c + Vector2(-40, -80), "ひびが入った！", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.5, 0.4))
	# 道具（掛けてあるもの／掴んでいるもの）
	for id in TOOL_HOOKS:
		if id == _held:
			continue
		if id == &"bottle":
			_draw_bottle_hook()
			continue
		LabAssets.blit_center(self, _tool_tex(id), TOOL_HOOKS[id])
	if _held != &"":
		var over := _over_cauldron(_held_pos)
		LabAssets.blit_center(self, _tool_tex(_held), _held_pos, false, Color(1, 1, 1, 1.0) if over else Color(1, 1, 1, 0.8))
		if over:
			LabAssets.dotted_circle(self, c, OVER_RADIUS, Color(1, 1, 1, 0.35), 24, 3.0)
	# 温度
	var font := get_theme_default_font()
	var t := "%d℃" % int(round(bench.vessel_temperature))
	draw_string(font, Vector2(size.x - 80, 28), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.95, 0.85))
	if bench.fire != null:
		var fuel := "燃料 %d%%" % int(round(bench.fire.fuel * 100.0))
		draw_string(font, Vector2(size.x - 170, fz.position.y + 22), fuel + ("（消えている）" if bench.fire.is_out() else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.75, 0.6))

func _draw_fire(c: Vector2) -> void:
	var fz := fire_zone()
	var base := Vector2(c.x, fz.position.y + 28)
	if bench.fire == null:
		draw_string(get_theme_default_font(), Vector2(fz.position.x + 24, fz.position.y + 40), "棚から熱源をドラッグして据える", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.75, 0.6))
		return
	var fire := bench.fire
	var frame: Texture2D = LabAssets.TEX[&"flame_%d" % (int(_flicker * 6.0) % 2)]
	if not fire.is_out():
		var scale := 0.4 + 0.8 * fire.drive
		var sz := frame.get_size() * LabAssets.PX * Vector2(1.0, scale)
		draw_texture_rect(frame, Rect2(base - Vector2(sz.x * 0.5, sz.y), sz), false)
	match fire.source.input_mode:
		HeatSource.InputMode.BELLOWS_HOLD:
			var tex: Texture2D = LabAssets.TEX[&"bellows_%d" % (1 if _squeeze > 0.5 else 0)]
			LabAssets.blit(self, tex, _bellows_rect().position)
			_caption("ふいごを押し続ける" if not _pumping else "火勢 %d%%" % int(round(fire.drive * 100.0)))
		HeatSource.InputMode.FAN_SLIDE:
			var fx := _fan_x if _fan_x > 0.0 else size.x * 0.25
			LabAssets.blit_bottom(self, LabAssets.TEX[&"uchiwa"], Vector2(fx, size.y - 4))
			_caption("火の上で左右にあおぐ")
		_:
			for i in 3:
				LabAssets.blit_bottom(self, LabAssets.TEX[&"log"], Vector2(70 + (i % 2) * 8, size.y - 10 - i * 18), i % 2 == 1)
			_caption("今だ！ 火をクリックして薪を入れる" if fire.is_ember() else ("火が消えた — クリックで点け直す" if fire.is_out() else "燃え盛っている… 炎が小さくなるまで待つ"))

## 掛けてある瓶。瓶詰めできるときは金色に明滅して札を出し、できない間は少し暗い。
func _draw_bottle_hook() -> void:
	var at: Vector2 = TOOL_HOOKS[&"bottle"]
	var tex := _tool_tex(&"bottle")
	if not bottle_ready:
		LabAssets.blit_center(self, tex, at, false, Color(0.7, 0.7, 0.7, 0.85))
		return
	var pulse := 0.5 + 0.5 * sin(_flicker * 5.0)
	draw_circle(at, 46.0 + 6.0 * pulse, Color(1.0, 0.8, 0.3, 0.18 + 0.12 * pulse))
	LabAssets.dotted_circle(self, at, 40.0 + 4.0 * pulse, Color(1.0, 0.85, 0.4, 0.6 + 0.4 * pulse), 16, 3.0)
	LabAssets.blit_center(self, tex, at, false, Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.95, 0.7), pulse))
	# 札（インクの短冊）
	var font := get_theme_default_font()
	var label := "瓶詰めできる"
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var box := Rect2(at + Vector2(-tw * 0.5 - 8, 50), Vector2(tw + 16, 22))
	draw_rect(box, LabAssets.PAPER)
	draw_rect(box, LabAssets.INK, false, 2.0)
	draw_string(font, box.position + Vector2(8, 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, LabAssets.INK)

## pH の目盛り：リトマスの帯（0〜14）と現在値の印。縁の色をここで読む。
func _draw_ph_scale(at: Vector2) -> void:
	var px := LabAssets.PX
	var seg_w := 3
	for i in 15:
		_blit_dot(at + Vector2(i * seg_w * px, 0), seg_w, 2, LabAssets.litmus(float(i)))
	var x := at.x + clampf(ph, 0.0, 14.0) * seg_w * px
	_blit_dot(Vector2(x - px, at.y - 2 * px), 2, 2, Color(1, 0.95, 0.85))
	_blit_dot(Vector2(x - px * 0.5, at.y + 2 * px), 1, 1, Color(1, 0.95, 0.85))
	var font := get_theme_default_font()
	draw_string(font, at + Vector2(0, -12), "pH %.1f" % ph, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.95, 0.85))
	draw_string(font, at + Vector2(-2, 2 * px + 22), "酸", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.75, 0.6))
	draw_string(font, at + Vector2(15 * seg_w * px - 28, 2 * px + 22), "塩基", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.75, 0.6))

func _blit_dot(p: Vector2, w: int, h: int, color: Color) -> void:
	draw_rect(Rect2(LabAssets.snap(p), Vector2(w * LabAssets.PX, h * LabAssets.PX)), color)

func _caption(text: String) -> void:
	var fz := fire_zone()
	draw_string(get_theme_default_font(), Vector2(fz.position.x + 200, fz.end.y - 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.85, 0.6))
