## 純度計算ユーティリティ（副作用なしの静的関数群）。
##
## 「純度72%の硫酸で反応Xは成立するか」を UI を起動せず検証できることが、
## バランス調整では決定的な差になる（設計書 §8）。ここはその中核。
class_name Purity
extends RefCounted

## 複数の Substance を混合したときの合計量と純度を返す。
## 純度は「純分の質量保存」で決まる: purity = Σ(amount_i * purity_i) / Σ(amount_i)。
##
## 戻り値: { "amount": float, "purity": float }
static func blend(substances: Array) -> Dictionary:
	var total := 0.0
	var pure := 0.0
	for s in substances:
		total += s.amount
		pure += s.amount * s.purity
	if total <= 0.0:
		return {"amount": 0.0, "purity": 0.0}
	return {"amount": total, "purity": pure / total}

## 精製工程（蒸留・ろ過・再結晶など）を抽象化したモデル。
## 純度は target_purity まで上がりうるが、recovery（0〜1）ぶんだけ量が減る＝収率が落ちる。
##
## 戻り値: { "amount": float, "purity": float }
static func refine(amount: float, purity: float, target_purity: float, recovery: float) -> Dictionary:
	var new_purity := clampf(maxf(purity, target_purity), 0.0, 1.0)
	var new_amount := amount * clampf(recovery, 0.0, 1.0)
	return {"amount": new_amount, "purity": new_purity}

## その純度が用途の要求を満たすか（設計書 §4 の「純度が足りなければ用途が限られる」）。
static func meets(purity: float, required: float) -> bool:
	return purity >= required
