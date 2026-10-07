## 火にかける容器の定義（データ駆動）。土器・るつぼなど。
##
## 作業台（LabBench）で熱源の上に置くと、火の温度に遅れて追従する。
## max_temperature を超えるとひびが入る（＝「上の段階の熱には上の容器が要る」の制約解除⑥）。
class_name VesselDef
extends Resource

## 一意な識別子（例: &"clay_pot"）。
@export var id: StringName = &""

## 表示名（例: "土器"）。
@export var display_name: String = ""

## 耐えられる温度（℃）。超えるとひびが入り使えなくなる。
@export var max_temperature: float = 900.0

## 火の温度に追従する時間（秒）。大きいほど温まりにくく冷めにくい。
@export var heat_lag: float = 3.0

## 表示用スプライト名（assets/sprites/fire_<sprite>.png）。
@export var sprite: StringName = &"pot"

## 解禁条件となる設備・技術 id。
@export var tech_id: StringName = &""
