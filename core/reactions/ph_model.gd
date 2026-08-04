## pH の連続モデル（設計書 §3、第10章の決定）。
##
## pH は「直接いじる値」ではなく、組成（酸/塩基の量）と濃度から決まる“結果”。
## 反応マップ上では等高線オーバーレイとして描画するため、ここはその数値核。
##
## 設計上の要件:
##   - 加水（希釈）で pH が中性へ寄る  … concentration で自動的に弱まる
##   - 酸/塩基の投入（中和）で pH が動く … net_acid の符号で決まる
##   - 高温でわずかに中性点が下がる（Kw）… temperature の効果（フレーバー）
##   - 0〜14 に有界で、特異点を持たない … tanh でなめらかに飽和させる
##
## 入力の濃度・温度は「マップ座標を 0〜1 に正規化した値」を受け取る（軸の絶対単位に依存しない）。
class_name PHModel
extends RefCounted

## 中性の基準 pH。
const NEUTRAL_PH := 7.0

## net_acid × 濃度 を pH スケールへ移すゲイン。
## 1.0（強酸1単位）×濃度1.0 で a=2 → tanh(2)≈0.96 → pH≈0.3 になる強さ。
const ACIDITY_GAIN := 2.0

## 高温側で中性 pH が下がる量（温度 0→1 で計 TEMP_NEUTRAL_SHIFT だけ動く）。
const TEMP_NEUTRAL_SHIFT := 0.8

## pH を計算する。
##   net_acid        : 正味の酸当量（正=酸性 / 負=塩基性）。組成側の状態。
##   concentration01 : 濃度（マップ横軸を 0〜1 に正規化）。希釈すると 0 に近づく。
##   temperature01   : 温度（マップ縦軸を 0〜1 に正規化）。
static func compute(net_acid: float, concentration01: float, temperature01: float) -> float:
	var c := clampf(concentration01, 0.0, 1.0)
	var t := clampf(temperature01, 0.0, 1.0)
	# 希釈すると c→0 になり、酸性度 a→0 ＝ 自動的に中性へ寄る。
	var a := net_acid * c * ACIDITY_GAIN
	# 高温ほど中性点をわずかに下げる（Kw の温度依存の擬似表現）。
	var neutral := NEUTRAL_PH - TEMP_NEUTRAL_SHIFT * (t - 0.5)
	# tanh で 0〜14 に有界化。net_acid=0 なら中性点そのもの。
	var ph := neutral - 7.0 * tanh(a)
	return clampf(ph, 0.0, 14.0)
