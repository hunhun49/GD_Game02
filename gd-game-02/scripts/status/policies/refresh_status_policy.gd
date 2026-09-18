class_name RefreshStatusPolicy
extends StatusReapplyPolicy

func resolve(current: StatusEffectInstance, _incoming: StatusEffectInstance) -> StatusEffectInstance:
	current.remaining = maxf(current.remaining, current.definition.duration_seconds)
	return current
