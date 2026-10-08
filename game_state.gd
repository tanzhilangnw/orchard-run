extends Node

var current_level := 0
const LEVELS := [
	{"name": "01  云朵果园", "brief": "跟着奶龙穿过第一片果园，熟悉跳跃与收集。", "skin": 0},
	{"name": "02  蜂蜜暮林", "brief": "夕色落进树林，沿着高台收集熟透的橙子。", "skin": 1},
	{"name": "03  月光糖山", "brief": "最后的山路在月光下发亮，抵达山顶奖杯。", "skin": 2}
]

func advance() -> bool:
	if current_level < LEVELS.size() - 1:
		current_level += 1
		return true
	return false

func restart_campaign() -> void:
	current_level = 0
