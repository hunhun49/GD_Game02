class_name StatusModifiers
extends RefCounted

var blocked_actions: int = 0
var _stats: Dictionary = {}

# Same group: strongest debuff and strongest buff. Different groups multiply.
func add_multiplier(stat: StringName, group: StringName, factor: float) -> void:
	if not _stats.has(stat):
		_stats[stat] = {}
	if not _stats[stat].has(group):
		_stats[stat][group] = Vector2.ONE
	var pair: Vector2 = _stats[stat][group]
	pair.x = minf(pair.x, factor)
	pair.y = maxf(pair.y, factor)
	_stats[stat][group] = pair

func multiplier(stat: StringName) -> float:
	var result: float = 1.0
	for pair: Vector2 in _stats.get(stat, {}).values():
		result *= pair.x * pair.y
	return clampf(result, 0.1, 3.0)
