## プレイヤーキャラクター（採取マップ上の操作対象）。
##
## 8方向のトップダウン移動。入力アクション move_left/right/up/down（WASD＋矢印）は
## project.godot の入力マップに定義してある。
extends CharacterBody2D

## 移動速度（px/秒）。
@export var speed: float = 220.0

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

	# 進行方向に体を向ける（プレースホルダの三角が向く）。
	if direction != Vector2.ZERO:
		$Visual.rotation = direction.angle() + PI / 2.0
