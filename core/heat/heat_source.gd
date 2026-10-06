## 熱源の定義（データ駆動）。`docs/design/heat-tiers.md`。
##
## 熱源ティア＝反応マップの温度軸の「到達天井」。天井はハード（それ以上は上げられない）。
## 各ティアは火力を上げる“操作”も異なる（仮の3段階）:
##   ① 直火            … タイミングよく薪を入れる（クリック）        FEED_TIMING
##   ② 囲い＋あおぐ    … あおぐ（マウスのスライド）                  FAN_SLIDE
##   ③ ふいご          … ふいごを押し続ける（クリック長押し）        BELLOWS_HOLD
## 操作の種類はデータ（input_mode）で宣言し、presentation 層はそれを見てジェスチャを選ぶ。
## 数値の意味づけは FireSim 側（core/heat/fire_sim.gd）にある。
class_name HeatSource
extends Resource

## 火力を上げる操作の種類。
enum InputMode { FEED_TIMING, FAN_SLIDE, BELLOWS_HOLD }

## 一意な識別子（例: &"direct_fire"）。
@export var id: StringName = &""

## 表示名（例: "直火"）。
@export var display_name: String = ""

## 熱源ツリー上の段階（1=直火、2=囲い、3=ふいご…）。
@export var tier: int = 1

## 温度軸の天井（℃）。FireSim の温度と ReactionSim.heat() はこれを超えない。
@export var max_temperature: float = 600.0

## 火力を上げる操作。
@export var input_mode: InputMode = InputMode.FEED_TIMING

## 操作 1 単位が火勢(drive)に与える量。
## FEED_TIMING: 使わない（タイミング判定が火勢を決める）
## FAN_SLIDE:   スライド距離 1 単位あたり
## BELLOWS_HOLD: 押し続けた 1 秒あたり
@export var input_gain: float = 1.0

## 操作をやめたときに火勢が 1 秒あたり失われる量。大きいほど手を止めると衰えやすい。
@export var drive_decay: float = 0.5

## 燃料がある限り保たれる火勢の下限（何もしなくても燃えている分）。火が消えると 0 になる。
@export var idle_drive: float = 0.15

## 燃料の消費速度（1 秒あたり、火勢ゼロでも消える分）。
@export var fuel_burn_rate: float = 0.02

## 火勢が最大のときに追加で消費する燃料（1 秒あたり）。
@export var drive_burn_rate: float = 0.10

## 温度が平衡値へ寄る時間（秒）。小さいほど追従が速い。
@export var response_time: float = 1.1

## 解禁条件となる設備・技術 id（レシピ逆算で下位ティアを要求する）。
@export var tech_id: StringName = &""
