## シーンを数フレーム描画してスクショを保存する（ソフトウェア描画での確認用）。
## 実行例:
##   SHOT_SCENE=res://presentation/reaction/reaction_lab.tscn SHOT_OUT=/abs/shot.png \
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --script res://tools/screenshot.gd
##
## 環境変数:
##   SHOT_SCENE  撮影するシーン（既定: 反応ラボ）
##   SHOT_OUT    保存先 PNG（既定: user://shot.png）
##   SHOT_ACTION 数フレーム後にシーンのルートで呼ぶメソッド名（例: open_lab）
##   SHOT_FRAMES 撮影までのフレーム数（既定: 15）
extends SceneTree

var _f := 0
var _scene: Node
var _action := ""
var _frames := 15

func _initialize() -> void:
	var scene_path := OS.get_environment("SHOT_SCENE")
	if scene_path == "":
		scene_path = "res://presentation/reaction/reaction_lab.tscn"
	_action = OS.get_environment("SHOT_ACTION")
	var frames_env := OS.get_environment("SHOT_FRAMES")
	if frames_env.is_valid_int():
		_frames = maxi(int(frames_env), 2)
	var ps: PackedScene = load(scene_path)
	if ps != null:
		_scene = ps.instantiate()
		get_root().add_child(_scene)

func _process(_delta: float) -> bool:
	_f += 1
	if _f == 4 and _action != "" and _scene != null and _scene.has_method(_action):
		_scene.call(_action)
	if _f >= _frames:
		var out := OS.get_environment("SHOT_OUT")
		if out == "":
			out = "user://shot.png"
		var img := get_root().get_texture().get_image()
		var err := img.save_png(out)
		print("screenshot save err=%d -> %s (%dx%d)" % [err, out, img.get_width(), img.get_height()])
		quit()
	return false
