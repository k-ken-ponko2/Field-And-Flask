## カレンダー・季節（設計書 §5, §8）。純粋ロジック、エンジン非依存。
##
## 時間を消費するのは「遠征」と「本番生産」だけ（§6）。実験室では advance を呼ばない、
## という運用で「テンポの衝突」を回避する。ここはその時間管理の土台。
class_name GameCalendar
extends RefCounted

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const DAYS_PER_SEASON := 28
const SEASONS_PER_YEAR := 4
const DAYS_PER_YEAR := DAYS_PER_SEASON * SEASONS_PER_YEAR

## 0 起点の通算日数。
var total_day: int = 0

## 日数を進める（遠征や本番生産で消費）。負の値は無視して 0 未満にはしない。
func advance(days: int) -> void:
	total_day = maxi(0, total_day + days)

## 現在の季節。
func season() -> Season:
	return (total_day / DAYS_PER_SEASON) % SEASONS_PER_YEAR

## 季節内の日（1〜DAYS_PER_SEASON）。
func day_of_season() -> int:
	return total_day % DAYS_PER_SEASON + 1

## 通算年（1 起点）。
func year() -> int:
	return total_day / DAYS_PER_YEAR + 1
