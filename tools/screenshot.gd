## シーンを数フレーム描画してスクショを保存する（ソフトウェア描画での確認用）。
## 実行例:
##   SHOT_SCENE=res://presentation/reaction/reaction_lab.tscn SHOT_OUT=/abs/shot.png \
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --script res://tools/screenshot.gd
extends SceneTree

var _f := 0

func _initialize() -> void:
	var scene_path := OS.get_environment("SHOT_SCENE")
	if scene_path == "":
		scene_path = "res://presentation/reaction/reaction_lab.tscn"
	var ps: PackedScene = load(scene_path)
	if ps != null:
		get_root().add_child(ps.instantiate())

func _process(_delta: float) -> bool:
	_f += 1
	if _f >= 15:
		var out := OS.get_environment("SHOT_OUT")
		if out == "":
			out = "user://shot.png"
		var img := get_root().get_texture().get_image()
		var err := img.save_png(out)
		print("screenshot save err=%d -> %s (%dx%d)" % [err, out, img.get_width(), img.get_height()])
		quit()
	return false
