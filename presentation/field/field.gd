## 採取マップのプレイアブルシーン（presentation 層）。
##
## 見た目を「それっぽく」するため、地面はシームレスノイズのシェーダ、木・岩・茂み・草は
## FieldArt が生成するテクスチャで配置し、影付き＋Yソートで奥行きを出す。池・小道・
## ビネットで雰囲気を付ける。すべて手続き生成なので外部素材は不要（後で差し替え可能）。
extends Node2D

const WORLD_SIZE := Vector2(2000.0, 1400.0)
const WALL_THICKNESS := 40.0
const PLAYER_START := Vector2(1000.0, 700.0)
const POND_CENTER := Vector2(520.0, 1050.0)
const POND_RADIUS := Vector2(210.0, 135.0)

const GROUND_SHADER := """
shader_type canvas_item;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec2 repeat = vec2(8.0, 6.0);
uniform vec3 c_low : source_color = vec3(0.16, 0.34, 0.15);
uniform vec3 c_mid : source_color = vec3(0.25, 0.47, 0.22);
uniform vec3 c_high : source_color = vec3(0.39, 0.60, 0.29);
void fragment() {
	float n = texture(noise, UV * repeat).r;
	float n2 = texture(noise, UV * repeat * 3.3 + vec2(0.37)).r;
	vec3 col = mix(c_low, c_mid, smoothstep(0.35, 0.55, n));
	col = mix(col, c_high, smoothstep(0.62, 0.85, n));
	col *= 0.94 + 0.12 * n2;
	COLOR = vec4(col, 1.0);
}
"""

const VIGNETTE_SHADER := """
shader_type canvas_item;
void fragment() {
	float d = distance(UV, vec2(0.5));
	float v = smoothstep(0.48, 0.92, d);
	COLOR = vec4(0.0, 0.0, 0.0, v * 0.45);
}
"""

var _rng := RandomNumberGenerator.new()
var _shadow_tex: Texture2D

@onready var _player: CharacterBody2D = $Player

func _ready() -> void:
	y_sort_enabled = true
	_rng.seed = 20250804
	_shadow_tex = FieldArt.make_shadow()
	_build_ground()
	_build_pond()
	_build_path()
	_scatter_props()
	_build_walls()
	_add_player_shadow()
	_build_atmosphere()
	_setup_camera_limits()

# --- 地面 -------------------------------------------------------------------

func _build_ground() -> void:
	var fnl := FastNoiseLite.new()
	fnl.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fnl.frequency = 0.03

	var noise_tex := NoiseTexture2D.new()
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true
	noise_tex.noise = fnl

	var rect := ColorRect.new()
	rect.name = "Ground"
	rect.size = WORLD_SIZE
	rect.color = Color(0.25, 0.47, 0.22)
	rect.z_index = -20
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GROUND_SHADER
	mat.shader = sh
	mat.set_shader_parameter("noise", noise_tex)
	mat.set_shader_parameter("repeat", WORLD_SIZE / 230.0)
	rect.material = mat
	add_child(rect)

# --- 池 ---------------------------------------------------------------------

func _build_pond() -> void:
	_add_poly(_ellipse_points(POND_CENTER, POND_RADIUS + Vector2(18, 14), 30), Color(0.72, 0.66, 0.47), -12)
	_add_poly(_ellipse_points(POND_CENTER, POND_RADIUS, 30), Color(0.20, 0.44, 0.55), -11)
	_add_poly(_ellipse_points(POND_CENTER - Vector2(0, 10), POND_RADIUS * 0.7, 28), Color(0.16, 0.37, 0.50), -11)
	_add_poly(_ellipse_points(POND_CENTER - POND_RADIUS * Vector2(0.3, 0.35), POND_RADIUS * 0.26, 20), Color(0.42, 0.63, 0.71, 0.7), -11)

	# 水には入れないよう当たり判定。
	var body := StaticBody2D.new()
	body.position = POND_CENTER
	var col := CollisionPolygon2D.new()
	col.polygon = _ellipse_points(Vector2.ZERO, POND_RADIUS * 0.92, 16)
	body.add_child(col)
	add_child(body)

# --- 小道 -------------------------------------------------------------------

func _build_path() -> void:
	var pts := PackedVector2Array([
		Vector2(120, 250), Vector2(520, 430), Vector2(980, 560),
		Vector2(1360, 770), Vector2(1650, 1080), Vector2(1900, 1320),
	])
	_add_line(pts, 86.0, Color(0.50, 0.40, 0.28), -14)
	_add_line(pts, 64.0, Color(0.66, 0.54, 0.36), -13)

# --- 装飾物（木・岩・茂み・草） ---------------------------------------------

func _scatter_props() -> void:
	_place_many(FieldArt.make_tree(), 16, true, 12.0, true)
	_place_many(FieldArt.make_rock(), 10, true, 15.0, true)
	_place_many(FieldArt.make_bush(), 14, false, 0.0, true)
	_place_many(FieldArt.make_tuft(), 28, false, 0.0, false)

func _place_many(tex: Texture2D, count: int, solid: bool, radius: float, shadow: bool) -> void:
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 40:
		attempts += 1
		var p := Vector2(
			_rng.randf_range(80.0, WORLD_SIZE.x - 80.0),
			_rng.randf_range(80.0, WORLD_SIZE.y - 80.0)
		)
		if not _is_free(p):
			continue
		_add_prop(tex, p, solid, radius, shadow)
		placed += 1

func _is_free(p: Vector2) -> bool:
	if p.distance_to(PLAYER_START) < 190.0:
		return false
	var d := p - POND_CENTER
	var rx := POND_RADIUS.x + 50.0
	var ry := POND_RADIUS.y + 50.0
	if (d.x * d.x) / (rx * rx) + (d.y * d.y) / (ry * ry) <= 1.0:
		return false
	return true

func _add_prop(tex: Texture2D, pos: Vector2, solid: bool, radius: float, shadow: bool) -> void:
	var n := Node2D.new()
	n.position = pos

	if shadow and _shadow_tex != null:
		var sh := Sprite2D.new()
		sh.texture = _shadow_tex
		sh.z_index = -1
		n.add_child(sh)

	var spr := Sprite2D.new()
	spr.texture = tex
	spr.position = Vector2(0.0, -tex.get_height() / 2.0)
	n.add_child(spr)

	if solid:
		var body := StaticBody2D.new()
		var col := CollisionShape2D.new()
		var shp := CircleShape2D.new()
		shp.radius = radius
		col.shape = shp
		body.add_child(col)
		n.add_child(body)

	add_child(n)

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
	sh.z_index = -1
	sh.position = Vector2(0.0, 10.0)
	_player.add_child(sh)

func _build_atmosphere() -> void:
	var cm := CanvasModulate.new()
	cm.color = Color(0.98, 0.96, 0.90)
	add_child(cm)

	var layer := CanvasLayer.new()
	layer.layer = 100
	var vig := ColorRect.new()
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER
	mat.shader = sh
	vig.material = mat
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

# --- 図形ヘルパ -------------------------------------------------------------

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
