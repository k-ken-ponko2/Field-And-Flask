## 地形タイルのビルダー（presentation 層）。
##
## ワールドを 32px（16px タイル × 2 倍）の格子に切り、各セルの種別（草・土・石畳・砂・水）を
## 塗ってから、TileMapLayer に焼く。種別の境界は「デュアルグリッド」で描く:
## 表示タイルを半セルずらし、4 隅のセルがその種別かどうかの 4 ビットで
## 16 種の遷移タイル（tools/gen_tiles.py が生成）を選ぶ。これで角丸の有機的な境界になる。
##
## 重ね順: 草（全面） → 土 → 石畳 → 砂 → 水。上の層は自分の種別だけ不透明に描く。
## global class_name は使わず、利用側から preload して使う。
extends RefCounted

enum Kind { GRASS, DIRT, COBBLE, SAND, WATER }

const TILE := 16
const SCALE := 2.0
const CELL := TILE * SCALE
const ATLAS_PATH := "res://assets/tiles/terrain.png"
const GRASS_VARIANTS := 6
## 草は明るい組（列 0〜5）と暗い組（列 6〜11）があり、低周波ノイズで塗り分ける。
const GRASS_SETS := 2
## 草バリエーションの出現比率（無地を多めに）。
const GRASS_WEIGHTS := [46, 18, 10, 8, 6, 12]
## 全面タイル（4 隅すべて自分の種別）のバリエーション行と、種別ごとの列オフセット。
const FULL_ROW := 5
const FULL_VARIANTS := 4
## 遷移タイルの行（アトラス上）と、その層が「自分の種別とみなす」種別。
const OVERLAYS := [
	{"kind": Kind.DIRT, "row": 1, "full_col": 0, "covers": [Kind.DIRT]},
	{"kind": Kind.COBBLE, "row": 2, "full_col": 4, "covers": [Kind.COBBLE]},
	{"kind": Kind.SAND, "row": 3, "full_col": 8, "covers": [Kind.SAND, Kind.WATER]},
	{"kind": Kind.WATER, "row": 4, "full_col": 12, "covers": [Kind.WATER]},
]

var cols: int
var rows: int
var _kinds: PackedInt32Array
var _rng := RandomNumberGenerator.new()
var _tone_noise := FastNoiseLite.new()

func _init(world_size: Vector2, seed_value: int) -> void:
	cols = int(ceil(world_size.x / CELL)) + 1
	rows = int(ceil(world_size.y / CELL)) + 1
	_kinds.resize(cols * rows)
	_kinds.fill(Kind.GRASS)
	_rng.seed = seed_value
	_tone_noise.seed = seed_value
	_tone_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_tone_noise.frequency = 0.045

# --- 塗り（ワールド座標 px） -----------------------------------------------------

func kind_at(cx: int, cy: int) -> int:
	if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
		return Kind.GRASS
	return _kinds[cy * cols + cx]

func kind_at_world(p: Vector2) -> int:
	return kind_at(int(floor(p.x / CELL)), int(floor(p.y / CELL)))

func set_kind(cx: int, cy: int, kind: int) -> void:
	if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
		return
	_kinds[cy * cols + cx] = kind

func paint_ellipse(center: Vector2, radius: Vector2, kind: int) -> void:
	var inside := func(c: Vector2) -> bool:
		var d := (c - center) / radius
		return d.dot(d) <= 1.0
	_paint(inside, kind)

func paint_rect(rect: Rect2, kind: int) -> void:
	var inside := func(c: Vector2) -> bool:
		return rect.has_point(c)
	_paint(inside, kind)

func paint_polyline(points: Array, width: float, kind: int) -> void:
	var half := width * 0.5
	var inside := func(c: Vector2) -> bool:
		for i in points.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(c, points[i], points[i + 1])
			if q.distance_to(c) <= half:
				return true
		return false
	_paint(inside, kind)

## 塗った領域の縁を少し崩す（直線的な境界にゆらぎを足す）。
func roughen(kind: int, chance: float) -> void:
	var snapshot := _kinds.duplicate()
	for cy in rows:
		for cx in cols:
			if snapshot[cy * cols + cx] != kind:
				continue
			var edge := false
			for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := _kind_in(snapshot, cx + off.x, cy + off.y)
				if n != kind:
					edge = true
			if edge and _rng.randf() < chance:
				var off: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][_rng.randi_range(0, 3)]
				if _kind_in(snapshot, cx + off.x, cy + off.y) == Kind.GRASS:
					set_kind(cx + off.x, cy + off.y, kind)

func _kind_in(arr: PackedInt32Array, cx: int, cy: int) -> int:
	if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
		return Kind.GRASS
	return arr[cy * cols + cx]

func _paint(inside: Callable, kind: int) -> void:
	for cy in rows:
		for cx in cols:
			var center := Vector2((cx + 0.5) * CELL, (cy + 0.5) * CELL)
			if inside.call(center):
				_kinds[cy * cols + cx] = kind

# --- TileMapLayer への焼き込み ---------------------------------------------------

## 層を parent に追加し、種別 → TileMapLayer の辞書を返す（水面シェーダなどを付けるため）。
func build(parent: Node, z_base: int) -> Dictionary:
	var tile_set := _make_tile_set()
	var layers := {}

	var grass := _make_layer(tile_set, z_base)
	for cy in rows:
		for cx in cols:
			# 明暗の境界がセルの四角で目立たないよう、しきい値をセルごとに揺らす。
			var tone := _tone_noise.get_noise_2d(cx, cy) + _rng.randf_range(-0.09, 0.09)
			var set_offset := GRASS_VARIANTS if tone > 0.08 else 0
			grass.set_cell(Vector2i(cx, cy), 0, Vector2i(_pick_grass_variant() + set_offset, 0))
	parent.add_child(grass)
	layers[Kind.GRASS] = grass

	for i in OVERLAYS.size():
		var spec: Dictionary = OVERLAYS[i]
		var layer := _make_layer(tile_set, z_base + 1 + i)
		# 半セルずらす: 表示タイル (x, y) の左上隅がワールドセル (x, y) の中心に来る。
		layer.position = Vector2(CELL * 0.5, CELL * 0.5)
		var covers: Array = spec["covers"]
		for cy in range(-1, rows):
			for cx in range(-1, cols):
				var mask := 0
				if covers.has(kind_at(cx, cy)):
					mask |= 1
				if covers.has(kind_at(cx + 1, cy)):
					mask |= 2
				if covers.has(kind_at(cx, cy + 1)):
					mask |= 4
				if covers.has(kind_at(cx + 1, cy + 1)):
					mask |= 8
				if mask == 15:
					var col: int = spec["full_col"] + _rng.randi_range(0, FULL_VARIANTS - 1)
					layer.set_cell(Vector2i(cx, cy), 0, Vector2i(col, FULL_ROW))
				elif mask != 0:
					layer.set_cell(Vector2i(cx, cy), 0, Vector2i(mask, spec["row"]))
		parent.add_child(layer)
		layers[spec["kind"]] = layer
	return layers

func _pick_grass_variant() -> int:
	var total := 0
	for w in GRASS_WEIGHTS:
		total += w
	var roll := _rng.randi_range(0, total - 1)
	for i in GRASS_WEIGHTS.size():
		roll -= GRASS_WEIGHTS[i]
		if roll < 0:
			return i
	return 0

func _make_layer(tile_set: TileSet, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	layer.scale = Vector2(SCALE, SCALE)
	layer.z_index = z
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return layer

func _make_tile_set() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = load(ATLAS_PATH)
	src.texture_region_size = Vector2i(TILE, TILE)
	for col in GRASS_VARIANTS * GRASS_SETS:
		src.create_tile(Vector2i(col, 0))
	for spec in OVERLAYS:
		for col in range(1, 16):
			src.create_tile(Vector2i(col, spec["row"]))
	for col in OVERLAYS.size() * FULL_VARIANTS:
		src.create_tile(Vector2i(col, FULL_ROW))
	ts.add_source(src, 0)
	return ts
