## 錬金ラボ（ポーションクラフト寄せの実験室）。配線と表示のみ、ロジックは core。
##
##   左: 羊皮紙の反応マップ（AlchemyMapView）
##   右上: 大釜ステーション（CauldronStation）… 炎の上の大釜と掛けてある道具
##   右下: 素材棚（ShelfItem）… 素材は釜へ、熱源は火へドラッグ
## 流れ: 素材を釜へドラッグ（かざすと点線の予告）→ かき混ぜ棒で回して経路を進む → ひしゃく/蒸留器で濃度 →
##       熱源の操作で温度（釜の温度がそのまま縦軸）→ 目標領域で瓶をかざして瓶詰め → ノートに記録。
##
## 実行: res://presentation/lab/alchemy_lab.tscn（F6）／ Web: play/?scene=alchemy_lab
class_name AlchemyLab
extends Control

const START := Vector2(2.0, 0.0)
const MATERIALS := ["vitriol", "lime", "water", "sulfur"]
const HEAT_SOURCES := ["direct_fire", "enclosed_fire", "bellows_forge"]
const ICONS := {
	"vitriol": &"ing_vitriol", "lime": &"ing_lime", "water": &"ing_water", "sulfur": &"ing_sulfur",
	"direct_fire": &"log", "enclosed_fire": &"hearth", "bellows_forge": &"bellows_0",
}

var map: ReactionMap
var materials: Dictionary = {}
var sim: ReactionSim
var bench := LabBench.new()
var notes: Array[ReactionNote] = []

var map_view: AlchemyMapView
var station: CauldronStation
var toast: Label
var notebook: RichTextLabel
var _toast_timer := 0.0

func _ready() -> void:
	map = load("res://data/reactions/acid_base_map.tres")
	for id in MATERIALS:
		var m: MaterialDef = load("res://data/materials/%s.tres" % id)
		if m != null:
			materials[m.id] = m
	_build_ui()
	# ポーションクラフト同様、最初から火と釜は据えてある。
	bench.place_heat_source(load("res://data/heat/direct_fire.tres"), 1.0)
	bench.place_vessel(load("res://data/heat/cauldron.tres"))
	_new_batch()

func _new_batch() -> void:
	sim = ReactionSim.new(map, START)
	if bench.fire != null:
		sim.set_heat_source(bench.fire.source)
	map_view.setup(sim)
	station.sim = sim
	_refresh_notebook()

func _process(delta: float) -> void:
	bench.tick(delta)
	if bench.vessel != null and not sim.batch_lost:
		# 釜の温度がそのまま縦軸。
		var target_y := map.temperature_to_y(bench.vessel_temperature)
		var dy := target_y - sim.position.y
		if absf(dy) > 0.002:
			sim.heat(dy)
	if bench.vessel_cracked and not sim.batch_lost:
		sim.batch_lost = true
		_say("釜にひびが入った… 中身は失われた", Color(0.9, 0.5, 0.4))
	station.liquid_color = LabAssets.litmus(sim.ph()) if not sim.batch_lost else Color(0.3, 0.1, 0.1)
	map_view.heat_ceiling_celsius = bench.fire.source.max_temperature if bench.fire != null else 0.0
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			toast.text = ""

# --- ステーションからの操作 ----------------------------------------------------------

func _on_stirred(distance: float) -> void:
	if sim.batch_lost:
		return
	var y_before := sim.position.y
	sim.stir(distance)
	# 素材の縦成分＝反応熱。釜の温度に押し上げ（下げ）として入れ、あとは火の温度へ戻っていく。
	var dy := sim.position.y - y_before
	if absf(dy) > 0.0001 and bench.vessel != null:
		bench.vessel_temperature = map.y_to_temperature(sim.position.y)
	_check_hazard()

func _on_watering(dt: float) -> void:
	if sim.batch_lost:
		return
	sim.add_water(CauldronStation.WATER_RATE * dt)
	_check_hazard()

func _on_distilling(dt: float) -> void:
	if sim.batch_lost:
		return
	sim.distill(CauldronStation.DISTILL_RATE * dt)
	_check_hazard()

func _check_hazard() -> void:
	if sim.batch_lost and _toast_timer <= 0.0:
		_say("暴走！ バッチは全損。「新しいバッチ」でやり直す", Color(0.9, 0.4, 0.3))

func _on_bottle() -> void:
	var tgt := sim.reached_target()
	if sim.batch_lost:
		_say("暴走したバッチは瓶に詰められない", Color(0.9, 0.5, 0.4))
		return
	if tgt == null:
		_say("まだ何にもなっていない（目標の領域と pH を満たしていない）", Color(0.95, 0.85, 0.6))
		return
	var note := sim.to_note()
	notes.append(note)
	_say("%s を瓶詰め — 収率 %d%% / 純度目安 %.2f。ノートに記録した" % [tgt.label, int(round(note.recorded_yield * 100.0)), note.base_purity], Color(0.95, 0.85, 0.5))
	_new_batch()

func _on_dropped(data: Dictionary) -> void:
	match data.get("kind"):
		&"material":
			if sim.batch_lost:
				_say("暴走したバッチには入れられない", Color(0.9, 0.5, 0.4))
				return
			var m: MaterialDef = load(data["path"])
			sim.queue_material(m)
			_say("%s を入れた。かき混ぜ棒で回すと経路を進む" % m.display_name, Color(0.95, 0.85, 0.6))
		&"heat_source":
			var src: HeatSource = load(data["path"])
			bench.place_heat_source(src, 1.0)
			sim.set_heat_source(src)
			_say("%s を据えた（天井 %d℃）" % [src.display_name, int(src.max_temperature)], Color(0.95, 0.85, 0.6))

func _on_hover(m: MaterialDef) -> void:
	map_view.hover_material = m

func _on_fed(timing: StringName) -> void:
	_say({&"good": "いい頃合い！ 火勢が上がった", &"early": "早すぎた… 火が窒息した", &"late": "消えていた… 点け直し"}.get(timing, ""), Color(0.95, 0.85, 0.6))

func _say(text: String, color: Color) -> void:
	toast.text = text
	toast.add_theme_color_override("font_color", color)
	_toast_timer = 2.5

# --- UI -------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.11, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	map_view = AlchemyMapView.new()
	map_view.position = Vector2(20, 20)
	map_view.size = Vector2(720, 636)
	add_child(map_view)

	station = CauldronStation.new()
	station.position = Vector2(760, 20)
	station.size = Vector2(500, 392)
	station.bench = bench
	station.stirred.connect(_on_stirred)
	station.watering.connect(_on_watering)
	station.distilling.connect(_on_distilling)
	station.bottle_requested.connect(_on_bottle)
	station.item_dropped.connect(_on_dropped)
	station.hover_changed.connect(_on_hover)
	station.fed.connect(_on_fed)
	add_child(station)

	# 素材棚
	var shelf := ShelfPanel.new()
	shelf.position = Vector2(760, 440)
	shelf.size = Vector2(500, 260)
	add_child(shelf)
	var row1 := HBoxContainer.new()
	row1.position = Vector2(8, 4)
	row1.add_theme_constant_override("separation", 4)
	shelf.add_child(row1)
	for id in MATERIALS:
		var m: MaterialDef = materials.get(StringName(id))
		if m == null:
			continue
		var it := ShelfItem.new()
		it.setup(&"material", m.id, "res://data/materials/%s.tres" % id, LabAssets.TEX[ICONS[id]], m.display_name)
		row1.add_child(it)
	var row2 := HBoxContainer.new()
	row2.position = Vector2(8, 132)
	row2.add_theme_constant_override("separation", 4)
	shelf.add_child(row2)
	for id in HEAT_SOURCES:
		var h: HeatSource = load("res://data/heat/%s.tres" % id)
		var it := ShelfItem.new()
		it.setup(&"heat_source", h.id, "res://data/heat/%s.tres" % id, LabAssets.TEX[ICONS[id]], h.display_name)
		row2.add_child(it)
	var btns := VBoxContainer.new()
	btns.position = Vector2(372, 150)
	btns.add_theme_constant_override("separation", 6)
	shelf.add_child(btns)
	btns.add_child(_btn("新しいバッチ", func(): _new_batch(); _say("釜を空にした", Color(0.95, 0.85, 0.6))))
	btns.add_child(_btn("燃料を補充", func(): if bench.fire != null: bench.fire.fuel = 1.0))

	toast = Label.new()
	toast.position = Vector2(764, 414)
	toast.size = Vector2(496, 24)
	toast.add_theme_font_size_override("font_size", 14)
	toast.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	add_child(toast)

	notebook = RichTextLabel.new()
	notebook.bbcode_enabled = true
	notebook.scroll_active = false
	notebook.fit_content = true
	notebook.position = Vector2(28, 664)
	notebook.size = Vector2(712, 36)
	notebook.add_theme_font_size_override("normal_font_size", 12)
	notebook.add_theme_color_override("default_color", Color(0.93, 0.86, 0.72))
	add_child(notebook)

func _refresh_notebook() -> void:
	if notes.is_empty():
		notebook.text = "[color=#b8a98a]ノート: まだ記録がない。目標に着いたら瓶を釜にかざして瓶詰めする。[/color]"
		return
	var parts: Array[String] = []
	for n in notes:
		parts.append("%s（収率 %d%%）" % [n.product_id, int(round(n.recorded_yield * 100.0))])
	notebook.text = "ノート: " + " ／ ".join(parts)

func _btn(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	return b
