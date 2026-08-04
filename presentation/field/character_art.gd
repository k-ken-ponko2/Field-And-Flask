## プレイヤーキャラのテクスチャをコードで生成する（presentation 層）。
##
## 素材なしで「小さな人型」を手続き生成。前(down)・後(up)・横(side) の3枚を作り、
## 横向きの左右は Sprite2D.flip_h で使い分ける。global class_name は使わず preload 前提。
extends RefCounted

const W := 28
const H := 40

const SKIN := Color(0.98, 0.80, 0.62)
const SKIN_SH := Color(0.88, 0.68, 0.50)
const HAIR := Color(0.34, 0.22, 0.13)
const HAIR_HI := Color(0.45, 0.31, 0.19)
const SHIRT := Color(0.28, 0.55, 0.74)
const SHIRT_SH := Color(0.22, 0.45, 0.62)
const PANTS := Color(0.30, 0.28, 0.34)
const BOOT := Color(0.24, 0.17, 0.12)
const EYE := Color(0.14, 0.12, 0.16)

## 体（胴・腕・脚・靴）— 3方向で共通。
static func _body(img: Image) -> void:
	# 靴
	_rect(img, 8, 35, 5, 4, BOOT)
	_rect(img, 15, 35, 5, 4, BOOT)
	# 脚（ズボン、中央にすき間で2本に見せる）
	_rect(img, 8, 28, 5, 8, PANTS)
	_rect(img, 15, 28, 5, 8, PANTS)
	# 胴（シャツ）＋右側の陰
	_rect(img, 7, 18, 14, 12, SHIRT)
	_rect(img, 16, 18, 5, 12, SHIRT_SH)
	# 袖と手
	_rect(img, 4, 19, 4, 9, SHIRT)
	_rect(img, 20, 19, 4, 9, SHIRT_SH)
	_rect(img, 4, 27, 4, 3, SKIN)
	_rect(img, 20, 27, 4, 3, SKIN)

static func make_down() -> Texture2D:
	var img := _new(W, H)
	_body(img)
	_circle(img, 14, 12, 8, SKIN)          # 顔
	_circle_top(img, 14, 12, 8, HAIR, 9)   # 前髪（上部）
	_rect(img, 7, 11, 2, 4, HAIR)          # もみあげ
	_rect(img, 19, 11, 2, 4, HAIR)
	_rect(img, 11, 13, 2, 2, EYE)          # 目
	_rect(img, 17, 13, 2, 2, EYE)
	_rect(img, 13, 16, 3, 1, SKIN_SH)      # 口
	return _tex(img)

static func make_up() -> Texture2D:
	var img := _new(W, H)
	_body(img)
	_rect(img, 12, 17, 4, 2, SKIN)         # うなじ
	_circle(img, 14, 12, 8, HAIR)          # 後頭部（全部髪）
	_circle_top(img, 14, 11, 8, HAIR_HI, 8)
	return _tex(img)

static func make_side() -> Texture2D:
	# 右向きプロファイル（左向きは flip_h）
	var img := _new(W, H)
	_body(img)
	# 頭：中心(15,11) r8。上と後ろ(左)が髪、前(右)が顔。
	var cx := 15
	var cy := 11
	var r := 8
	for j in range(cy - r, cy + r + 1):
		for i in range(cx - r, cx + r + 1):
			var dx := i - cx
			var dy := j - cy
			if dx * dx + dy * dy > r * r:
				continue
			if j <= cy - 2 or i <= cx:
				img.set_pixel(i, j, HAIR)
			else:
				img.set_pixel(i, j, SKIN)
	_rect(img, 18, 12, 2, 2, EYE)          # 前寄りの目
	_rect(img, 22, 12, 1, 2, SKIN_SH)      # 鼻先
	return _tex(img)

# --- 低レベルヘルパ ---------------------------------------------------------

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

static func _circle(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for j in range(cy - r, cy + r + 1):
		for i in range(cx - r, cx + r + 1):
			if i < 0 or j < 0 or i >= img.get_width() or j >= img.get_height():
				continue
			var dx := i - cx
			var dy := j - cy
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(i, j, c)

## 円のうち j <= max_y の部分だけ塗る（髪の生え際などに使う）。
static func _circle_top(img: Image, cx: int, cy: int, r: int, c: Color, max_y: int) -> void:
	for j in range(cy - r, min(cy + r + 1, max_y + 1)):
		for i in range(cx - r, cx + r + 1):
			if i < 0 or j < 0 or i >= img.get_width() or j >= img.get_height():
				continue
			var dx := i - cx
			var dy := j - cy
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(i, j, c)
