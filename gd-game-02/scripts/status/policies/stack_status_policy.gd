class_name StackStatusPolicy
extends StatusReapplyPolicy

@export_range(1, 64) var max_stacks: int = 5
@export var refresh_duration: bool = true

func is_valid() -> bool:
	return max_stacks >= 1 and max_stacks <= 64

func resolve(current: StatusEffectInstance, _incoming: StatusEffectInstance) -> StatusEffectInstance:
	current.stacks = mini(max_stacks, current.stacks + 1)
	if refresh_duration:
		current.remaining = maxf(current.remaining, current.definition.duration_seconds)
	return current
