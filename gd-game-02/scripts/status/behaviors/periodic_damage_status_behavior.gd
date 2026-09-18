class_name PeriodicDamageStatusBehavior
extends PeriodicStatusBehavior

@export var amount: float = 3.0
@export var damage_type: DamageType.Type = DamageType.Type.GENERIC

func is_valid() -> bool:
	return super.is_valid() and is_finite(amount) and amount > 0 and DamageType.is_valid(damage_type)

func pulse(context: StatusEffectContext) -> void:
	context.deal_damage(amount * context.instance.stacks, damage_type, context.state.sequence)
