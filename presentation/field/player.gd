## プレイヤーキャラクター（採取マップの操作対象）。
##
## 8方向移動＋移動方向を向く。見た目は CharacterArt が生成する前・後・横の3枚を
## 切り替え、横向きの左右は flip_h で使い分ける。
extends CharacterBody2D

const CharacterArt = preload("res://presentation/field/character_art.gd")

## 移動速度（px/秒）。
@export var speed: float = 220.0

var _frames := {}
var _facing := "down"

@onready var _visual: Sprite2D = $Visual

func _ready() -> void:
	_frames = {
		"down": CharacterArt.make_down(),
		"up": CharacterArt.make_up(),
		"side": CharacterArt.make_side(),
	}
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_visual.scale = Vector2(2.0, 2.0)  # 16x24 のドット絵を等倍拡大（Nearest でくっきり）
	_visual.position = Vector2(0.0, -18.0)
	_apply_facing()

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

	if direction != Vector2.ZERO:
		_facing = _direction_name(direction)
		_apply_facing()

func _direction_name(dir: Vector2) -> String:
	if absf(dir.x) > absf(dir.y):
		return "right" if dir.x > 0.0 else "left"
	return "down" if dir.y > 0.0 else "up"

func _apply_facing() -> void:
	match _facing:
		"left":
			_visual.texture = _frames["side"]
			_visual.flip_h = true
		"right":
			_visual.texture = _frames["side"]
			_visual.flip_h = false
		_:
			_visual.texture = _frames[_facing]
			_visual.flip_h = false
