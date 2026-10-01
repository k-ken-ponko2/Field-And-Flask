## プレイヤーキャラのテクスチャを供給する（presentation 層）。
##
## ドット絵スプライト（assets/sprites/char_*.png、18×30）を読み込んで返す。
## スプライトは tools/gen_character.py が部位の組み立てで生成する。
## 方向は "down" / "up" / "side"（右向き。左向きは player.gd 側で flip_h）。
## global class_name は使わず preload 前提。
extends RefCounted

const SPRITE_DIR := "res://assets/sprites/"
const FRAME_COUNT := 4

## 歩行サイクル 4 フレーム（0=待機/接地, 1=左足前, 2=通過, 3=右足前）。
static func frames(direction: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in FRAME_COUNT:
		out.append(load(SPRITE_DIR + "char_%s_%d.png" % [direction, i]))
	return out

## まばたき（目を閉じた待機）。目が見えない上向きには無い。
static func blink(direction: String) -> Texture2D:
	if direction == "up":
		return null
	return load(SPRITE_DIR + "char_%s_blink.png" % direction)
