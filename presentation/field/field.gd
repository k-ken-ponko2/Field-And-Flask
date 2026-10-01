## 採取マップのプレイアブルシーン（presentation 層）。
##
## 見た目はキャラクターと同じ「ドット絵を Nearest で 2 倍」に統一する。
##   - 地面: 低コントラストでピクセル化した草地シェーダ
##   - 池:   ピクセル化した揺らめく水面シェーダ＋砂の岸＋葦・睡蓮
##   - 装飾: 木・岩・茂み・草・花・小石のドット絵（影付き・Yソート）、木と草は風で揺れる
##   - 空気: ゆっくり流れる雲の影、漂う花粉、暖色の CanvasModulate、ビネット
## 外部素材は tools/gen_sprites.py が生成する PNG のみ。
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
const PATH_POINTS := [
	Vector2(120, 250), Vector2(520, 430), Vector2(980, 560),
	Vector2(1360, 770), Vector2(1650, 1080), Vector2(1900, 1320),
]
const PATH_WIDTH := 80.0
const STATION_POS := Vector2(1190.0, 620.0)
const STATION_CLEARANCE := 120.0
const INTERACT_RADIUS := 84.0
## 仮の所持素材（採取が実装されるまでの表示用）。
const INVENTORY := {&"vitriol": 3, &"lime": 2, &"water": 6, &"sulfur": 1}

## 地面。1 ドット（2px）単位で「組版」するピクセルアート風シェーダ。
##   - 草: 4 トーンをベイヤー法のディザで切り替え、乾いた場所は黄みに寄せる。
##         葉の縦筋・クローバー・小さな野花をセルのハッシュで散らす
##   - 土のパッチ: ノイズのしきい値をディザで縁取り、小石模様を乗せる
##   - 小道: 線分までの距離で描く。ディザの縁、轍、縁の陰、踏み固められて乾いた帯
##   - 砂の岸: 池の楕円距離で描く。水際は湿って暗い
##   - 裸地: 作業台の足元など、uniform で渡した楕円
## 色はすべて固定パレット（中間色を作らない）なので、スプライトと粒感・色調が揃う。
const GROUND_SHADER := """
shader_type canvas_item;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec2 world_size = vec2(2000.0, 1400.0);
uniform float cell = 2.0;
uniform vec3 grass0 : source_color = vec3(0.24, 0.45, 0.23);
uniform vec3 grass1 : source_color = vec3(0.30, 0.53, 0.27);
uniform vec3 grass2 : source_color = vec3(0.36, 0.60, 0.31);
uniform vec3 grass3 : source_color = vec3(0.47, 0.69, 0.37);
uniform vec3 dry : source_color = vec3(0.58, 0.63, 0.34);
uniform vec3 dirt0 : source_color = vec3(0.48, 0.38, 0.25);
uniform vec3 dirt1 : source_color = vec3(0.64, 0.53, 0.36);
uniform vec3 dirt2 : source_color = vec3(0.73, 0.62, 0.43);
uniform vec3 sand0 : source_color = vec3(0.62, 0.57, 0.42);
uniform vec3 sand1 : source_color = vec3(0.79, 0.72, 0.53);
uniform vec3 clover : source_color = vec3(0.20, 0.40, 0.22);
uniform vec3 flower_a : source_color = vec3(0.96, 0.91, 0.58);
uniform vec3 flower_b : source_color = vec3(0.93, 0.70, 0.78);
uniform vec2 path_points[6];
uniform float path_width = 80.0;
uniform vec2 pond_center = vec2(520.0, 1050.0);
uniform vec2 pond_radius = vec2(210.0, 135.0);
uniform vec3 bare_spots[4];

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float bayer4(vec2 c) {
	int x = int(mod(c.x, 4.0));
	int y = int(mod(c.y, 4.0));
	int m[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
	return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	return length(p - (a + ab * t));
}

vec3 grass_tone(float idx) {
	if (idx < 0.5) { return grass0; }
	if (idx < 1.5) { return grass1; }
	if (idx < 2.5) { return grass2; }
	return grass3;
}

vec3 dirt_tex(vec2 c) {
	float h = hash21(c + 5.0);
	vec3 d = dirt1;
	if (h < 0.10) { d = dirt2; }
	else if (h > 0.96) { d = dirt0; }
	vec2 sc = floor(c / vec2(5.0, 4.0));
	vec2 si = c - sc * vec2(5.0, 4.0);
	if (hash21(sc + 9.0) < 0.06 && si.y == 1.0 && si.x >= 1.0 && si.x <= 2.0) {
		d = (si.x == 1.0) ? dirt2 : dirt0;
	}
	return d;
}

void fragment() {
	vec2 wp = UV * world_size;
	vec2 c = floor(wp / cell);
	vec2 p = (c + 0.5) * cell;
	vec2 uvn = p / world_size;
	float dith = bayer4(c);

	// --- 草地 ---------------------------------------------------------
	float macro = texture(noise, uvn * 2.5).r;
	float mid = texture(noise, uvn * 9.0 + 0.3).r;
	float tone_f = clamp(mid * 0.7 + macro * 0.3, 0.0, 0.999) * 3.0;
	float lo = floor(tone_f);
	float idx = lo + step(dith, tone_f - lo);
	vec3 col = grass_tone(idx);
	float dryness = smoothstep(0.62, 0.88, macro);
	col = mix(col, dry, step(dith, dryness) * 0.4);

	// 葉の縦筋（3 行ごとのグループに 2 ドットの線）。
	float rg = floor(c.y / 3.0);
	vec2 bk = vec2(c.x, rg);
	if (hash21(bk + 7.0) < mix(0.07, 0.03, dryness)) {
		float start = floor(hash21(bk + 3.0) * 2.0);
		float r = c.y - rg * 3.0;
		if (r >= start && r <= start + 1.0) {
			float dir = (hash21(bk + 11.0) < 0.5) ? 1.0 : -1.0;
			col = grass_tone(clamp(idx + dir, 0.0, 3.0));
		}
	}
	// クローバー（3 点）と小さな野花（1 点）。
	vec2 cc = floor(c / 3.0);
	vec2 inner = c - cc * 3.0;
	float ch = hash21(cc + 19.0);
	if (ch < 0.04 * (1.0 - dryness)) {
		if ((inner.y == 1.0 && inner.x != 1.0) || (inner.x == 1.0 && inner.y == 0.0)) { col = clover; }
	} else if (ch > 0.994 && inner.x == 1.0 && inner.y == 1.0) {
		col = (hash21(cc + 23.0) < 0.5) ? flower_a : flower_b;
	}

	// --- 土のパッチ ----------------------------------------------------
	float dn = texture(noise, uvn * 3.2 + 0.61).r;
	float dirt_f = smoothstep(0.77, 0.83, dn);
	col = mix(col, dirt_tex(c), step(dith, dirt_f));

	// --- 小道 ---------------------------------------------------------
	float d = 1e9;
	for (int i = 0; i < 5; i++) {
		d = min(d, seg_dist(p, path_points[i], path_points[i + 1]));
	}
	float half_w = path_width * 0.5;
	float dj = d + (texture(noise, uvn * 18.0 + 0.2).r - 0.5) * 18.0;
	float worn = 1.0 - smoothstep(half_w, half_w + 52.0, dj);
	col = mix(col, dry, step(dith, worn * 0.75) * 0.6);
	vec3 pcol = dirt_tex(c);
	float rut = 1.0 - smoothstep(2.0, 6.0, abs(d - half_w * 0.45));
	pcol = mix(pcol, dirt0, step(dith, rut * 0.5));
	float rim = smoothstep(half_w - 16.0, half_w - 2.0, dj);
	pcol = mix(pcol, dirt0, step(dith, rim * 0.45));
	float path_f = 1.0 - smoothstep(half_w - 8.0, half_w + 6.0, dj);
	col = mix(col, pcol, step(dith, path_f));

	// --- 砂の岸 --------------------------------------------------------
	float pd = length((p - pond_center) / pond_radius);
	float sand_f = 1.0 - smoothstep(1.11, 1.19, pd + (texture(noise, uvn * 14.0).r - 0.5) * 0.05);
	vec3 sand = (pd < 1.045) ? sand0 : ((hash21(c + 31.0) < 0.07) ? sand0 : sand1);
	col = mix(col, sand, step(dith, sand_f));

	// --- 裸地（作業台の足元など） --------------------------------------
	for (int i = 0; i < 4; i++) {
		vec3 s = bare_spots[i];
		if (s.z <= 0.0) { continue; }
		float bd = length((p - s.xy) / vec2(s.z, s.z * 0.5));
		float bf = 1.0 - smoothstep(0.82, 1.06, bd + (hash21(c + 41.0) - 0.5) * 0.1);
		col = mix(col, dirt_tex(c), step(dith, bf));
	}
	COLOR = vec4(col, 1.0);
}
"""

## 水面。頂点の位置をそのまま使い、4px セルで量子化した低周波ノイズから
## 「浅い帯」と「波の筋（ノイズの等高線）」を作ってゆっくり流す。
const WATER_SHADER := """
shader_type canvas_item;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform float cell = 4.0;
uniform vec3 deep : source_color = vec3(0.17, 0.38, 0.50);
uniform vec3 shallow : source_color = vec3(0.22, 0.46, 0.57);
uniform vec3 ripple : source_color = vec3(0.42, 0.66, 0.74);
uniform vec3 glint : source_color = vec3(0.86, 0.94, 0.96);
varying vec2 v_pos;
void vertex() {
	v_pos = VERTEX;
}
void fragment() {
	vec2 p = floor(v_pos / cell) * cell;
	float t = TIME * 0.03;
	float n = texture(noise, p * 0.0012 + vec2(t, t * 0.5)).r;
	float n2 = texture(noise, p * 0.0006 - vec2(t * 0.5, t * 0.15) + 0.5).r;
	vec3 col = mix(deep, shallow, step(0.52, n));
	// ノイズの等高線を波の筋にする（低周波ノイズ × 少ない本数で、間隔の広いゆるい曲線にする）。
	float level = n2 * 1.5 + TIME * 0.05;
	float band = abs(fract(level) - 0.5);
	float line = step(band, 0.045);
	col = mix(col, ripple, line);
	float sparkle = step(0.985, texture(noise, p * 0.01 + vec2(TIME * 0.02, -TIME * 0.015)).r) * line;
	col = mix(col, glint, sparkle);
	COLOR = vec4(col, 1.0);
}
"""

## 雲の影。大きなノイズをゆっくり流し、柔らかく暗くする。
const CLOUD_SHADER := """
shader_type canvas_item;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec2 world_size = vec2(2000.0, 1400.0);
uniform float strength = 0.16;
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
const LabScene = preload("res://presentation/reaction/reaction_lab.tscn")

var _rng := RandomNumberGenerator.new()
var _shadow_tex: Texture2D
var _sway_mat: ShaderMaterial
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
	_build_ground()
	_build_pond()
	_build_path()
	_build_station()
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

# --- 地面 -------------------------------------------------------------------

func _build_ground() -> void:
	var rect := ColorRect.new()
	rect.name = "Ground"
	rect.size = WORLD_SIZE
	rect.color = Color(0.33, 0.56, 0.29)
	rect.z_index = -20
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := _make_material(GROUND_SHADER)
	mat.set_shader_parameter("noise", _make_noise(0.02, 1))
	mat.set_shader_parameter("world_size", WORLD_SIZE)
	mat.set_shader_parameter("path_points", PackedVector2Array(PATH_POINTS))
	mat.set_shader_parameter("path_width", PATH_WIDTH)
	mat.set_shader_parameter("pond_center", POND_CENTER)
	mat.set_shader_parameter("pond_radius", POND_RADIUS)
	# 裸地: (x, y, 横半径)。z が 0 の要素は使われない。
	mat.set_shader_parameter("bare_spots", PackedVector3Array([
		Vector3(STATION_POS.x, STATION_POS.y + 8.0, 62.0),
		Vector3(PLAYER_START.x - 40.0, PLAYER_START.y + 30.0, 46.0),
		Vector3.ZERO,
		Vector3.ZERO,
	]))
	rect.material = mat
	add_child(rect)

# --- 池 ---------------------------------------------------------------------

func _build_pond() -> void:
	# 砂の岸は地面シェーダが描く。ここは水面から。
	var water := Polygon2D.new()
	water.polygon = _ellipse_points(POND_CENTER, POND_RADIUS, 36)
	water.z_index = -11
	var mat := _make_material(WATER_SHADER)
	mat.set_shader_parameter("noise", _make_noise(0.03, 2))
	water.material = mat
	add_child(water)

	# 睡蓮（水面の上に平置き）。
	var pad := FieldArt.prop("lilypad")
	for off in [Vector2(-70, 24), Vector2(44, -34), Vector2(96, 46), Vector2(-20, -58)]:
		_add_decal(pad, POND_CENTER + off, -9)

	# 岸の葦。右上側は開けておく（近づける場所を残す）。
	var reed := FieldArt.prop("reed")
	for i in 22:
		var a := TAU * float(i) / 22.0
		if a > 4.6 and a < 6.0:
			continue
		var jitter := Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-6.0, 6.0))
		var pos := POND_CENTER + Vector2(cos(a) * (POND_RADIUS.x + 18.0), sin(a) * (POND_RADIUS.y + 14.0)) + jitter
		_add_prop(reed, pos, 0.0, Vector2.ZERO, true)

	# 水には入れないよう当たり判定。
	var body := StaticBody2D.new()
	body.position = POND_CENTER
	var col := CollisionPolygon2D.new()
	col.polygon = _ellipse_points(Vector2.ZERO, POND_RADIUS * 0.94, 18)
	body.add_child(col)
	add_child(body)

# --- 小道 -------------------------------------------------------------------

## 小道そのものは地面シェーダが描く。ここでは小石だけ道なりに散らす。
func _build_path() -> void:
	var pebble := FieldArt.prop("pebble")
	for i in PATH_POINTS.size() - 1:
		var a: Vector2 = PATH_POINTS[i]
		var b: Vector2 = PATH_POINTS[i + 1]
		var dir := (b - a).normalized()
		var normal := Vector2(-dir.y, dir.x)
		var steps := int(a.distance_to(b) / 70.0)
		for s in steps:
			var along := a.lerp(b, (float(s) + _rng.randf()) / float(steps))
			var pos := along + normal * _rng.randf_range(-PATH_WIDTH * 0.32, PATH_WIDTH * 0.32)
			_add_decal(pebble, pos, -12)

# --- 作業台 -----------------------------------------------------------------

## 足元の裸地は地面シェーダ（bare_spots）が描く。
func _build_station() -> void:
	_add_prop(FieldArt.prop("station"), STATION_POS, 30.0, Vector2(1.5, 1.1), false)

# --- 装飾物（木・岩・茂み・草・花） -----------------------------------------

func _scatter_props() -> void:
	var trees := FieldArt.trees()
	var mushroom := FieldArt.prop("mushroom")
	for i in 20:
		var at := _place_one(trees[i % trees.size()], 14.0, Vector2(1.25, 1.0), true, 70.0)
		# 木陰にときどきキノコ。
		if at != Vector2.INF and _rng.randf() < 0.4:
			var side := -1.0 if _rng.randf() < 0.5 else 1.0
			_add_prop(mushroom, at + Vector2(side * _rng.randf_range(26.0, 40.0), _rng.randf_range(4.0, 14.0)), 0.0, Vector2.ZERO, false)
	var twig := FieldArt.prop("twig")
	for i in 14:
		var at := _find_free(30.0)
		if at != Vector2.INF:
			_add_decal(twig, at, -10)
	for i in 8:
		_place_one(FieldArt.prop("rock_a"), 16.0, Vector2(0.8, 0.6), false, 60.0)
	for i in 10:
		_place_one(FieldArt.prop("rock_b"), 0.0, Vector2(0.45, 0.4), false, 40.0)
	for i in 16:
		_place_one(FieldArt.prop("bush"), 0.0, Vector2(0.8, 0.7), true, 50.0)
	var tuft := FieldArt.prop("tuft")
	for i in 90:
		_place_one(tuft, 0.0, Vector2.ZERO, true, 30.0)
	_scatter_flowers()

func _scatter_flowers() -> void:
	var flowers := FieldArt.flowers()
	for c in 16:
		var center := _find_free(40.0)
		if center == Vector2.INF:
			continue
		var primary: Texture2D = flowers[_rng.randi_range(0, flowers.size() - 1)]
		var secondary: Texture2D = flowers[_rng.randi_range(0, flowers.size() - 1)]
		for i in _rng.randi_range(4, 8):
			var pos := center + Vector2(_rng.randf_range(-30.0, 30.0), _rng.randf_range(-20.0, 20.0))
			_add_prop(primary if _rng.randf() < 0.7 else secondary, pos, 0.0, Vector2.ZERO, true)

## 空いている場所に 1 つ置き、置いた位置を返す（置けなければ Vector2.INF）。
func _place_one(tex: Texture2D, radius: float, shadow_scale: Vector2, sway: bool, path_margin: float) -> Vector2:
	var p := _find_free(path_margin)
	if p != Vector2.INF:
		_add_prop(tex, p, radius, shadow_scale, sway)
	return p

## 池・小道・開始地点・作業台を避けたランダムな位置を返す（見つからなければ Vector2.INF）。
func _find_free(path_margin: float) -> Vector2:
	for attempt in 60:
		var p := Vector2(
			_rng.randf_range(80.0, WORLD_SIZE.x - 80.0),
			_rng.randf_range(80.0, WORLD_SIZE.y - 80.0)
		)
		if _is_free(p, path_margin):
			return p
	return Vector2.INF

func _is_free(p: Vector2, path_margin: float) -> bool:
	if p.distance_to(PLAYER_START) < 190.0:
		return false
	if p.distance_to(STATION_POS) < STATION_CLEARANCE:
		return false
	var d := p - POND_CENTER
	var rx := POND_RADIUS.x + 70.0
	var ry := POND_RADIUS.y + 60.0
	if (d.x * d.x) / (rx * rx) + (d.y * d.y) / (ry * ry) <= 1.0:
		return false
	return not _near_path(p, path_margin)

func _near_path(p: Vector2, margin: float) -> bool:
	for i in PATH_POINTS.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, PATH_POINTS[i], PATH_POINTS[i + 1])
		if q.distance_to(p) < PATH_WIDTH * 0.5 + margin:
			return true
	return false

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

## 地面に平置きする飾り（小石・睡蓮）。Y ソートに参加せず、指定の z に置く。
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
	# 見えない壁（マップ外周のすぐ外側）。
	_add_wall(Vector2(w * 0.5, -t * 0.5), Vector2(w, t))
	_add_wall(Vector2(w * 0.5, h + t * 0.5), Vector2(w, t))
	_add_wall(Vector2(-t * 0.5, h * 0.5), Vector2(t, h))
	_add_wall(Vector2(w + t * 0.5, h * 0.5), Vector2(t, h))

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

func _add_poly(points: PackedVector2Array, color: Color, z: int) -> void:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	poly.z_index = z
	add_child(poly)

func _add_line(points: PackedVector2Array, width: float, color: Color, z: int) -> void:
	var line := Line2D.new()
	line.points = points
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = z
	add_child(line)
