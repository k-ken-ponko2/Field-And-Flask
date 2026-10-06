## 火ラボ（presentation 層の仮UI）。`docs/design/heat-tiers.md` §6。
##
## 熱源 3 段階を切り替え、それぞれの操作で火力を上げて温度を見る:
##   ① 直火        … タイミングよく薪を入れる（クリック）
##   ② 囲い炉      … あおぐ（マウスのスライド）
##   ③ ふいご炉    … ふいごを押し続ける（クリック長押し）
## 段階ごとに UI（FireView の派生）を差し替える。ロジックは core（FireSim / HeatSource）。
##
## 実行: res://presentation/heat/fire_lab.tscn を開いて実行（F6）。
##       fire_lab_direct / fire_lab_fan / fire_lab_bellows.tscn は各段階を最初から開く。
class_name FireLab
extends Control

## 起動時に選ぶ段階（0=直火, 1=囲い炉, 2=ふいご炉）。
@export var initial_tier: int = 0

const SOURCE_IDS := ["direct_fire", "enclosed_fire", "bellows_forge"]
const HINTS := {
	HeatSource.InputMode.FEED_TIMING: "火の上をクリックして薪を入れる。燃料ゲージが橙の帯（熾火）に入ったときが好機。",
	HeatSource.InputMode.FAN_SLIDE: "火の上でマウスを左右に動かしてあおぐ。手を止めると火勢が落ちる。",
	HeatSource.InputMode.BELLOWS_HOLD: "火の上でクリックを押し続けてふいごを踏む。短い押下では弱い。",
}
## 到達目標の温度帯（仮）。どのティアで届くかを示す。
const GOALS := [
	{"label": "乾燥・燻製", "low": 150.0, "high": 350.0},
	{"label": "素焼き土器", "low": 700.0, "high": 900.0},
	{"label": "青銅溶解", "low": 1000.0, "high": 1200.0},
]

var sources: Array[HeatSource] = []
var sim: FireSim
var view: FireView
var firecard: PanelContainer
var readout: RichTextLabel
var hint: Label
var feedback: Label
var _feedback_timer := 0.0
var _readout_timer := 0.0
var _tier_buttons: Array[Button] = []

## 読み出しの更新間隔（秒）。毎フレーム文字列を組み直さない。
const READOUT_INTERVAL := 0.15

func _ready() -> void:
	for id in SOURCE_IDS:
		var h: HeatSource = load("res://data/heat/%s.tres" % id)
		if h != null:
			sources.append(h)
	_build_ui()
	_select(clampi(initial_tier, 0, sources.size() - 1))

## 段階の操作に合った UI を作る。
func _make_view(mode: HeatSource.InputMode) -> FireView:
	match mode:
		HeatSource.InputMode.FAN_SLIDE:
			return FanFireView.new()
		HeatSource.InputMode.BELLOWS_HOLD:
			return BellowsFireView.new()
		_:
			return DirectFireView.new()

func _select(index: int) -> void:
	var source := sources[index]
	sim = FireSim.new(source, 0.6)
	if view != null:
		view.queue_free()
	view = _make_view(source.input_mode)
	view.custom_minimum_size = Vector2(440, 440)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.fed.connect(_on_fed)
	firecard.add_child(view)
	view.setup(sim)
	hint.text = HINTS.get(source.input_mode, "")
	for i in _tier_buttons.size():
		_tier_buttons[i].button_pressed = i == index
	_refresh()

func _process(delta: float) -> void:
	if sim == null:
		return
	sim.tick(delta)
	if _feedback_timer > 0.0:
		_feedback_timer -= delta
		if _feedback_timer <= 0.0:
			feedback.text = ""
	_readout_timer -= delta
	if _readout_timer <= 0.0:
		_readout_timer = READOUT_INTERVAL
		_refresh()

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

	firecard = PanelContainer.new()
	firecard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	firecard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(firecard)

	var concard := PanelContainer.new()
	concard.custom_minimum_size = Vector2(360, 0)
	root.add_child(concard)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 8)
	concard.add_child(panel)

	var title := Label.new()
	title.text = "火ラボ — 熱源の3段階（仮）"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.541, 0.353, 0.086))
	panel.add_child(title)

	panel.add_child(_section("熱源"))
	for i in sources.size():
		var s := sources[i]
		var b := Button.new()
		b.toggle_mode = true
		b.text = "%d. %s — 天井 %d℃" % [s.tier, s.display_name, int(s.max_temperature)]
		b.pressed.connect(_select.bind(i))
		_tier_buttons.append(b)
		panel.add_child(b)

	panel.add_child(_section("操作"))
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(hint)
	feedback = Label.new()
	feedback.add_theme_font_size_override("font_size", 18)
	feedback.add_theme_color_override("font_color", Color(0.8, 0.45, 0.1))
	panel.add_child(feedback)

	panel.add_child(_section("状態"))
	readout = RichTextLabel.new()
	readout.bbcode_enabled = true
	readout.fit_content = true
	readout.scroll_active = false
	readout.add_theme_color_override("default_color", Color(0.2, 0.19, 0.16))
	panel.add_child(readout)

	panel.add_child(_row([_btn("燃料を補充", func(): sim.fuel = 1.0), _btn("やり直す", func(): _select(_current_index()))]))

func _current_index() -> int:
	for i in sources.size():
		if sources[i] == sim.source:
			return i
	return 0

func _on_fed(timing: StringName) -> void:
	feedback.text = {&"good": "いい頃合い！ 火勢が上がった", &"early": "早すぎた… 火が窒息した", &"late": "消えていた… 点け直し"}.get(timing, "")
	_feedback_timer = 1.6

func _refresh() -> void:
	if readout == null or sim == null:
		return
	var lines: Array[String] = []
	lines.append(_kv("温度", "%d℃ / 天井 %d℃" % [int(round(sim.temperature)), int(sim.source.max_temperature)]))
	lines.append(_kv("火勢", "%d%%" % int(round(sim.drive * 100.0))))
	lines.append(_kv("燃料", "%d%%%s" % [int(round(sim.fuel * 100.0)), "（消えている）" if sim.is_out() else ""]))
	lines.append(_kv("操作", "%d 回" % sim.operations.size()))
	lines.append("")
	for g in GOALS:
		var reachable: bool = g["low"] <= sim.source.max_temperature
		var mark := "●" if sim.in_band(g["low"], g["high"]) else ("○" if reachable else "✕")
		var note := "" if reachable else "（届かない）"
		lines.append("%s %s  %d〜%d℃%s" % [mark, g["label"], int(g["low"]), int(g["high"]), note])
	lines.append("[color=#8c8070]● 温度帯の中 ／ ○ 届く ／ ✕ 届かない[/color]")
	readout.text = "\n".join(lines)

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.55, 0.5, 0.42))
	return l

func _row(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for b in buttons:
		row.add_child(b)
	return row

func _btn(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	return b

func _kv(label: String, value: String) -> String:
	return "[color=#8c8070]%s[/color]  %s" % [label, value]
