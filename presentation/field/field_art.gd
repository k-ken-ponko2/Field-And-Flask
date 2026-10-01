## フィールドの装飾テクスチャをコードで生成する（presentation 層）。
##
## アート素材が無くても「それっぽい」見た目にするための手続き生成。ピクセル単位で
## 陰影を付けた木・岩・茂み・草・影を作る。将来は本物のスプライトに差し替え可能。
##
## global class_name は使わず、利用側から preload して使う（未インポート状態でも動く）。
extends RefCounted

const TRUNK := Color(0.42, 0.30, 0.20)
const TRUNK_HI := Color(0.52, 0.39, 0.27)
const LEAF_LOW := Color(0.16, 0.34, 0.16)
const LEAF_MID := Color(0.24, 0.47, 0.22)
const LEAF_HI := Color(0.38, 0.62, 0.30)
const GRAY_LOW := Color(0.36, 0.39, 0.43)
const GRAY_MID := Color(0.50, 0.52, 0.55)
const GRAY_HI := Color(0.68, 0.70, 0.72)

static func make_tree() -> Texture2D:
	var w := 60
	var h := 80
	var img := _new(w, h)
	# 幹（先に描いて樹冠で上を隠す）。
	_rect(img, 26, 52, 8, 26, TRUNK)
	_rect(img, 26, 52, 3, 26, TRUNK_HI)
	# 樹冠（下影 → 中間 → ハイライトの順）。
	_circle(img, 30, 32, 22, LEAF_MID)
	_circle(img, 18, 30, 14, LEAF_MID)
	_circle(img, 44, 30, 13, LEAF_MID)
	_circle(img, 32, 42, 16, LEAF_LOW)
	_circle(img, 30, 30, 19, LEAF_MID)
	_circle(img, 23, 23, 11, LEAF_HI)
	_circle(img, 31, 26, 7, LEAF_HI)
	return _tex(img)

static func make_rock() -> Texture2D:
	var img := _new(50, 36)
	_ellipse(img, 25, 22, 21, 12, GRAY_MID)
	_ellipse(img, 25, 26, 19, 9, GRAY_LOW)
	_ellipse(img, 25, 20, 20, 10, GRAY_MID)
	_ellipse(img, 18, 16, 9, 5, GRAY_HI)
	return _tex(img)

static func make_bush() -> Texture2D:
	var img := _new(46, 36)
	_circle(img, 14, 22, 11, LEAF_MID)
	_circle(img, 32, 22, 11, LEAF_MID)
	_circle(img, 23, 18, 13, LEAF_MID)
	_circle(img, 23, 27, 12, LEAF_LOW)
	_circle(img, 18, 15, 6, LEAF_HI)
	_circle(img, 30, 17, 5, LEAF_HI)
	return _tex(img)

static func make_tuft() -> Texture2D:
	var w := 22
	var h := 16
	var img := _new(w, h)
	var blades := [Color(0.20, 0.42, 0.18), Color(0.31, 0.53, 0.25), Color(0.24, 0.47, 0.20)]
	var xs := [3, 7, 11, 15, 18]
	for i in xs.size():
		var bh := 6 + (i * 2) % 6
		_rect(img, xs[i], h - bh - 2, 2, bh, blades[i % blades.size()])
	return _tex(img)

## 足元の柔らかい楕円影。
static func make_shadow() -> Texture2D:
	var w := 56
	var h := 22
	var img := _new(w, h)
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
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, (1.0 - d) * 0.32))
	return _tex(img)

# --- 低レベル描画ヘルパ ------------------------------------------------------

static func _new(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img

static func _tex(img: Image) -> Texture2D:
	return ImageTexture.create_from_image(img)

static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in range(y, y + h):
		for i in range(x, x + w):
			if i >= 0 and j >= 0 and i < img.get_width() and j < img.get_height():
				img.set_pixel(i, j, c)

static func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for j in range(cy - ry, cy + ry + 1):
		for i in range(cx - rx, cx + rx + 1):
			if i < 0 or j < 0 or i >= img.get_width() or j >= img.get_height():
				continue
			var dx := float(i - cx) / float(rx)
			var dy := float(j - cy) / float(ry)
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(i, j, c)

static func _circle(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	_ellipse(img, cx, cy, r, r, c)

## 反応ラボの入口になる作業台（木のテーブル＋フラスコ＋乳鉢）。
static func make_station() -> Texture2D:
	var img := _new(64, 56)
	var wood := Color(0.55, 0.38, 0.22)
	var wood_hi := Color(0.68, 0.50, 0.30)
	var wood_lo := Color(0.40, 0.27, 0.16)
	var glass := Color(0.78, 0.89, 0.93)
	var glass_hi := Color(0.95, 0.98, 1.0)
	var liquid := Color(0.30, 0.62, 0.36)
	# 脚（先に描いて天板で上端を隠す）。
	_rect(img, 8, 34, 5, 18, wood_lo)
	_rect(img, 51, 34, 5, 18, wood_lo)
	_rect(img, 8, 48, 48, 2, wood_lo)
	# 天板。
	_rect(img, 4, 27, 56, 8, wood)
	_rect(img, 4, 27, 56, 2, wood_hi)
	_rect(img, 4, 33, 56, 2, wood_lo)
	# フラスコ（球底）。
	_rect(img, 29, 7, 6, 3, wood_lo)
	_rect(img, 30, 9, 4, 8, glass)
	_circle(img, 32, 20, 8, glass)
	_ellipse(img, 32, 22, 6, 4, liquid)
	_rect(img, 28, 16, 2, 4, glass_hi)
	# 乳鉢。
	_ellipse(img, 50, 23, 7, 4, GRAY_MID)
	_ellipse(img, 50, 22, 5, 2, GRAY_LOW)
	_rect(img, 48, 14, 2, 8, GRAY_HI)
	return _tex(img)
