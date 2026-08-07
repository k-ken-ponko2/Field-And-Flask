## プレイヤーキャラのテクスチャを供給する（presentation 層）。
##
## ドット絵スプライト（assets/sprites/char_*.png、16×24）を読み込んで返す。
## スプライトは tools/gen_sprites.py で生成する。global class_name は使わず preload 前提。
## 横向きの左右は Sprite2D.flip_h で使い分ける（player.gd 側）。
extends RefCounted

static func make_down() -> Texture2D:
	return load("res://assets/sprites/char_down.png")

static func make_up() -> Texture2D:
	return load("res://assets/sprites/char_up.png")

static func make_side() -> Texture2D:
	return load("res://assets/sprites/char_side.png")
