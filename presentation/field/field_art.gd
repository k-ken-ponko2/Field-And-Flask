## フィールドの装飾テクスチャを供給する（presentation 層）。
##
## 木・岩・茂み・草・花・葦・睡蓮・小石・作業台はドット絵スプライト
## （assets/sprites/prop_*.png、tools/gen_sprites.py で生成）を読み込んで返し、
## Godot 側では Nearest の 2 倍で描く（キャラクターと解像感を揃える）。
## 足元の影だけは滑らかな楕円が欲しいので、ここで手続き生成する。
##
## global class_name は使わず、利用側から preload して使う（未インポート状態でも動く）。
extends RefCounted

const SPRITE_DIR := "res://assets/sprites/"
const TREE_VARIANTS: Array[String] = ["tree_a", "tree_b", "tree_c"]
const FLOWER_VARIANTS: Array[String] = ["flower_pink", "flower_white", "flower_yellow", "flower_blue"]

## prop_<name>.png を読み込む。
static func prop(name: String) -> Texture2D:
	return load(SPRITE_DIR + "prop_%s.png" % name)

static func trees() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for n in TREE_VARIANTS:
		out.append(prop(n))
	return out

static func flowers() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for n in FLOWER_VARIANTS:
		out.append(prop(n))
	return out

## 足元の柔らかい楕円影。
static func make_shadow() -> Texture2D:
	var w := 56
	var h := 22
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := w / 2.0
	var cy := h / 2.0
	var rx := w / 2.0
	var ry := h / 2.0
	for y in h:
		for x in w:
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			var d := dx * dx + dy * dy
			if d <= 1.0:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, (1.0 - d) * 0.30))
	return ImageTexture.create_from_image(img)

## 花粉パーティクル用の 2×2 の点。
static func make_dot() -> Texture2D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)
