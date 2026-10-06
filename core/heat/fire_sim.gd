## 火（熱源）の純粋シミュレータ。`docs/design/heat-tiers.md` §4・§6。
##
## presentation 層はジェスチャ（クリック／スライド／長押し）を数値に変換してここへ流し、
## 毎フレーム tick(dt) を呼ぶ。ここには入力・描画・時間取得は一切ない（core のルール）。
##
## モデル:
##   drive（火勢 0〜1）  … 操作で上がり、放っておくと drive_decay で idle_drive まで衰える
##   fuel（燃料 0〜1）   … 時間と火勢で減る。尽きると火が消える（天井＝外気温）
##   temperature（℃）   … 平衡温度 = 外気温 + (天井 − 外気温) × drive^0.6 へ response_time で追従
##                        天井はハード：熱源の max_temperature を決して超えない
##
## 操作は熱源の input_mode に合うものだけ受け付ける（直火をあおいでも意味がない）。
class_name FireSim
extends RefCounted

## 外気温（℃）。火が消えたときに落ち着く温度。
const AMBIENT := 20.0
## 火勢 → 平衡温度のカーブ（1 未満で、弱い火勢でもそこそこ温度が出る）。
const DRIVE_CURVE := 0.6

## ① 薪入れ: 1 回で足される燃料。
const FEED_AMOUNT := 0.45
## ① 薪入れ: 燃料がこれ以下なら「熾火」＝ちょうどよいタイミング。
const FEED_WINDOW_HIGH := 0.45
## ① 薪入れ: 早すぎ（まだ燃料が多い）と火が窒息して火勢がこの倍率に落ちる。
const SMOTHER_FACTOR := 0.4
## ① 薪入れ: 消えた火に薪を足したときの火勢（点け直しは弱い）。
const RELIGHT_DRIVE := 0.25

var source: HeatSource
var temperature: float = AMBIENT
var fuel: float = 0.0
var drive: float = 0.0
## 経過時間（秒）。
var elapsed: float = 0.0
## 操作の記録 [{op, ...}]（実験ノート一般化の下地）。
var operations: Array = []

func _init(heat_source: HeatSource, start_fuel: float = 0.5) -> void:
	source = heat_source
	fuel = clampf(start_fuel, 0.0, 1.0)
	drive = _idle_drive()

## この熱源が受け付ける操作か。
func accepts(mode: HeatSource.InputMode) -> bool:
	return source != null and source.input_mode == mode

## ① 薪を入れる（クリック）。タイミングは燃料残量で判定する。
## 戻り値: { "ok": bool, "timing": &"good" | &"early" | &"late" }
##   good  … 熾火に薪 → 火勢が最大になる
##   early … まだ燃えているのに薪 → 窒息して火勢が落ちる
##   late  … 火が消えてから薪 → 点け直し（火勢は弱い）
func feed() -> Dictionary:
	if not accepts(HeatSource.InputMode.FEED_TIMING):
		return {"ok": false, "timing": &""}
	var timing: StringName
	if fuel <= 0.0:
		timing = &"late"
		drive = RELIGHT_DRIVE
	elif fuel <= FEED_WINDOW_HIGH:
		timing = &"good"
		drive = 1.0
	else:
		timing = &"early"
		drive *= SMOTHER_FACTOR
	fuel = minf(1.0, fuel + FEED_AMOUNT)
	operations.append({"op": &"feed", "timing": timing})
	return {"ok": true, "timing": timing}

## ② あおぐ（マウスのスライド）。distance はこのフレームで動かした距離（正規化単位）。
func fan(distance: float) -> bool:
	if not accepts(HeatSource.InputMode.FAN_SLIDE) or distance <= 0.0:
		return false
	drive = minf(1.0, drive + distance * source.input_gain)
	operations.append({"op": &"fan", "amount": distance})
	return true

## ③ ふいごを押し続ける（クリック長押し）。held_seconds は押していた時間（通常は dt）。
func pump(held_seconds: float) -> bool:
	if not accepts(HeatSource.InputMode.BELLOWS_HOLD) or held_seconds <= 0.0:
		return false
	drive = minf(1.0, drive + held_seconds * source.input_gain)
	operations.append({"op": &"pump", "amount": held_seconds})
	return true

## 時間を進める。火勢の衰え → 燃料消費 → 温度の追従（天井でハードクランプ）。
func tick(dt: float) -> void:
	if source == null or dt <= 0.0:
		return
	elapsed += dt
	fuel = maxf(0.0, fuel - (source.fuel_burn_rate + drive * source.drive_burn_rate) * dt)
	drive = maxf(_idle_drive(), drive - source.drive_decay * dt)
	var ceiling := source.max_temperature if fuel > 0.0 else AMBIENT
	var equilibrium := AMBIENT + (ceiling - AMBIENT) * pow(drive, DRIVE_CURVE)
	temperature += (equilibrium - temperature) * minf(1.0, dt / source.response_time)
	temperature = clampf(temperature, AMBIENT, source.max_temperature)

## 火が消えているか（燃料切れ）。
func is_out() -> bool:
	return fuel <= 0.0

## 燃料がある間の火勢の下限。消えていれば 0。
func _idle_drive() -> float:
	if source == null or fuel <= 0.0:
		return 0.0
	return clampf(source.idle_drive, 0.0, 1.0)

## 天井に対する温度（0〜1）。
func temperature01() -> float:
	if source == null or source.max_temperature <= AMBIENT:
		return 0.0
	return clampf((temperature - AMBIENT) / (source.max_temperature - AMBIENT), 0.0, 1.0)

## 指定の温度帯に入っているか（℃）。
func in_band(low: float, high: float) -> bool:
	return temperature >= low and temperature <= high
