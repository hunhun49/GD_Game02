class_name RelationshipService
extends RefCounted

signal affinity_changed(from_id: StringName, to_id: StringName, previous: float, current: float)
var _graph := RelationshipGraph.new()

func get_affinity(from_id: StringName, to_id: StringName) -> float:
	return _graph.affinity(from_id, to_id)

func add_affinity(from_id: StringName, to_id: StringName, amount: float) -> bool:
	if not is_finite(amount):
		return false
	return set_affinity(from_id, to_id, get_affinity(from_id, to_id) + amount)

func set_affinity(from_id: StringName, to_id: StringName, value: float) -> bool:
	if not RelationshipGraph.valid_pair(from_id, to_id) or not is_finite(value):
		return false
	var previous := get_affinity(from_id, to_id)
	var current := clampf(value, RelationshipState.MIN_AFFINITY, RelationshipState.MAX_AFFINITY)
	if previous == current:
		return true
	_graph._write(from_id, to_id, current)
	affinity_changed.emit(from_id, to_id, previous, current)
	return true

func snapshot() -> Dictionary:
	return _graph.snapshot()

func restore(data: Dictionary) -> bool:
	return _graph.restore(data)
