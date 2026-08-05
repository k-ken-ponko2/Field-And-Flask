## 発見型ワークベンチ（`docs/design/tactile-crafting.md` §4）。
##
## 1 個のワークピースと「装備中の道具」を持ち、動作(motion)を適用する。
## `(状態, 装備道具, 動作)` が成立する ProcessDef があれば、その工程が「発見」され効果が適用される。
## 成立しない場合は理由を返す（道具違い／効果なし）。発見した順＝クラフトノート（§7 の一般化）。
##
## 純粋ロジック（副作用なし）。UI を起動せず発見・自動化を検証できる。
class_name Workbench
extends RefCounted

var workpiece: Workpiece
var processes: Array = []          ## ProcessDef の一覧
var equipped: StringName = &"hand" ## 装備中の道具 id（既定=素手）
var discovered: Array = []         ## 発見した工程列 [{process_id, tool, motion}]（＝ノート）

var _discovered_ids: Dictionary = {}

func _init(process_list: Array = [], start_workpiece: Workpiece = null) -> void:
	processes = process_list
	workpiece = start_workpiece if start_workpiece != null else Workpiece.new()

## 道具を持ち替える。
func equip(tool_id: StringName) -> void:
	equipped = tool_id

## 動作を適用する。
## 戻り値: { "ok": bool, "process": ProcessDef|null, "reason": StringName, "needed_tool": StringName }
##   reason: &"" 成功 / &"wrong_tool" 状態は合うが道具違い / &"no_effect" 今の状態では無意味
func apply(motion: StringName) -> Dictionary:
	# 今の状態（形・パラメータ）で成立しうる未発見の候補。
	var candidates: Array = []
	for pdef in processes:
		if _discovered_ids.has(pdef.id):
			continue
		if pdef.motion != motion:
			continue
		if pdef.state_matches(workpiece):
			candidates.append(pdef)
	if candidates.is_empty():
		return {"ok": false, "process": null, "reason": &"no_effect", "needed_tool": &""}
	# 装備道具が合う候補があれば成立。
	for pdef in candidates:
		if pdef.tool == &"" or pdef.tool == equipped:
			pdef.apply_to(workpiece)
			_discovered_ids[pdef.id] = true
			discovered.append({"process_id": pdef.id, "tool": equipped, "motion": motion})
			return {"ok": true, "process": pdef, "reason": &"", "needed_tool": &""}
	# 状態は合うが道具が違う（＝「〇〇を持て」のヒント材料）。
	return {"ok": false, "process": null, "reason": &"wrong_tool", "needed_tool": candidates[0].tool}

## 発見済みか。
func is_discovered(process_id: StringName) -> bool:
	return _discovered_ids.has(process_id)

## クラフトノート（発見した〔道具×動作〕の列）を返す。
func note() -> Array:
	return discovered.duplicate(true)
