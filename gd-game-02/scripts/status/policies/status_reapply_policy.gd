class_name StatusReapplyPolicy
extends Resource

@export var per_source: bool = false

func is_valid() -> bool:
	return true

func instance_key(id: StringName, source: StringName) -> String:
	# Structured encoding avoids collisions from punctuation in content IDs.
	return JSON.stringify([String(id), String(source) if per_source else ""])

# Return current (updated), incoming (replace), or null (reject).
# Policies operate only on instance data; never publish signals or alter nodes.
func resolve(_current: StatusEffectInstance, _incoming: StatusEffectInstance) -> StatusEffectInstance:
	return null
