## 採取マップの最初のプレイアブルシーン（presentation 層）。
##
## この段階の目的は「キャラクターがマップ上を動ける」こと。地面はグリッド描画の
## プレースホルダで、後で TileMapLayer + TileSet（設計書 §8）に差し替える。
## 境界の壁と障害物は衝突確認のためにコードで生成する。
extends Node2D

## マップの広さ（px）。
const WORLD_SIZE := Vector2(2000.0, 1400.0)
const WALL_THICKNESS := 40.0
const CELL := 64.0

@onready var _player: CharacterBody2D = $Player

func _ready() -> void:
	_build_walls()
	_build_obstacles()
	_setup_camera_limits()

func _draw() -> void:
	# 背景。
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.16, 0.22, 0.17), true)
	# グリッド線（地面の目安・移動が見えるように）。
	var grid := Color(1, 1, 1, 0.06)
	var x := 0.0
	while x <= WORLD_SIZE.x:
		draw_line(Vector2(x, 0), Vector2(x, WORLD_SIZE.y), grid, 1.0)
		x += CELL
	var y := 0.0
	while y <= WORLD_SIZE.y:
		draw_line(Vector2(0, y), Vector2(WORLD_SIZE.x, y), grid, 1.0)
		y += CELL
	# 外周。
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.4, 0.5, 0.4), false, 2.0)

func _build_walls() -> void:
	var t := WALL_THICKNESS
	var w := WORLD_SIZE.x
	var h := WORLD_SIZE.y
	# 上・下・左・右（中心座標, サイズ）。
	_add_wall(Vector2(w * 0.5, t * 0.5), Vector2(w, t))
	_add_wall(Vector2(w * 0.5, h - t * 0.5), Vector2(w, t))
	_add_wall(Vector2(t * 0.5, h * 0.5), Vector2(t, h))
	_add_wall(Vector2(w - t * 0.5, h * 0.5), Vector2(t, h))

func _build_obstacles() -> void:
	# 衝突を体感するための障害物をいくつか。将来は採取ポイント等に置き換える。
	_add_wall(Vector2(600, 500), Vector2(120, 120), Color(0.35, 0.3, 0.25))
	_add_wall(Vector2(1300, 900), Vector2(200, 80), Color(0.35, 0.3, 0.25))
	_add_wall(Vector2(1000, 300), Vector2(80, 260), Color(0.35, 0.3, 0.25))

func _add_wall(center: Vector2, size: Vector2, color: Color = Color(0.22, 0.28, 0.3)) -> void:
	var body := StaticBody2D.new()
	body.position = center

	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)

	var visual := Polygon2D.new()
	visual.color = color
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	visual.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)
	])
	body.add_child(visual)

	add_child(body)

func _setup_camera_limits() -> void:
	var cam := _player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(WORLD_SIZE.x)
	cam.limit_bottom = int(WORLD_SIZE.y)
