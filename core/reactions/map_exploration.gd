## 反応マップの探索状態（霧の晴れ方と発見済みの物質）。設計書 §3.2「未踏領域」。
##
## ポーションクラフトの霧と同じ約束:
##   - マップは最初モヤで覆われ、マーカーが通った周りだけ晴れる（晴れた跡は残る）
##   - 目標は晴れても「？」のまま。瓶詰め（生成）で初めて名前が付き、周りのモヤが広めに晴れる
## 純粋ロジック（Resource なので .tres に保存できる＝セーブデータの一部）。描画は presentation 側。
class_name MapExploration
extends Resource

## マーカーの周りが晴れる半径（マップ座標）。
const REVEAL_RADIUS := 0.9
## 発見（瓶詰め）で晴れる半径は、領域の半径にこれを足したもの。
const DISCOVERY_MARGIN := 1.0
## 訪問点を間引く距離（これより近い点は追加しない）。
const MIN_STEP := 0.25

@export var map_id: StringName = &""
## 晴れた点の列 [{ "p": Vector2, "r": float }]。
@export var revealed: Array = []
## 発見済みの物質 id。
@export var discovered: Array[StringName] = []

func _init(id: StringName = &"") -> void:
	map_id = id

## マーカーの位置を記録する（近すぎれば追加しない）。追加したら true。
func mark_visited(p: Vector2) -> bool:
	if not revealed.is_empty():
		var last: Dictionary = revealed.back()
		if (last["p"] as Vector2).distance_to(p) < MIN_STEP:
			return false
	revealed.append({"p": p, "r": REVEAL_RADIUS})
	return true

## 任意の点の周りを晴らす（発見時など）。
func reveal_around(p: Vector2, radius: float) -> void:
	revealed.append({"p": p, "r": radius})

## 物質を発見する。初めてなら true。
func discover(product_id: StringName) -> bool:
	if product_id == &"" or discovered.has(product_id):
		return false
	discovered.append(product_id)
	return true

func is_discovered(product_id: StringName) -> bool:
	return discovered.has(product_id)

## 点の見えやすさ（0=モヤ、1=晴れ）。最寄りの晴れた点の縁から soft だけ外側まで滑らかに落ちる。
func visibility(p: Vector2, soft: float = 0.5) -> float:
	var best := 0.0
	for e in revealed:
		var d := (e["p"] as Vector2).distance_to(p)
		var r: float = e["r"]
		var v: float
		if d <= r:
			v = 1.0
		elif d >= r + soft:
			v = 0.0
		else:
			v = 1.0 - (d - r) / soft
		if v > best:
			best = v
			if best >= 1.0:
				break
	return best

## 点がはっきり見えるか（晴れの内側）。
func is_revealed(p: Vector2) -> bool:
	return visibility(p, 0.0) >= 1.0
