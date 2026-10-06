## core/ の純粋ロジックを UI 起動なしで検証するヘッドレステストランナー（設計書 §8）。
##
## 実行:
##   godot --headless --path . --script res://core/__tests__/run_tests.gd
##
## 外部テストフレームワークは使わず、core/ が公開する global class_name を直接使う。
## （事前に一度エディタでプロジェクトをインポートしておくと class_name が登録される）
## 全テストが通れば終了コード 0、1件でも失敗すれば 1 を返す（CI 連携用）。
extends SceneTree

var _passed := 0
var _failed := 0

func _initialize() -> void:
	_test_purity()
	_test_reaction()
	_test_ph()
	_test_reaction_hazards()
	_test_acid_base_scenario()
	_test_reaction_note()
	_test_recipe_resolver()
	_test_recipe_data()
	_test_workbench()
	_test_fire_sim()
	_test_heat_ceiling()
	_test_heat_data()
	_test_calendar()
	print("========================================")
	print("Field & Flask core tests: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)

func _ok(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("  ✗ FAIL: " + msg)

# --- 純度 -------------------------------------------------------------------

func _test_purity() -> void:
	var a := Substance.new()
	a.amount = 100.0
	a.purity = 0.6
	var b := Substance.new()
	b.amount = 100.0
	b.purity = 1.0
	var mix := Purity.blend([a, b])
	_ok(is_equal_approx(mix["amount"], 200.0), "混合の合計量は保存される")
	_ok(is_equal_approx(mix["purity"], 0.8), "混合純度は質量保存で 0.8")

	var refined := Purity.refine(200.0, 0.8, 0.98, 0.5)
	_ok(is_equal_approx(refined["purity"], 0.98), "精製で純度が上がる")
	_ok(is_equal_approx(refined["amount"], 100.0), "精製で量が減る（収率）")

	_ok(Purity.meets(0.98, 0.9), "純度が要求を満たす")
	_ok(not Purity.meets(0.6, 0.9), "純度不足を検出する")

	_ok(is_equal_approx(Purity.blend([])["amount"], 0.0), "空の混合は 0")

# --- 反応マップ -------------------------------------------------------------

func _test_reaction() -> void:
	var map := ReactionMap.new()
	map.bounds = Rect2(0, 0, 10, 10)

	var target := ReactionRegion.new()
	target.kind = ReactionRegion.Kind.TARGET
	target.center = Vector2(2, 6)
	target.radius = 1.0
	target.product_id = &"dilute_sulfuric_acid"

	var hazard := ReactionRegion.new()
	hazard.kind = ReactionRegion.Kind.HAZARD
	hazard.center = Vector2(8, 9)
	hazard.radius = 1.5

	map.regions = [target, hazard]

	# 加熱で上へ動き、目標領域に入る。
	var sim := ReactionSim.new(map, Vector2(2, 2))
	_ok(sim.current_region() == null, "開始時は何もない領域")
	sim.heat(4.0)
	_ok(is_equal_approx(sim.position.y, 6.0), "加熱は上（+y）へ移動")
	_ok(sim.current_region() == target, "目標領域に到達")
	_ok(not sim.is_hazard(), "目標領域は暴走域ではない")

	# 経路が長いほど収率が下がる。
	var short_path := ReactionSim.new(map, Vector2(2, 2))
	short_path.heat(2.0)
	var long_path := ReactionSim.new(map, Vector2(2, 2))
	long_path.heat(2.0)
	long_path.distill(3.0)
	long_path.add_water(3.0)
	_ok(long_path.yield_ratio() < short_path.yield_ratio(), "遠回りは収率を下げる")

	# 暴走域の検出。
	var into_hazard := ReactionSim.new(map, Vector2(8, 2))
	into_hazard.heat(7.0)
	_ok(into_hazard.is_hazard(), "暴走域への侵入を検出")

	# 境界クランプ。
	var oob := ReactionSim.new(map, Vector2(5, 5))
	oob.heat(100.0)
	_ok(oob.position.y <= 10.0, "移動は境界内にクランプされる")

	# 素材投入による跳躍。
	var sulfur := MaterialDef.new()
	sulfur.jump_vector = Vector2(1, 1)
	sulfur.jump_magnitude = 2.0
	var jump := ReactionSim.new(map, Vector2(1, 1))
	jump.add_material(sulfur)
	_ok(jump.position == Vector2(3, 3), "素材投入で固有方向へ跳躍")

# --- pH（連続モデル） -------------------------------------------------------

func _test_ph() -> void:
	var map := ReactionMap.new()
	map.bounds = Rect2(0, 0, 10, 10)

	# 強酸・高濃度は pH < 2。
	var acid := ReactionSim.new(map, Vector2(9, 5))  # 濃度 0.9
	acid.add_acid(1.0)
	_ok(acid.ph() < 2.0, "強酸・高濃度は pH<2")

	# 希釈すると pH が中性へ寄る（同じ net_acid で濃度だけ下げる）。
	var diluted := ReactionSim.new(map, Vector2(9, 5))
	diluted.add_acid(1.0)
	var before := diluted.ph()
	diluted.add_water(8.0)  # x:9→1、濃度 0.9→0.1
	_ok(diluted.ph() > before, "希釈で pH が中性へ寄る")
	_ok(diluted.ph() < 7.0, "希釈しても酸性のまま（7未満）")

	# 中和: 塩基を加えると pH が 7 に寄る。
	var neutralize := ReactionSim.new(map, Vector2(9, 5))
	neutralize.add_acid(1.0)
	var acidic_ph := neutralize.ph()
	neutralize.add_base(1.0)  # net_acid → 0
	_ok(neutralize.ph() > acidic_ph, "塩基投入で pH が上がる")
	_ok(absf(neutralize.ph() - 7.0) < 0.6, "完全中和で pH ≈ 7")

	# 塩基過剰は pH > 7。
	var basic := ReactionSim.new(map, Vector2(9, 5))
	basic.add_base(1.0)
	_ok(basic.ph() > 7.0, "塩基過剰は pH>7")

	# 素材の酸性度が組成に反映される（塩基性素材で中和方向）。
	var lime := MaterialDef.new()
	lime.acidity = -1.0
	lime.jump_magnitude = 1.0
	var mat := ReactionSim.new(map, Vector2(9, 5))
	mat.add_acid(1.0)
	mat.add_material(lime)
	_ok(mat.net_acid < 1.0, "塩基性素材の投入で net_acid が下がる")

# --- 反応マップ（最短経路・暴走域・pH条件） --------------------------------

func _test_reaction_hazards() -> void:
	var map := ReactionMap.new()
	map.bounds = Rect2(0, 0, 10, 10)
	var target := ReactionRegion.new()
	target.kind = ReactionRegion.Kind.TARGET
	target.center = Vector2(2, 6)
	target.radius = 1.2
	var hazard := ReactionRegion.new()
	hazard.kind = ReactionRegion.Kind.HAZARD
	hazard.center = Vector2(8, 9)
	hazard.radius = 1.5
	map.regions = [target, hazard]

	# 最短経路は蛇行より高収率。
	var straight := ReactionSim.new(map, Vector2(2, 2))
	straight.heat(4.0)  # → 中心 (2,6)
	var winding := ReactionSim.new(map, Vector2(2, 2))
	winding.heat(4.0)       # 中心
	winding.add_water(1.0)  # (1,6)
	winding.distill(1.0)    # (2,6) 戻る
	_ok(straight.yield_ratio() > winding.yield_ratio(), "最短経路は蛇行より高収率")
	_ok(straight.yield_ratio() > 0.9, "完璧な最短経路はほぼ収率1")

	# 暴走域への突入でバッチ全損＋設備ダメージ。
	var boom := ReactionSim.new(map, Vector2(8, 2))
	boom.heat(7.0)  # → 中心 (8,9)
	_ok(boom.is_hazard(), "暴走域を検出")
	_ok(boom.batch_lost, "暴走域突入でバッチ全損")
	_ok(is_equal_approx(boom.yield_ratio(), 0.0), "全損時の収率は 0")
	_ok(boom.equipment_damage > 0.0, "高温の暴走域は設備を痛める")

	# 縁をかすめると収率が落ちる（同じ経路長で比較）。
	var graze := ReactionSim.new(map, Vector2(8, 2))
	graze.heat(5.0)  # → (8,7)、中心まで距離 2.0（半径1.5＋余白1.0の内側）
	var safe := ReactionSim.new(map, Vector2(5, 2))
	safe.heat(5.0)   # → (5,7)、何もない
	_ok(not graze.batch_lost, "かすめただけでは全損しない")
	_ok(graze.yield_ratio() < safe.yield_ratio(), "暴走域をかすめると収率が落ちる")

	# pH 条件つき目標: 空間的に入っても pH が合わなければ未達成。
	var ph_target := ReactionRegion.new()
	ph_target.kind = ReactionRegion.Kind.TARGET
	ph_target.center = Vector2(5, 5)
	ph_target.radius = 1.0
	ph_target.requires_ph = true
	ph_target.ph_min = 0.0
	ph_target.ph_max = 4.0
	var pmap := ReactionMap.new()
	pmap.bounds = Rect2(0, 0, 10, 10)
	pmap.regions = [ph_target]
	var ps := ReactionSim.new(pmap, Vector2(5, 5))
	_ok(ps.current_region() == ph_target, "空間的には領域内")
	_ok(ps.reached_target() == null, "pH 未達では目標未達成")
	ps.add_acid(2.0)  # pH を下げて条件内へ
	_ok(ps.ph() <= 4.0, "酸を加えて pH を条件内へ")
	_ok(ps.reached_target() == ph_target, "空間＋pH 条件を満たして達成")

# --- 酸・塩基マップ 統合シナリオ（実データ .tres を読み込む） ---------------
# 「緑礬で濃硫酸を作る → 希釈して希硫酸にする → 石灰で中和すると条件を外れる」
# という一本の筋を、data/ の実リソースを読んで検証する（.tres の回帰も兼ねる）。

func _test_acid_base_scenario() -> void:
	var map: ReactionMap = load("res://data/reactions/acid_base_map.tres")
	_ok(map != null, "酸塩基マップを .tres から読み込める")
	var vitriol: MaterialDef = load("res://data/materials/vitriol.tres")
	var lime: MaterialDef = load("res://data/materials/lime.tres")
	_ok(vitriol != null and lime != null, "素材 .tres を読み込める")
	if map == null or vitriol == null or lime == null:
		return

	# 緑礬を重ねて投入 → 右上・強酸性へ動き、濃硫酸の領域へ。
	var sim := ReactionSim.new(map, Vector2(4, 3))
	for i in 5:
		sim.add_material(vitriol)
	var conc := sim.reached_target()
	_ok(conc != null and conc.product_id == &"concentrated_sulfuric_acid", "緑礬の投入で濃硫酸に到達")

	# 加水で希釈し、加熱して希硫酸の領域へ（酸性のまま濃度を下げる）。
	sim.add_water(5.0)
	sim.heat(2.0)
	var dilute := sim.reached_target()
	_ok(dilute != null and dilute.product_id == &"dilute_sulfuric_acid", "希釈して希硫酸へ移行")
	_ok(not sim.batch_lost and sim.yield_ratio() > 0.0, "全損せず収率が残る")

	# 石灰（塩基）で中和すると pH が上がり、希硫酸の pH 条件を外れる。
	for i in 6:
		sim.add_material(lime)
	_ok(sim.ph() > 3.0, "石灰で中和すると pH が希硫酸条件(≤3)を外れる")
	_ok(sim.reached_target() == null, "中和後は希硫酸として成立しない")

# --- 実験ノート（経路の保存・再生・委任量産） ------------------------------

func _test_reaction_note() -> void:
	var map := ReactionMap.new()
	map.bounds = Rect2(0, 0, 10, 10)
	var target := ReactionRegion.new()
	target.kind = ReactionRegion.Kind.TARGET
	target.center = Vector2(2, 6)
	target.radius = 1.2
	target.product_id = &"dilute_sulfuric_acid"
	target.base_purity = 0.8
	target.requires_ph = true
	target.ph_min = 0.0
	target.ph_max = 3.0
	map.regions = [target]

	var vitriol := MaterialDef.new()
	vitriol.id = &"vitriol"
	vitriol.jump_vector = Vector2(0.0, 0.0)
	vitriol.acidity = 1.0
	var materials := {&"vitriol": vitriol}

	# 経路を実行して目標へ到達し、ノートに保存。
	var sim := ReactionSim.new(map, Vector2(2, 2))
	sim.add_material(vitriol)
	sim.add_material(vitriol)  # net_acid=2、pH を条件内へ
	sim.heat(4.0)              # → (2,6)
	var note := sim.to_note()
	_ok(note.product_id == &"dilute_sulfuric_acid", "ノートに到達物質が記録される")
	_ok(note.operations.size() == 3, "操作列が記録される")

	# 再生は決定的に同じ結果を再現する。
	var replay := note.replay(map, materials)
	_ok(replay.position == sim.position, "再生で同じ座標に到達")
	_ok(is_equal_approx(replay.ph(), sim.ph()), "再生で同じ pH")
	_ok(is_equal_approx(replay.yield_ratio(), sim.yield_ratio()), "再生で同じ収率")
	_ok(replay.reached_target() != null, "再生でも目標を達成")

	# 委任量産: 入力量×収率、純度は base_purity×入力純度。
	var out := note.produce(100.0, 0.9)
	_ok(out["product_id"] == &"dilute_sulfuric_acid", "生産物の id が返る")
	_ok(is_equal_approx(out["amount"], 100.0 * note.recorded_yield), "生産量は入力量×収率")
	_ok(is_equal_approx(out["purity"], 0.8 * 0.9), "純度は base_purity×入力純度")

# --- レシピ逆算（願い → 必要物質） ------------------------------------------

func _test_recipe_resolver() -> void:
	var acid := Recipe.new()
	acid.product_id = &"dilute_sulfuric_acid"
	acid.inputs = [&"vitriol"]
	acid.tech_id = &"glass_flask"
	var drug := Recipe.new()
	drug.product_id = &"sulfa_drug"
	drug.inputs = [&"dilute_sulfuric_acid"]
	var cure := Recipe.new()
	cure.product_id = &"cure"
	cure.inputs = [&"sulfa_drug"]
	var book := RecipeBook.new([acid, drug, cure])

	# 何も持っていない状態で治療薬を逆算。
	var plan := book.resolve(&"cure", [])
	_ok(plan["ok"], "既知レシピで葉まで辿れる")
	_ok(plan["steps"] == [&"dilute_sulfuric_acid", &"sulfa_drug", &"cure"], "工程が依存順に並ぶ")
	_ok(plan["raw_needed"] == [&"vitriol"], "採取が必要な原料は緑礬")
	_ok(&"glass_flask" in plan["tech_needed"], "必要設備が挙がる")

	# 中間生成物を所持していれば、そこから先だけになる（枝刈り）。
	var plan2 := book.resolve(&"cure", [&"dilute_sulfuric_acid"])
	_ok(plan2["steps"] == [&"sulfa_drug", &"cure"], "所持分は工程から外れる")
	_ok(plan2["raw_needed"].is_empty(), "所持していれば原料採取は不要")
	_ok(plan2["tech_needed"].is_empty(), "所持分の設備要求も消える")

	# 循環依存は ok=false で検出する。
	var a := Recipe.new()
	a.product_id = &"a"
	a.inputs = [&"b"]
	var b := Recipe.new()
	b.product_id = &"b"
	b.inputs = [&"a"]
	var loopy := RecipeBook.new([a, b])
	_ok(not loopy.resolve(&"a", [])["ok"], "循環依存を検出する")

func _test_recipe_data() -> void:
	var acid: Recipe = load("res://data/recipes/dilute_sulfuric_acid.tres")
	var drug: Recipe = load("res://data/recipes/sulfa_drug.tres")
	var cure: Recipe = load("res://data/recipes/cure.tres")
	_ok(acid != null and drug != null and cure != null, "レシピ .tres を読み込める")
	if acid == null or drug == null or cure == null:
		return
	var book := RecipeBook.new([acid, drug, cure])
	var plan := book.resolve(&"cure", [])
	_ok(plan["steps"] == [&"dilute_sulfuric_acid", &"sulfa_drug", &"cure"], "実データでも工程順に逆算できる")
	_ok(plan["raw_needed"] == [&"vitriol"], "実データでも原料は緑礬")
	_ok(&"glass_flask" in plan["tech_needed"] and &"synthesis_bench" in plan["tech_needed"], "実データで必要設備が揃う")

# --- 発見型ワークベンチ（状態×道具×動作） ---------------------------------
# UC-1 石の鏃：素手では割れない → 敲石で剥離 → 鹿角で整形 → 押圧具で刃付け。

func _make_knap_processes() -> Array:
	var pick := ProcessDef.new()
	pick.id = &"pick"; pick.display_name = "石材選び"
	pick.tool = &"hand"; pick.motion = &"place"; pick.result_shape = "原石"
	var rough := ProcessDef.new()
	rough.id = &"rough"; rough.display_name = "粗割り"
	rough.tool = &"hammer"; rough.motion = &"strike"; rough.requires_shape = "原石"
	rough.result_shape = "粗い両面"; rough.effects = {&"鋭さ": 35.0, &"完成度": 20.0}
	var form := ProcessDef.new()
	form.id = &"form"; form.display_name = "剥離整形"
	form.tool = &"antler"; form.motion = &"strike"; form.requires_shape = "粗い両面"
	form.result_shape = "木葉形"; form.effects = {&"対称性": 70.0, &"完成度": 55.0}
	var edge := ProcessDef.new()
	edge.id = &"edge"; edge.display_name = "刃付け"
	edge.tool = &"presser"; edge.motion = &"press"; edge.requires_shape = "木葉形"
	edge.result_shape = "鏃"; edge.effects = {&"鋭さ": 95.0, &"完成度": 100.0}
	return [pick, rough, form, edge]

func _test_workbench() -> void:
	var wb := Workbench.new(_make_knap_processes(), Workpiece.new())

	# 素手で置く → 石材選びを発見。
	wb.equip(&"hand")
	var r1 := wb.apply(&"place")
	_ok(r1["ok"] and r1["process"].id == &"pick", "素手で石材選びを発見")
	_ok(wb.workpiece.shape == "原石", "形が原石になる")

	# 素手で叩く → 割れない（状態は合うが道具違い、敲石が要る）。
	var r2 := wb.apply(&"strike")
	_ok(not r2["ok"] and r2["reason"] == &"wrong_tool", "素手では割れない")
	_ok(r2["needed_tool"] == &"hammer", "必要な道具は敲石")

	# 敲石で叩く → 粗割り。
	wb.equip(&"hammer")
	var r3 := wb.apply(&"strike")
	_ok(r3["ok"] and r3["process"].id == &"rough", "敲石で粗割りを発見")
	_ok(is_equal_approx(wb.workpiece.get_prop(&"完成度"), 20.0), "完成度が上がる")

	# 鹿角で整形、押圧具で刃付け。
	wb.equip(&"antler")
	_ok(wb.apply(&"strike")["process"].id == &"form", "鹿角で剥離整形を発見")
	wb.equip(&"presser")
	var r5 := wb.apply(&"press")
	_ok(r5["ok"] and r5["process"].id == &"edge", "押圧具で刃付けを発見")
	_ok(wb.workpiece.shape == "鏃", "完成＝鏃")
	_ok(is_equal_approx(wb.workpiece.get_prop(&"完成度"), 100.0), "完成度100")

	# 打製では研がない → 効果なし。
	var rg := wb.apply(&"grind")
	_ok(not rg["ok"] and rg["reason"] == &"no_effect", "研ぐ動作は意味がない")

	# ノート＝発見した〔道具×動作〕の列（順番通り）。
	var note := wb.note()
	_ok(note.size() == 4, "4工程を発見")
	_ok(note[0]["process_id"] == &"pick" and note[3]["process_id"] == &"edge", "発見順が保存される")
	_ok(note[1]["tool"] == &"hammer" and note[1]["motion"] == &"strike", "道具と動作が記録される")

# --- 熱源 ---------------------------------------------------------------------

func _make_heat_source(mode: HeatSource.InputMode, ceiling: float, decay: float) -> HeatSource:
	var h := HeatSource.new()
	h.id = &"test"; h.max_temperature = ceiling; h.input_mode = mode
	h.input_gain = 1.0; h.drive_decay = decay; h.idle_drive = 0.15
	h.fuel_burn_rate = 0.02; h.drive_burn_rate = 0.1; h.response_time = 1.0
	return h

func _run_fire(sim: FireSim, seconds: float, per_tick: Callable = Callable()) -> void:
	var dt := 0.05
	var t := 0.0
	while t < seconds:
		if per_tick.is_valid():
			per_tick.call(dt)
		sim.tick(dt)
		t += dt

## 熾火になったら薪を足す（「タイミングよく薪を入れる」の模倣）。
func _feed_on_embers(fire: FireSim) -> void:
	if fire.fuel <= FireSim.FEED_WINDOW_HIGH:
		fire.feed()

func _test_fire_sim() -> void:
	# ① 直火：タイミングよく薪を入れる（クリック）。判定は燃料残量。
	var fire := FireSim.new(_make_heat_source(HeatSource.InputMode.FEED_TIMING, 600.0, 0.35), 0.3)
	_ok(not fire.fan(1.0) and not fire.pump(1.0), "直火はあおぐ／ふいごを受け付けない")
	_ok(is_equal_approx(fire.drive, 0.15), "燃料があれば弱く燃えている（idle_drive）")
	var r1 := fire.feed()
	_ok(r1["ok"] and r1["timing"] == &"good", "熾火に薪＝good で火勢最大")
	_ok(is_equal_approx(fire.drive, 1.0), "good の火勢は 1.0")
	_run_fire(fire, 2.0)
	_ok(fire.temperature > 300.0, "薪を入れた直後は温度が上がる (%.0f℃)" % fire.temperature)
	_ok(fire.temperature <= 600.0, "直火は 600℃ を超えない")
	var r2 := fire.feed()
	_ok(r2["timing"] == &"early", "燃えている最中の薪＝early（窒息）")
	_ok(fire.drive < 0.5, "early で火勢が落ちる")
	# 熾火のたびに薪を足し続ければ温度を保てる。
	_run_fire(fire, 10.0, func(_dt): _feed_on_embers(fire))
	_ok(fire.temperature > 150.0 and fire.temperature <= 600.0, "薪を保てば温度を保てる (%.0f℃)" % fire.temperature)
	# 放置すると燃料が尽きて外気温へ戻る。
	_run_fire(fire, 60.0)
	_ok(fire.is_out() and is_equal_approx(fire.drive, 0.0), "放置すると火が消える")
	_ok(fire.temperature < 30.0, "消えた火は外気温へ (%.0f℃)" % fire.temperature)
	var r3 := fire.feed()
	_ok(r3["timing"] == &"late" and is_equal_approx(fire.drive, FireSim.RELIGHT_DRIVE), "消えてからの薪＝late（点け直しは弱い）")

	# ② 囲い炉：あおぐ（スライド距離）。止めると衰える。
	var hearth := FireSim.new(_make_heat_source(HeatSource.InputMode.FAN_SLIDE, 900.0, 0.9), 1.0)
	_ok(not hearth.feed()["ok"], "囲い炉は薪のタイミング操作を受け付けない")
	_run_fire(hearth, 6.0, func(dt): hearth.fan(dt * 3.0))
	_ok(hearth.drive > 0.9, "あおぎ続けると火勢が最大近くになる (%.2f)" % hearth.drive)
	_ok(hearth.temperature > 700.0 and hearth.temperature <= 900.0, "囲い炉は 900℃ 天井の範囲で高温に (%.0f℃)" % hearth.temperature)
	var before := hearth.temperature
	_run_fire(hearth, 3.0)
	_ok(hearth.drive <= 0.16 and hearth.temperature < before, "手を止めると火勢が下限まで落ち温度も下がる")

	# ③ ふいご炉：押し続ける（長押し）。短い押下では弱い。
	var forge := FireSim.new(_make_heat_source(HeatSource.InputMode.BELLOWS_HOLD, 1300.0, 1.2), 1.0)
	forge.pump(0.1)
	forge.tick(0.05)
	_ok(forge.drive < 0.4, "一瞬押しただけでは火勢が弱い")
	_run_fire(forge, 6.0, func(dt): forge.pump(dt * 2.0))
	_ok(forge.drive > 0.9, "押し続けると火勢が最大近くになる")
	_ok(forge.temperature > 1000.0 and forge.temperature <= 1300.0, "ふいご炉は 1300℃ 天井の範囲で高温に (%.0f℃)" % forge.temperature)
	_ok(forge.operations.size() > 0 and forge.operations[0]["op"] == &"pump", "操作が記録される")

func _test_heat_ceiling() -> void:
	var map := ReactionMap.new()
	map.bounds = Rect2(0, 0, 10, 10)
	map.temperature_range = Vector2(20.0, 1000.0)
	_ok(is_equal_approx(map.temperature_to_y(20.0), 0.0) and is_equal_approx(map.temperature_to_y(1000.0), 10.0), "℃→座標の両端")
	_ok(is_equal_approx(map.y_to_temperature(5.0), 510.0), "座標→℃")

	var direct := HeatSource.new()
	direct.max_temperature = 600.0
	var expected_ceiling := map.temperature_to_y(600.0)

	# 熱源なし＝従来通り、マップ上端まで上がる。
	var free := ReactionSim.new(map, Vector2(2, 2))
	free.heat(100.0)
	_ok(is_equal_approx(free.position.y, 10.0), "熱源未設定なら制限なし")

	# 直火＝600℃ の天井でハードクランプ。
	var limited := ReactionSim.new(map, Vector2(2, 2))
	limited.set_heat_source(direct)
	limited.heat(100.0)
	_ok(is_equal_approx(limited.position.y, expected_ceiling), "直火の天井でクランプ (y=%.2f)" % limited.position.y)
	limited.heat(1.0)
	_ok(is_equal_approx(limited.position.y, expected_ceiling), "天井に居ても更に上がらない")
	limited.heat(-1.0)
	_ok(is_equal_approx(limited.position.y, expected_ceiling - 1.0), "冷却は天井に関係なく効く")
	_ok(is_equal_approx(limited.path_length, expected_ceiling - 2.0 + 1.0), "クランプ後の経路長は実移動ぶんだけ")

	# 天井より上にいる状態で据え替えても、引きずり下ろさない。
	var high := ReactionSim.new(map, Vector2(2, 9))
	high.set_heat_source(direct)
	high.heat(0.5)
	_ok(is_equal_approx(high.position.y, 9.0), "天井より上にいる場合は現状維持")
	high.set_heat_source(null)
	high.heat(0.5)
	_ok(is_equal_approx(high.position.y, 9.5), "null で制限解除")

func _test_heat_data() -> void:
	var expected := {
		"direct_fire": [1, 600.0, HeatSource.InputMode.FEED_TIMING],
		"enclosed_fire": [2, 900.0, HeatSource.InputMode.FAN_SLIDE],
		"bellows_forge": [3, 1300.0, HeatSource.InputMode.BELLOWS_HOLD],
	}
	var prev_ceiling := 0.0
	for id in expected:
		var h: HeatSource = load("res://data/heat/%s.tres" % id)
		_ok(h != null, "data/heat/%s.tres を読める" % id)
		if h == null:
			continue
		var e: Array = expected[id]
		_ok(h.id == StringName(id) and h.tier == e[0], "%s: id と段階" % id)
		_ok(is_equal_approx(h.max_temperature, e[1]) and h.input_mode == e[2], "%s: 天井と操作" % id)
		_ok(h.max_temperature > prev_ceiling, "%s: 上の段階ほど天井が高い" % id)
		prev_ceiling = h.max_temperature

# --- カレンダー -------------------------------------------------------------

func _test_calendar() -> void:
	var cal := GameCalendar.new()
	_ok(cal.season() == GameCalendar.Season.SPRING, "初日は春")
	_ok(cal.day_of_season() == 1, "初日は季節の 1 日目")
	_ok(cal.year() == 1, "初年度は 1 年目")

	cal.advance(28)
	_ok(cal.season() == GameCalendar.Season.SUMMER, "28日後は夏")
	_ok(cal.day_of_season() == 1, "季節が変わると日がリセット")

	cal.advance(28 * 3)
	_ok(cal.season() == GameCalendar.Season.SPRING, "1年で春に戻る")
	_ok(cal.year() == 2, "2 年目に入る")

	cal.advance(-1000)
	_ok(cal.total_day >= 0, "通算日数は負にならない")
