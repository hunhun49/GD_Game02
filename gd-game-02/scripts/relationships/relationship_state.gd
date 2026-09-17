class_name RelationshipState
extends RefCounted

const MIN_AFFINITY: float = -100.0
const MAX_AFFINITY: float = 100.0
var affinity: float = 0.0

func _init(value: float = 0.0) -> void:
	affinity = value
