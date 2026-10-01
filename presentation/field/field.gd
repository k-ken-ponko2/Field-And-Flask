## 採取マップのプレイアブルシーン（presentation 層）。
##
## 見た目はキャラクターと同じ「ドット絵を Nearest で 2 倍」に統一する。
##   - 地形: 16px タイル（草・土・石畳・砂・水）を terrain.gd がデュアルグリッドで敷く。
##           境界は角丸で有機的、タイル画は tools/gen_tiles.py が生成
##   - 構図: 作業台まわりの石畳の広場（柵・街灯・樽・木箱・看板・花壇）、池への枝道と
##           ほとりのベンチ、木立（切り株・キノコ・丈の高い草）、外周を囲む森、花の咲く木
##   - 装飾: 木・岩・茂み・草・花・小石（影付き・Yソート）、木と草は風で揺れる
##   - 空気: 水面の波の筋、ゆっくり流れる雲の影、漂う花粉、暖色の環境光、ビネット
##
## UI（仮）: HUD（季節・ポーチ・ヒント・プロンプト・トースト）を載せ、作業台の前で
## E を押すと反応ラボをオーバーレイで開く。実験中はツリーを pause して時間を止める
## （設計書 §6「実験は時間ゼロ」）。
extends Node2D

const WORLD_SIZE := Vector2(2000.0, 1400.0)
## ドット絵の拡大率（player.gd と揃える）。
const PIXEL := 2.0
const WALL_THICKNESS := 40.0
const PLAYER_START := Vector2(1000.0, 700.0)
const POND_CENTER := Vector2(520.0, 1050.0)
const POND_RADIUS := Vector2(210.0, 135.0)
const SAND_MARGIN := Vector2(40.0, 34.0)
const PATH_POINTS := [
	Vector2(120, 250), Vector2(520, 430), Vector2(980, 560),
	Vector2(1360, 770), Vector2(1650, 1080), Vector2(1900, 1320),
]
const PATH_WIDTH := 72.0
## 池のほとりへ降りる枝道。
const BRANCH_POINTS := [Vector2(1000, 575), Vector2(820, 780), Vector2(715, 905)]
const BRANCH_WIDTH := 52.0
const STATION_POS := Vector2(1190.0, 620.0)
## 作業台まわりの石畳の広場。
const CAMP_RECT := Rect2(1060.0, 540.0, 280.0, 190.0)
const INTERACT_RADIUS := 84.0
## 外周の森の帯（この内側に装飾を散らす）。
const BORDER := 100.0
## 仮の所持素材（採取が実装されるまでの表示用）。
const INVENTORY := {&"vitriol": 3, &"lime": 2, &"water": 6, &"sulfur": 1}

## 水面。タイルの色の上に、ノイズの等高線を波の筋としてゆっくり流す。
const WATER_SHADER := """
shader_type canvas_item;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform float cell = 2.0;
uniform float world_scale = 2.0;
uniform vec3 ripple : source_color = vec3(0.50, 0.72, 0.86);
varying vec2 v_pos;
void vertex() {
	v_pos = VERTEX * world_scale;
}
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 p = floor(v_pos / cell) * cell;
	float t = TIME * 0.03;
	float n2 = texture(noise, p * 0.0006 - vec2(t * 0.5, t * 0.15) + 0.5).r;
	float level = n2 * 1.5 + TIME * 0.05;
	float band = abs(fract(level) - 0.5);
	float line = step(band, 0.035) * step(0.5, tex.a);
	COLOR = vec4(mix(tex.rgb, ripple, line), tex.a);
}
"""

## 雲の影。大きなノイズをゆっくり流し、柔らかく暗くする。
const CLOUD_SHADER := """
shader_type canvas_item;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec2 world_size = vec2(2000.0, 1400.0);
uniform float strength = 0.14;
void fragment() {
	vec2 p = UV * world_size / 1100.0 + vec2(TIME * 0.011, TIME * 0.005);
	float n = texture(noise, p).r;
	float a = smoothstep(0.52, 0.72, n) * strength;
	COLOR = vec4(0.05, 0.09, 0.04, a);
}
"""

## 風の揺れ。上端ほど大きく左右に振る。位置から位相を作るので 1 つのマテリアルを共有できる。
## ドット絵が滲まないよう、揺れ幅は元ピクセル単位に丸める。
const SWAY_SHADER := """
shader_type canvas_item;
uniform float strength = 1.6;
uniform float speed = 1.3;
void vertex() {
	float phase = MODEL_MATRIX[3].x * 0.021 + MODEL_MATRIX[3].y * 0.017;
	float t = 1.0 - UV.y;
	VERTEX.x += floor(sin(TIME * speed + phase) * strength * t * t + 0.5);
}
"""

const VIGNETTE_SHADER := """
shader_type canvas_item;
void fragment() {
	float d = distance(UV, vec2(0.5));
	float v = smoothstep(0.50, 0.95, d);
	COLOR = vec4(0.02, 0.03, 0.02, v * 0.38);
}
"""

const FieldArt = preload("res://presentation/field/field_art.gd")
const FieldHud = preload("res://presentation/field/field_hud.gd")
const Terrain = preload("res://presentation/field/terrain.gd")
const LabScene = preload("res://presentation/reaction/reaction_lab.tscn")

var _rng := RandomNumberGenerator.new()
var _shadow_tex: Texture2D
var _sway_mat: ShaderMaterial
var _terrain: RefCounted
var _calendar := GameCalendar.new()
var _hud: CanvasLayer
var _lab_layer: CanvasLayer
var _near_station := false

@onready var _player: CharacterBody2D = $Player

func _ready() -> void:
	y_sort_enabled = true
	_rng.seed = 20250804
	_shadow_tex = FieldArt.make_shadow()
	_sway_mat = _make_material(SWAY_SHADER)
	_build_terrain()
	_build_pond()
	_build_path_decals()
	_build_camp()
	_build_border_forest()
	_build_groves()
	_scatter_props()
	_build_walls()
	_add_player_shadow()
	_build_atmosphere()
	_setup_camera_limits()
	_build_hud()

func _process(_delta: float) -> void:
	var near := _player.global_position.distance_to(STATION_POS) <= INTERACT_RADIUS
	if near == _near_station:
		return
	_near_station = near
	_hud.set_prompt("反応ラボを開く", near and _lab_layer == null)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _near_station and _lab_layer == null:
		open_lab()
		get_viewport().set_input_as_handled()

# --- 反応ラボ（オーバーレイ） ---------------------------------------------------

## 反応ラボを開く。実験中はフィールドを pause する。
func open_lab() -> void:
	if _lab_layer != null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 120
	layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = _palette(&"scrim", Color(0.08, 0.07, 0.05, 0.5))
	layer.add_child(scrim)

	var lab := LabScene.instantiate() as ReactionLab
	lab.embedded = true
	lab.closed.connect(_on_lab_closed)
	layer.add_child(lab)

	add_child(layer)
	_lab_layer = layer
	_hud.set_prompt("", false)
	_hud.visible = false
	get_tree().paused = true

func _on_lab_closed(note: ReactionNote, product_label: String) -> void:
	get_tree().paused = false
	if _lab_layer != null:
		_lab_layer.queue_free()
		_lab_layer = null
	_hud.visible = true
	_hud.set_prompt("反応ラボを開く", _near_station)
	if note.product_id != &"":
		_hud.toast("実験ノートに記録: %s · 収率 %d%%" % [product_label, int(round(note.recorded_yield * 100.0))])
	elif not note.operations.is_empty():
		_hud.toast("実験を中断した（時間は消費しない）")

# --- HUD -----------------------------------------------------------------------

func _build_hud() -> void:
	_hud = FieldHud.new()
	add_child(_hud)
	_calendar.advance(2)
	_hud.set_calendar(_calendar)
	_hud.set_inventory(_inventory_items())
	_hud.toast("作業台のそばで E を押すと反応ラボが開く")

func _inventory_items() -> Array:
	var items: Array = []
	for id in INVENTORY:
		var m: MaterialDef = load("res://data/materials/%s.tres" % id)
		items.append({
			"id": id,
			"name": m.display_name if m != null else String(id),
			"count": INVENTORY[id],
			"icon": load("res://assets/sprites/item_%s.png" % id),
		})
	return items

func _palette(name: StringName, fallback: Color) -> Color:
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.has_color(name, &"Palette"):
		return theme.get_color(name, &"Palette")
	return fallback

# --- 地形 -------------------------------------------------------------------

func _build_terrain() -> void:
	_terrain = Terrain.new(WORLD_SIZE, 20250804)
	_terrain.paint_polyline(PATH_POINTS, PATH_WIDTH, Terrain.Kind.DIRT)
	_terrain.paint_polyline(BRANCH_POINTS, BRANCH_WIDTH, Terrain.Kind.DIRT)
	_terrain.roughen(Terrain.Kind.DIRT, 0.25)
	_terrain.paint_rect(CAMP_RECT, Terrain.Kind.COBBLE)
	_terrain.paint_ellipse(POND_CENTER, POND_RADIUS + SAND_MARGIN, Terrain.Kind.SAND)
	_terrain.roughen(Terrain.Kind.SAND, 0.3)
	_terrain.paint_ellipse(POND_CENTER, POND_RADIUS, Terrain.Kind.WATER)
	var layers: Dictionary = _terrain.build(self, -20)
	var water: TileMapLayer = layers[Terrain.Kind.WATER]
	var mat := _make_material(WATER_SHADER)
	mat.set_shader_parameter("noise", _make_noise(0.03, 2))
	mat.set_shader_parameter("world_scale", Terrain.SCALE)
	water.material = mat

# --- 池 ---------------------------------------------------------------------

func _build_pond() -> void:
	# 睡蓮（水面の上に平置き）。
	var pad := FieldArt.prop("lilypad")
	for off in [Vector2(-70, 24), Vector2(44, -34), Vector2(96, 46), Vector2(-20, -58)]:
		_add_decal(pad, POND_CENTER + off, -9)

	# 岸の葦。枝道が着く北東側は開けておく。
	var reed := FieldArt.prop("reed")
	for i in 24:
		var a := TAU * float(i) / 24.0
		if a > 4.5 and a < 6.1:
			continue
		var jitter := Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-6.0, 6.0))
		var pos := POND_CENTER + Vector2(cos(a) * (POND_RADIUS.x + 22.0), sin(a) * (POND_RADIUS.y + 18.0)) + jitter
		_add_prop(reed, pos, 0.0, Vector2.ZERO, true)

	# ほとりのベンチと街灯、花の咲く木。
	_add_prop(FieldArt.prop("bench"), Vector2(790.0, 880.0), 18.0, Vector2(0.8, 0.5), false)
	_add_prop(FieldArt.prop("lamp_post"), Vector2(740.0, 860.0), 6.0, Vector2(0.35, 0.3), false)
	_add_prop(FieldArt.prop("tree_blossom"), Vector2(300.0, 840.0), 14.0, Vector2(1.25, 1.0), true)
	_add_prop(FieldArt.prop("tree_blossom"), Vector2(700.0, 1250.0), 14.0, Vector2(1.25, 1.0), true)
	_add_prop(FieldArt.prop("tree_blossom"), Vector2(1500.0, 470.0), 14.0, Vector2(1.25, 1.0), true)

	# 水には入れないよう当たり判定。
	var body := StaticBody2D.new()
	body.position = POND_CENTER
	var col := CollisionPolygon2D.new()
	col.polygon = _ellipse_points(Vector2.ZERO, POND_RADIUS * 0.94, 18)
	body.add_child(col)
	add_child(body)

# --- 小道の小石 -------------------------------------------------------------

func _build_path_decals() -> void:
	var pebble := FieldArt.prop("pebble")
	for i in PATH_POINTS.size() - 1:
		var a: Vector2 = PATH_POINTS[i]
		var b: Vector2 = PATH_POINTS[i + 1]
		var dir := (b - a).normalized()
		var normal := Vector2(-dir.y, dir.x)
		var steps := int(a.distance_to(b) / 110.0)
		for s in steps:
			var along := a.lerp(b, (float(s) + _rng.randf()) / float(steps))
			var pos := along + normal * _rng.randf_range(-PATH_WIDTH * 0.3, PATH_WIDTH * 0.3)
			if _terrain.kind_at_world(pos) == Terrain.Kind.DIRT:
				_add_decal(pebble, pos, -12)

# --- 作業台の広場 -----------------------------------------------------------

func _build_camp() -> void:
	var r := CAMP_RECT
	_add_prop(FieldArt.prop("station"), STATION_POS, 30.0, Vector2(1.5, 1.1), false)

	# 柵: 上辺と右辺を囲い、左辺は小道の入口を空ける。
	_fence_h(r.position.x, r.end.x, r.position.y - 6.0)
	_fence_v(r.end.x + 6.0, r.position.y + 10.0, r.end.y)
	_fence_v(r.position.x - 6.0, r.position.y + 10.0, r.position.y + 50.0)
	_fence_v(r.position.x - 6.0, r.position.y + 150.0, r.end.y)

	# 街灯は入口と出口の角に。
	_add_prop(FieldArt.prop("lamp_post"), Vector2(r.position.x + 18.0, r.position.y + 24.0), 6.0, Vector2(0.35, 0.3), false)
	_add_prop(FieldArt.prop("lamp_post"), Vector2(r.end.x - 20.0, r.end.y - 10.0), 6.0, Vector2(0.35, 0.3), false)

	# 樽と木箱は広場の隅に。
	_add_prop(FieldArt.prop("crate"), Vector2(r.position.x + 60.0, r.position.y + 40.0), 12.0, Vector2(0.6, 0.45), false)
	_add_prop(FieldArt.prop("crate"), Vector2(r.position.x + 92.0, r.position.y + 46.0), 12.0, Vector2(0.6, 0.45), false)
	_add_prop(FieldArt.prop("barrel"), Vector2(r.end.x - 50.0, r.position.y + 36.0), 11.0, Vector2(0.55, 0.4), false)
	_add_prop(FieldArt.prop("barrel"), Vector2(r.end.x - 76.0, r.position.y + 52.0), 11.0, Vector2(0.55, 0.4), false)
	_add_prop(FieldArt.prop("barrel"), Vector2(r.end.x - 44.0, r.end.y - 56.0), 11.0, Vector2(0.55, 0.4), false)
	_add_prop(FieldArt.prop("bench"), Vector2(r.position.x + 70.0, r.end.y - 14.0), 18.0, Vector2(0.8, 0.5), false)
	_add_prop(FieldArt.prop("sign"), Vector2(r.position.x - 30.0, r.position.y + 20.0), 6.0, Vector2.ZERO, false)

	# 花壇は柵の外側に並べる。
	var bed := FieldArt.prop("flowerbed")
	for x in [r.position.x + 40.0, r.position.x + 76.0, r.position.x + 112.0, r.end.x - 112.0, r.end.x - 76.0, r.end.x - 40.0]:
		_add_prop(bed, Vector2(x, r.position.y - 18.0), 0.0, Vector2.ZERO, false)
	for y in [r.position.y + 70.0, r.position.y + 100.0, r.position.y + 130.0]:
		_add_prop(FieldArt.prop("bush_flower"), Vector2(r.end.x + 36.0, y), 0.0, Vector2(0.7, 0.6), true)

## 横の柵: 16px の段を並べ、端に柱を立てる。1 本の当たり判定で塞ぐ。
func _fence_h(from_x: float, to_x: float, y: float) -> void:
	var seg := FieldArt.prop("fence_h")
	var step := seg.get_width() * PIXEL
	var x := from_x
	while x + step <= to_x:
		_add_prop(seg, Vector2(x + step * 0.5, y), 0.0, Vector2.ZERO, false)
		x += step
	_add_prop(FieldArt.prop("fence_post"), Vector2(x + 5.0, y), 0.0, Vector2.ZERO, false)
	_add_wall(Vector2((from_x + x) * 0.5, y - 8.0), Vector2(x - from_x + 10.0, 10.0))

## 縦の柵: 柱を並べる。
func _fence_v(x: float, from_y: float, to_y: float) -> void:
	var post := FieldArt.prop("fence_post")
	var y := from_y
	while y <= to_y:
		_add_prop(post, Vector2(x, y), 0.0, Vector2.ZERO, false)
		y += 20.0
	_add_wall(Vector2(x, (from_y + to_y) * 0.5 - 8.0), Vector2(10.0, to_y - from_y))

# --- 外周の森と木立 ---------------------------------------------------------

func _build_border_forest() -> void:
	var trees := FieldArt.trees()
	var blossom := FieldArt.prop("tree_blossom")
	var step := 54.0
	var pick := func() -> Texture2D:
		return blossom if _rng.randf() < 0.05 else trees[_rng.randi_range(0, trees.size() - 1)]
	# 上下 2 列、左右 2 列。奥の列ほど上に置いて重なりを出す。
	var x := 20.0
	while x < WORLD_SIZE.x:
		_add_prop(pick.call(), Vector2(x + _rng.randf_range(-10, 10), _rng.randf_range(26, 46)), 0.0, Vector2(1.25, 1.0), true)
		_add_prop(pick.call(), Vector2(x + 27.0 + _rng.randf_range(-10, 10), _rng.randf_range(62, 84)), 0.0, Vector2(1.25, 1.0), true)
		_add_prop(pick.call(), Vector2(x + _rng.randf_range(-10, 10), WORLD_SIZE.y - _rng.randf_range(2, 20)), 0.0, Vector2(1.25, 1.0), true)
		_add_prop(pick.call(), Vector2(x + 27.0 + _rng.randf_range(-10, 10), WORLD_SIZE.y - _rng.randf_range(34, 54)), 0.0, Vector2(1.25, 1.0), true)
		x += step
	var y := 100.0
	while y < WORLD_SIZE.y - 60.0:
		_add_prop(pick.call(), Vector2(_rng.randf_range(16, 34), y + _rng.randf_range(-8, 8)), 0.0, Vector2(1.25, 1.0), true)
		_add_prop(pick.call(), Vector2(_rng.randf_range(54, 76), y + 27.0 + _rng.randf_range(-8, 8)), 0.0, Vector2(1.25, 1.0), true)
		_add_prop(pick.call(), Vector2(WORLD_SIZE.x - _rng.randf_range(16, 34), y + _rng.randf_range(-8, 8)), 0.0, Vector2(1.25, 1.0), true)
		_add_prop(pick.call(), Vector2(WORLD_SIZE.x - _rng.randf_range(54, 76), y + 27.0 + _rng.randf_range(-8, 8)), 0.0, Vector2(1.25, 1.0), true)
		y += step

func _build_groves() -> void:
	var trees := FieldArt.trees()
	for center in [Vector2(320, 380), Vector2(1620, 300), Vector2(1740, 980), Vector2(380, 660), Vector2(1150, 1180)]:
		for i in 6:
			var p: Vector2 = center + Vector2(_rng.randf_range(-120, 120), _rng.randf_range(-80, 80))
			if _is_free(p, 20.0):
				_add_prop(trees[_rng.randi_range(0, trees.size() - 1)], p, 14.0, Vector2(1.25, 1.0), true)
		for tex_name in ["bush", "stump", "mushroom", "mushroom", "tall_grass", "tall_grass", "tall_grass", "bush_flower"]:
			var p: Vector2 = center + Vector2(_rng.randf_range(-150, 150), _rng.randf_range(-100, 100))
			if _is_free(p, 10.0):
				var solid := 10.0 if tex_name in ["bush", "stump"] else 0.0
				var shadow := Vector2(0.8, 0.6) if tex_name in ["bush", "stump", "bush_flower"] else Vector2.ZERO
				_add_prop(FieldArt.prop(tex_name), p, solid, shadow, tex_name != "stump")

# --- 散らす装飾（岩・茂み・草・花） -----------------------------------------

func _scatter_props() -> void:
	for i in 6:
		_place_one(FieldArt.prop("rock_a"), 16.0, Vector2(0.8, 0.6), false, 20.0)
	for i in 10:
		_place_one(FieldArt.prop("rock_b"), 0.0, Vector2(0.45, 0.4), false, 8.0)
	for i in 10:
		_place_one(FieldArt.prop("bush"), 0.0, Vector2(0.8, 0.7), true, 16.0)
	for i in 8:
		_place_one(FieldArt.prop("bush_flower"), 0.0, Vector2(0.8, 0.7), true, 16.0)
	for i in 30:
		_place_one(FieldArt.prop("tall_grass"), 0.0, Vector2.ZERO, true, 8.0)
	var tuft := FieldArt.prop("tuft")
	for i in 70:
		_place_one(tuft, 0.0, Vector2.ZERO, true, 4.0)
	var twig := FieldArt.prop("twig")
	for i in 12:
		var at := _find_free(8.0)
		if at != Vector2.INF:
			_add_decal(twig, at, -10)
	_scatter_flowers()

func _scatter_flowers() -> void:
	var flowers := FieldArt.flowers()
	for c in 16:
		var center := _find_free(30.0)
		if center == Vector2.INF:
			continue
		var primary: Texture2D = flowers[_rng.randi_range(0, flowers.size() - 1)]
		var secondary: Texture2D = flowers[_rng.randi_range(0, flowers.size() - 1)]
		for i in _rng.randi_range(4, 8):
			var pos := center + Vector2(_rng.randf_range(-30.0, 30.0), _rng.randf_range(-20.0, 20.0))
			_add_prop(primary if _rng.randf() < 0.7 else secondary, pos, 0.0, Vector2.ZERO, true)

## 空いている場所に 1 つ置き、置いた位置を返す（置けなければ Vector2.INF）。
func _place_one(tex: Texture2D, radius: float, shadow_scale: Vector2, sway: bool, margin: float) -> Vector2:
	var p := _find_free(margin)
	if p != Vector2.INF:
		_add_prop(tex, p, radius, shadow_scale, sway)
	return p

## 草地で、池・小道・広場・開始地点・作業台・外周の森から離れたランダムな位置を返す。
func _find_free(margin: float) -> Vector2:
	for attempt in 60:
		var p := Vector2(
			_rng.randf_range(BORDER, WORLD_SIZE.x - BORDER),
			_rng.randf_range(BORDER, WORLD_SIZE.y - BORDER)
		)
		if _is_free(p, margin):
			return p
	return Vector2.INF

func _is_free(p: Vector2, margin: float) -> bool:
	if p.x < BORDER or p.y < BORDER or p.x > WORLD_SIZE.x - BORDER or p.y > WORLD_SIZE.y - BORDER:
		return false
	if p.distance_to(PLAYER_START) < 150.0:
		return false
	if CAMP_RECT.grow(40.0).has_point(p):
		return false
	for off in [Vector2.ZERO, Vector2(margin, 0), Vector2(-margin, 0), Vector2(0, margin), Vector2(0, -margin)]:
		if _terrain.kind_at_world(p + off) != Terrain.Kind.GRASS:
			return false
	return true

## Y ソートされる立ち物。原点が足元になるよう、2 倍にしたスプライトを上にずらす。
## radius > 0 なら円の当たり判定を付ける。shadow_scale が ZERO なら影なし。
func _add_prop(tex: Texture2D, pos: Vector2, radius: float, shadow_scale: Vector2, sway: bool) -> void:
	var n := Node2D.new()
	n.position = pos

	if shadow_scale != Vector2.ZERO and _shadow_tex != null:
		var sh := Sprite2D.new()
		sh.texture = _shadow_tex
		sh.scale = shadow_scale
		sh.z_index = -1
		n.add_child(sh)

	var spr := Sprite2D.new()
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(PIXEL, PIXEL)
	spr.position = Vector2(0.0, -tex.get_height() * PIXEL * 0.5)
	if sway:
		spr.material = _sway_mat
	n.add_child(spr)

	if radius > 0.0:
		var body := StaticBody2D.new()
		var col := CollisionShape2D.new()
		var shp := CircleShape2D.new()
		shp.radius = radius
		col.shape = shp
		body.add_child(col)
		n.add_child(body)

	add_child(n)

## 地面に平置きする飾り（小石・睡蓮・小枝）。Y ソートに参加せず、指定の z に置く。
func _add_decal(tex: Texture2D, pos: Vector2, z: int) -> void:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(PIXEL, PIXEL)
	spr.position = pos
	spr.z_index = z
	add_child(spr)

# --- 境界・カメラ・雰囲気 ---------------------------------------------------

func _build_walls() -> void:
	var t := WALL_THICKNESS
	var w := WORLD_SIZE.x
	var h := WORLD_SIZE.y
	# 見えない壁。外周の森の内側で止める。
	var inset := BORDER - 20.0
	_add_wall(Vector2(w * 0.5, inset - t * 0.5), Vector2(w, t))
	_add_wall(Vector2(w * 0.5, h - inset + t * 0.5), Vector2(w, t))
	_add_wall(Vector2(inset - t * 0.5, h * 0.5), Vector2(t, h))
	_add_wall(Vector2(w - inset + t * 0.5, h * 0.5), Vector2(t, h))

func _add_wall(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _add_player_shadow() -> void:
	if _shadow_tex == null:
		return
	var sh := Sprite2D.new()
	sh.texture = _shadow_tex
	sh.scale = Vector2(0.6, 0.55)
	sh.z_index = -1
	sh.position = Vector2(0.0, 12.0)
	_player.add_child(sh)

func _build_atmosphere() -> void:
	# 暖色の環境光。
	var cm := CanvasModulate.new()
	cm.color = Color(1.0, 0.97, 0.90)
	add_child(cm)

	# 雲の影（立ち物より上、UI より下）。
	var clouds := ColorRect.new()
	clouds.size = WORLD_SIZE
	clouds.z_index = 30
	clouds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cmat := _make_material(CLOUD_SHADER)
	cmat.set_shader_parameter("noise", _make_noise(0.012, 3))
	cmat.set_shader_parameter("world_size", WORLD_SIZE)
	clouds.material = cmat
	add_child(clouds)

	# 漂う花粉。プレイヤーに付けて発生範囲だけ追従させる（粒子自体はワールド座標）。
	var pollen := CPUParticles2D.new()
	pollen.amount = 36
	pollen.lifetime = 9.0
	pollen.preprocess = 9.0
	pollen.local_coords = false
	pollen.texture = FieldArt.make_dot()
	pollen.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	pollen.emission_rect_extents = Vector2(760.0, 440.0)
	pollen.direction = Vector2(1.0, -0.25)
	pollen.spread = 70.0
	pollen.gravity = Vector2.ZERO
	pollen.initial_velocity_min = 5.0
	pollen.initial_velocity_max = 14.0
	pollen.color = Color(1.0, 0.96, 0.72)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
	pollen.color_ramp = ramp
	pollen.z_index = 40
	_player.add_child(pollen)

	# ビネット。
	var layer := CanvasLayer.new()
	layer.layer = 100
	var vig := ColorRect.new()
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.material = _make_material(VIGNETTE_SHADER)
	layer.add_child(vig)
	add_child(layer)

func _setup_camera_limits() -> void:
	var cam := _player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(WORLD_SIZE.x)
	cam.limit_bottom = int(WORLD_SIZE.y)

# --- 図形・マテリアルのヘルパ -----------------------------------------------

func _make_material(code: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = code
	mat.shader = sh
	return mat

func _make_noise(frequency: float, seed_value: int) -> NoiseTexture2D:
	var fnl := FastNoiseLite.new()
	fnl.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fnl.frequency = frequency
	fnl.seed = seed_value
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = fnl
	return tex

func _ellipse_points(center: Vector2, radius: Vector2, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return pts
