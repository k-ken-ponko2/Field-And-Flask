## 作業台（presentation 層）。道具を選んで組み合わせる場所。
##
## 右のパレットから道具をドラッグし、左の火の上にドロップして使う:
##   熱源（直火／囲い炉／ふいご炉）… 据える。火の操作はその熱源の UI（FireView の派生）に切り替わる
##   容器（土器／るつぼ）           … 熱源の上に置く。火の温度に追従し、耐熱を超えるとひび
## 状態は core の LabBench。ここはドロップの変換と表示のみ。
##
## 実行: res://presentation/lab/lab_bench.tscn（F6）／ Web: play/?scene=lab_bench
class_name LabBenchScene
extends Control

const HEAT_SOURCES := [
	{"id": "direct_fire", "hint": "クリックで薪を入れる"},
	{"id": "enclosed_fire", "hint": "マウスのスライドであおぐ"},
	{"id": "bellows_forge", "hint": "クリック長押しでふいご"},
]
const VESSELS := [
	{"id": "clay_pot", "hint": "〜900℃。火の上にドロップ"},
	{"id": "crucible", "hint": "〜1400℃。金属を溶かす"},
]
const ICONS := {
	"direct_fire": &"log", "enclosed_fire": &"hearth", "bellows_forge": &"bellows_0",
	"clay_pot": &"pot", "crucible": &"crucible",
}
## 容器を「火の上」と見なすドロップ位置の許容半径（px）。
const DROP_RADIUS := 140.0

var bench := LabBench.new()
var view: FireView
var firecard: PanelContainer
var placeholder: Label
var readout: RichTextLabel
var feedback: Label
var _feedback_timer := 0.0
var _readout_timer := 0.0

func _ready() -> void:
	_build_ui()
	_refresh()

func _process(delta: float) -> void:
	bench.tick(delta)
	if view != null:
		view.vessel = bench.vessel
		view.vessel_temperature = bench.vessel_temperature
		view.vessel_cracked = bench.vessel_cracked
	if _feedback_timer > 0.0:
		_feedback_timer -= delta
		if _feedback_timer <= 0.0:
			feedback.text = ""
	_readout_timer -= delta
	if _readout_timer <= 0.0:
		_readout_timer = 0.15
		_refresh()

# --- ドロップの受け付け ----------------------------------------------------------

func _on_dropped(data: Dictionary, at: Vector2) -> void:
	match data.get("kind"):
		&"heat_source":
			_place_heat_source(data["path"])
		&"vessel":
			_place_vessel(data["path"], at)

func _place_heat_source(path: String) -> void:
	var src: HeatSource = load(path)
	var r := bench.place_heat_source(src, 1.0)
	if not r["ok"]:
		return
	_mount_view(src)
	_say("%s を据えた" % src.display_name, Color(0.8, 0.45, 0.1))

func _place_vessel(path: String, at: Vector2) -> void:
	var def: VesselDef = load(path)
	if bench.fire == null:
		_say("先に熱源を置いてください", Color(0.8, 0.3, 0.2))
		return
	if view != null and at.distance_to(view.vessel_seat()) > DROP_RADIUS:
		_say("火の上に置いてください", Color(0.8, 0.3, 0.2))
		return
	var r := bench.place_vessel(def)
	if r["ok"]:
		_say("%s を火にかけた" % def.display_name, Color(0.8, 0.45, 0.1))

func _remove_vessel() -> void:
	if bench.vessel == null:
		return
	_say("%s を下ろした" % bench.vessel.display_name, Color(0.55, 0.5, 0.42))
	bench.remove_vessel()

## 熱源に合った火の UI に差し替える。
func _mount_view(src: HeatSource) -> void:
	if view != null:
		view.queue_free()
	match src.input_mode:
		HeatSource.InputMode.FAN_SLIDE:
			view = FanFireView.new()
		HeatSource.InputMode.BELLOWS_HOLD:
			view = BellowsFireView.new()
		_:
			view = DirectFireView.new()
	view.accepts_drops = true
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.item_dropped.connect(_on_dropped)
	view.fed.connect(func(timing: StringName): _say({&"good": "いい頃合い！", &"early": "早すぎた… 窒息", &"late": "点け直し…"}.get(timing, ""), Color(0.8, 0.45, 0.1)))
	firecard.add_child(view)
	view.setup(bench.fire)
	placeholder.visible = false

func _say(text: String, color: Color) -> void:
	feedback.text = text
	feedback.add_theme_color_override("font_color", color)
	_feedback_timer = 2.0

# --- UI ------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		outer.add_theme_constant_override(m, 18)
	add_child(outer)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	outer.add_child(root)

	# 左：作業台（火の UI が載る）。熱源が無い間はドロップ先の案内だけ。
	firecard = PanelContainer.new()
	firecard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	firecard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(firecard)
	var empty := DropTarget.new()
	empty.item_dropped.connect(_on_dropped)
	empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	firecard.add_child(empty)
	placeholder = Label.new()
	placeholder.text = "右の「熱源」をここへドラッグして据える"
	placeholder.add_theme_font_size_override("font_size", 18)
	placeholder.add_theme_color_override("font_color", Color(0.8, 0.72, 0.6))
	placeholder.set_anchors_preset(Control.PRESET_CENTER)
	placeholder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	placeholder.grow_vertical = Control.GROW_DIRECTION_BOTH
	empty.add_child(placeholder)

	# 右：パレット。
	var concard := PanelContainer.new()
	concard.custom_minimum_size = Vector2(360, 0)
	root.add_child(concard)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 8)
	concard.add_child(panel)
	var title := Label.new()
	title.text = "作業台 — 道具を置いて使う（仮）"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.541, 0.353, 0.086))
	panel.add_child(title)
	var note := Label.new()
	note.text = "道具を左へドラッグ＆ドロップ。熱源→容器の順に重ねる。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(note)

	panel.add_child(_section("熱源（据える）"))
	for h in HEAT_SOURCES:
		var src: HeatSource = load("res://data/heat/%s.tres" % h["id"])
		panel.add_child(_item(&"heat_source", src.id, "res://data/heat/%s.tres" % h["id"], "%s — 天井 %d℃" % [src.display_name, int(src.max_temperature)], h["hint"]))
	panel.add_child(_section("容器（火の上に置く）"))
	for v in VESSELS:
		var def: VesselDef = load("res://data/heat/%s.tres" % v["id"])
		panel.add_child(_item(&"vessel", def.id, "res://data/heat/%s.tres" % v["id"], "%s — 耐熱 %d℃" % [def.display_name, int(def.max_temperature)], v["hint"]))

	feedback = Label.new()
	feedback.add_theme_font_size_override("font_size", 16)
	panel.add_child(feedback)
	panel.add_child(_section("状態"))
	readout = RichTextLabel.new()
	readout.bbcode_enabled = true
	readout.fit_content = true
	readout.scroll_active = false
	readout.add_theme_color_override("default_color", Color(0.2, 0.19, 0.16))
	panel.add_child(readout)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_btn("容器を下ろす", _remove_vessel))
	row.add_child(_btn("燃料を補充", func(): if bench.fire != null: bench.fire.fuel = 1.0))
	panel.add_child(row)

func _item(kind: StringName, id: StringName, path: String, label: String, hint: String) -> PaletteItem:
	var it := PaletteItem.new()
	it.setup(kind, id, path, FireView.TEX[ICONS[String(id)]], label, hint)
	return it

func _refresh() -> void:
	var lines: Array[String] = []
	if bench.fire == null:
		lines.append(_kv("熱源", "なし"))
	else:
		var f := bench.fire
		lines.append(_kv("熱源", "%s（天井 %d℃）" % [f.source.display_name, int(f.source.max_temperature)]))
		lines.append(_kv("温度", "%d℃" % int(round(f.temperature))))
		lines.append(_kv("火勢 / 燃料", "%d%% / %d%%%s" % [int(round(f.drive * 100.0)), int(round(f.fuel * 100.0)), "（消えている）" if f.is_out() else ""]))
	if bench.vessel == null:
		lines.append(_kv("容器", "なし"))
	else:
		var state := "ひびが入った" if bench.vessel_cracked else "%d℃" % int(round(bench.vessel_temperature))
		lines.append(_kv("容器", "%s（耐熱 %d℃）: %s" % [bench.vessel.display_name, int(bench.vessel.max_temperature), state]))
	lines.append(_kv("記録", "%d 手" % bench.log.size()))
	readout.text = "\n".join(lines)

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.55, 0.5, 0.42))
	return l

func _btn(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	return b

func _kv(label: String, value: String) -> String:
	return "[color=#8c8070]%s[/color]  %s" % [label, value]
