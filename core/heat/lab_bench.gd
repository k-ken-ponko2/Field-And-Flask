## 作業台（純粋ロジック）。道具を選んで組み合わせる場所の“状態”。
##
## 置けるもの（今のところ）:
##   熱源  … HeatSource を据える（FireSim を作る）。差し替え可
##   容器  … 熱源の上に VesselDef を置く。火の温度に heat_lag で追従し、max_temperature を超えるとひび
## presentation 層はドラッグ＆ドロップをここの place_* に変換し、毎フレーム tick(dt) を呼ぶ。
class_name LabBench
extends RefCounted

var fire: FireSim = null
var vessel: VesselDef = null
var vessel_temperature: float = FireSim.AMBIENT
var vessel_cracked: bool = false
## 置いた・下ろしたの記録 [{op, id}]。
var log: Array = []

## 熱源を据える（既にあれば差し替え。容器は載ったまま）。
func place_heat_source(source: HeatSource, start_fuel: float = 0.6) -> Dictionary:
	if source == null:
		return {"ok": false, "reason": &"no_source"}
	fire = FireSim.new(source, start_fuel)
	log.append({"op": &"heat_source", "id": source.id})
	return {"ok": true, "reason": &""}

## 容器を熱源の上に置く。熱源が無いと置けない。既に載っていれば入れ替え。
func place_vessel(def: VesselDef) -> Dictionary:
	if def == null:
		return {"ok": false, "reason": &"no_vessel"}
	if fire == null:
		return {"ok": false, "reason": &"needs_heat_source"}
	vessel = def
	vessel_temperature = FireSim.AMBIENT
	vessel_cracked = false
	log.append({"op": &"vessel", "id": def.id})
	return {"ok": true, "reason": &""}

## 容器を下ろす。
func remove_vessel() -> void:
	if vessel != null:
		log.append({"op": &"remove_vessel", "id": vessel.id})
	vessel = null
	vessel_temperature = FireSim.AMBIENT
	vessel_cracked = false

## 時間を進める：火 → 容器の順。
func tick(dt: float) -> void:
	if fire == null or dt <= 0.0:
		return
	fire.tick(dt)
	if vessel == null:
		return
	var lag := maxf(vessel.heat_lag, 0.01)
	vessel_temperature += (fire.temperature - vessel_temperature) * minf(1.0, dt / lag)
	if not vessel_cracked and vessel_temperature > vessel.max_temperature:
		vessel_cracked = true
		log.append({"op": &"cracked", "id": vessel.id})

## 容器が載っていて無事か。
func vessel_ready() -> bool:
	return vessel != null and not vessel_cracked
