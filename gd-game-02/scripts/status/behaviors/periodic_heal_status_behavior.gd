class_name PeriodicHealStatusBehavior
extends PeriodicStatusBehavior

@export var amount: float = 3.0

func is_valid() -> bool:
	return super.is_valid() and is_finite(amount) and amount > 0

func pulse(context: StatusEffectContext) -> void:
	context.heal(amount * context.instance.stacks)
