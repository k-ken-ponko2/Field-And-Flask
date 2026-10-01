## プレイヤーキャラクター（採取マップの操作対象）。
##
## 8方向移動＋移動方向を向く。見た目は前・後・横の 4 フレーム歩行サイクル
## （tools/gen_character.py が生成。接地フレームでは上半身の弾みをスプライト側に焼いてある）。
## 待機中は呼吸の上下とまばたき、歩行中は足元に土煙を出す。
## 横向きの左右は flip_h で使い分ける。
extends CharacterBody2D

const CharacterArt = preload("res://presentation/field/character_art.gd")

## 移動速度（px/秒）。
@export var speed: float = 220.0
## 歩行アニメの速さ（1秒あたりのフレーム数）。
@export var step_rate: float = 8.0
## スプライトの基準 Y オフセット（足元を当たり判定の少し下に置く）。
const BASE_Y := -24.0
## 呼吸: 周期と、持ち上がっている時間（秒）。
const BREATH_PERIOD := 2.4
const BREATH_UP := 0.6
## まばたき: 間隔の範囲と長さ（秒）。
const BLINK_MIN := 2.5
const BLINK_MAX := 5.5
const BLINK_LENGTH := 0.12

var _frames := {}
var _blinks := {}
var _facing := "down"
var _anim_t := 0.0
var _idle_t := 0.0
var _blink_in := 3.0
var _blink_left := 0.0
var _moving := false
var _dust: CPUParticles2D

@onready var _visual: Sprite2D = $Visual

func _ready() -> void:
	for dir in ["down", "up", "side"]:
		_frames[dir] = CharacterArt.frames(dir)
		_blinks[dir] = CharacterArt.blink(dir)
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_visual.scale = Vector2(2.0, 2.0)
	_build_dust()
	_apply()

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

	_moving = direction != Vector2.ZERO
	if _moving:
		_facing = _direction_name(direction)
		_anim_t += delta
		_idle_t = 0.0
	else:
		_anim_t = 0.0
		_idle_t += delta
	_tick_blink(delta)
	_dust.emitting = _moving
	_apply()

func _direction_name(dir: Vector2) -> String:
	if absf(dir.x) > absf(dir.y):
		return "right" if dir.x > 0.0 else "left"
	return "down" if dir.y > 0.0 else "up"

func _tick_blink(delta: float) -> void:
	if _blink_left > 0.0:
		_blink_left -= delta
		return
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink_left = BLINK_LENGTH
		_blink_in = randf_range(BLINK_MIN, BLINK_MAX)

func _apply() -> void:
	var base := _facing
	var flip := false
	if _facing == "left":
		base = "side"
		flip = true
	elif _facing == "right":
		base = "side"

	var set: Array = _frames[base]
	var tex: Texture2D = set[0]
	var breath := 0.0
	if _moving:
		tex = set[int(_anim_t * step_rate) % set.size()]
	else:
		if fmod(_idle_t, BREATH_PERIOD) < BREATH_UP:
			breath = -1.0
		var blink: Texture2D = _blinks[base]
		if _blink_left > 0.0 and blink != null:
			tex = blink

	_visual.texture = tex
	_visual.flip_h = flip
	_visual.position = Vector2(0.0, BASE_Y + breath)

## 歩行中の土煙。足元から小さな粒を出す。
func _build_dust() -> void:
	_dust = CPUParticles2D.new()
	_dust.emitting = false
	_dust.amount = 8
	_dust.lifetime = 0.45
	_dust.local_coords = false
	_dust.position = Vector2(0.0, 6.0)
	_dust.z_index = -1
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_dust.texture = ImageTexture.create_from_image(img)
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_dust.emission_sphere_radius = 5.0
	_dust.direction = Vector2(0.0, -1.0)
	_dust.spread = 70.0
	_dust.gravity = Vector2(0.0, 12.0)
	_dust.initial_velocity_min = 8.0
	_dust.initial_velocity_max = 18.0
	_dust.scale_amount_min = 1.0
	_dust.scale_amount_max = 2.0
	_dust.color = Color(0.80, 0.70, 0.54)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.0)])
	_dust.color_ramp = ramp
	add_child(_dust)
