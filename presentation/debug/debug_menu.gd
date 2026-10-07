## デバッグメニュー（presentation 層）。Web ビルドの入口。
##
## 各シーン（フィールド／反応マップ／火ラボ3段階）を一覧から開き、左上の「← メニュー」で戻れる。
## ブラウザでは URL の ?scene=<id> で直接シーンを開ける（debug ページからのリンク用）。
## 例: play/?scene=fire_lab_fan
class_name DebugMenu
extends Node

const SCENES := [
	{"id": "lab_bench", "label": "作業台（道具をドラッグ＆ドロップ）", "path": "res://presentation/lab/lab_bench.tscn"},
	{"id": "fire_lab_direct", "label": "火ラボ ① 直火（クリックで薪）", "path": "res://presentation/heat/fire_lab_direct.tscn"},
	{"id": "fire_lab_fan", "label": "火ラボ ② 囲い炉（スライドであおぐ）", "path": "res://presentation/heat/fire_lab_fan.tscn"},
	{"id": "fire_lab_bellows", "label": "火ラボ ③ ふいご炉（長押し）", "path": "res://presentation/heat/fire_lab_bellows.tscn"},
	{"id": "fire_lab", "label": "火ラボ（3段階を切り替え）", "path": "res://presentation/heat/fire_lab.tscn"},
	{"id": "reaction_lab", "label": "反応マップ（温度×濃度 / pH）", "path": "res://presentation/reaction/reaction_lab.tscn"},
	{"id": "field", "label": "採取マップ（WASD で移動）", "path": "res://presentation/field/field.tscn"},
]

var _ui: CanvasLayer
var _menu: Control
var _back: Button
var _current: Node

func _ready() -> void:
	_build_ui()
	var wanted := _scene_from_url()
	if wanted != "":
		_open(wanted)

## ブラウザの ?scene= を読む（Web 以外は空）。
func _scene_from_url() -> String:
	if not OS.has_feature("web"):
		return ""
	var v = JavaScriptBridge.eval("new URLSearchParams(location.search).get('scene') || ''")
	return str(v) if v != null else ""

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 100
	add_child(_ui)

	_menu = PanelContainer.new()
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_ui.add_child(_menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(420, 0)
	_menu.add_child(box)
	var title := Label.new()
	title.text = "Field & Flask — デバッグメニュー"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.541, 0.353, 0.086))
	box.add_child(title)
	var note := Label.new()
	note.text = "シーンを選ぶと開きます。左上の「← メニュー」で戻れます。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	for s in SCENES:
		var b := Button.new()
		b.text = s["label"]
		b.pressed.connect(_open.bind(s["id"]))
		box.add_child(b)

	_back = Button.new()
	_back.text = "← メニュー"
	_back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_back.position = Vector2(8, 8)
	_back.visible = false
	_back.pressed.connect(_close)
	_ui.add_child(_back)

func _find(id: String) -> Dictionary:
	for s in SCENES:
		if s["id"] == id:
			return s
	return {}

func _open(id: String) -> void:
	var entry := _find(id)
	if entry.is_empty():
		return
	_close()
	var ps: PackedScene = load(entry["path"])
	if ps == null:
		return
	_current = ps.instantiate()
	add_child(_current)
	_menu.visible = false
	_back.visible = true

func _close() -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	_menu.visible = true
	_back.visible = false
