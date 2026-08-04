## レシピ集＋逆算ソルバー（設計書 §2 コアループ②「必要なものを推理する」）。
##
## 願い（作りたい物）を与えると、依存関係を後ろ向きにたどって
## 「何を先に作ればいいか（工程順）」「何を採取してくる必要があるか（原料）」
## 「どの設備が要るか」を導く。純粋ロジックなので UI なしで検証できる。
class_name RecipeBook
extends RefCounted

## product_id -> Recipe。
var recipes: Dictionary = {}

func _init(recipe_list: Array = []) -> void:
	for r in recipe_list:
		if r is Recipe:
			recipes[r.product_id] = r

## 生成物のレシピを返す（無ければ null＝採取するしかない原料）。
func recipe_for(product_id: StringName) -> Recipe:
	return recipes.get(product_id)

## 願い（goal_id）を達成するための計画を逆算して返す。
##   owned: すでに所持している物の id 一覧（ここで枝刈りされる）。
## 戻り値:
##   {
##     "ok": bool,               # 既知のレシピで葉（原料）まで辿れたか（循環が無いか）
##     "steps": Array,           # 作るべき生成物の工程順（依存を先に、goal を最後に）
##     "raw_needed": Array,      # レシピが無く採取が必要な原料（所持分は除く）
##     "tech_needed": Array,     # 必要な設備・技術の id
##   }
func resolve(goal_id: StringName, owned: Array = []) -> Dictionary:
	var steps: Array = []
	var raw: Array = []
	var techs: Array = []
	var state: Dictionary = {}
	var ok := _expand(goal_id, owned, steps, raw, techs, state)
	return {"ok": ok, "steps": steps, "raw_needed": raw, "tech_needed": techs}

func _expand(id: StringName, owned: Array, steps: Array, raw: Array, techs: Array, state: Dictionary) -> bool:
	if id in owned:
		return true
	var s: String = state.get(id, "")
	if s == "done":
		return true
	if s == "visiting":
		return false  # 循環検出
	var recipe := recipe_for(id)
	if recipe == null:
		# レシピが無い＝採取するしかない原料。
		if not (id in raw):
			raw.append(id)
		state[id] = "done"
		return true
	state[id] = "visiting"
	var ok := true
	for inp in recipe.inputs:
		if not _expand(inp, owned, steps, raw, techs, state):
			ok = false
	if recipe.tech_id != &"" and not (recipe.tech_id in techs):
		techs.append(recipe.tech_id)
	state[id] = "done"
	if not (id in steps):
		steps.append(id)  # 依存を先に積んだ後に自分＝工程順（トポロジカル）
	return ok
