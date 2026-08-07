## プレイヤーキャラクター（採取マップの操作対象）。
##
## 8方向移動＋移動方向を向く。見た目は前・後・横の idle/walk 2フレームを持ち、
## 移動中は idle↔walk を切り替え＋上下の弾み(bob)で歩いて見せる。
## 横向きの左右は flip_h で使い分ける。
extends CharacterBody2D

const CharacterArt = preload("res://presentation/field/character_art.gd")

## 移動速度（px/秒）。
@export var speed: float = 220.0
## 歩行アニメの速さ（1秒あたりのフレーム切替回数）。
@export var step_rate: float = 7.0
## スプライトの基準 Y オフセット（足元を体の中心付近に置く）。
const BASE_Y := -18.0

var _frames := {}
var _facing := "down"
var _anim_t := 0.0
var _moving := false

@onready var _visual: Sprite2D = $Visual

func _ready() -> void:
	_frames = {
		"down": {"idle": CharacterArt.make_down(), "walk": CharacterArt.make_down_walk()},
		"up": {"idle": CharacterArt.make_up(), "walk": CharacterArt.make_up_walk()},
		"side": {"idle": CharacterArt.make_side(), "walk": CharacterArt.make_side_walk()},
	}
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_visual.scale = Vector2(2.0, 2.0)
	_apply()

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

	_moving = direction != Vector2.ZERO
	if _moving:
		_facing = _direction_name(direction)
		_anim_t += delta
	else:
		_anim_t = 0.0
	_apply()

func _direction_name(dir: Vector2) -> String:
	if absf(dir.x) > absf(dir.y):
		return "right" if dir.x > 0.0 else "left"
	return "down" if dir.y > 0.0 else "up"

func _apply() -> void:
	var base := _facing
	var flip := false
	if _facing == "left":
		base = "side"
		flip = true
	elif _facing == "right":
		base = "side"

	var set: Dictionary = _frames[base]
	var tex: Texture2D = set["idle"]
	var bob := 0.0
	if _moving and int(_anim_t * step_rate) % 2 == 1:
		tex = set["walk"]
		bob = -2.0

	_visual.texture = tex
	_visual.flip_h = flip
	_visual.position = Vector2(0.0, BASE_Y + bob)
