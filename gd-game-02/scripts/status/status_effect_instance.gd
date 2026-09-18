class_name StatusEffectInstance
extends RefCounted

var definition: StatusEffectDefinition
var source_id: StringName
var remaining: float
var stacks: int = 1
var key: String
# Separate dictionaries even if one Resource occurs twice in an effect list.
var behavior_states: Array[Dictionary] = []
var entered: Array[bool] = []

func _init(settings: StatusEffectDefinition, source: StringName) -> void:
	definition = settings.duplicate(true) as StatusEffectDefinition
	source_id = source
	remaining = definition.duration_seconds
	key = definition.reapply_policy.instance_key(definition.status_id, source)
	for behavior in definition.behaviors:
		behavior_states.append({})
		entered.append(false)

func snapshot() -> Dictionary:
	return {"id": definition.status_id, "name": definition.display_name, "remaining": remaining,
		"source_id": source_id, "stacks": stacks, "presentation_key": definition.presentation_key, "color": definition.color}
