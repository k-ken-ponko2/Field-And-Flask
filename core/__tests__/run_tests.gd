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
