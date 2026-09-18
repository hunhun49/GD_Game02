class_name ReplaceStatusPolicy
extends StatusReapplyPolicy

# Explicit content rank; never guess strength by examining arbitrary behaviors.
@export var require_higher_priority: bool = false

func resolve(current: StatusEffectInstance, incoming: StatusEffectInstance) -> StatusEffectInstance:
	if require_higher_priority and incoming.definition.priority <= current.definition.priority:
		return null
	return incoming
