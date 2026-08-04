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
