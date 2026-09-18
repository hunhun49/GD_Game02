class_name HealItemEffect
extends ItemUseEffect

@export var amount: float = 30.0

func is_valid() -> bool:
	return is_finite(amount) and amount > 0

func unavailable_reason(context: ItemUseContext) -> String:
	if not context.available() or context.health() == null:
		return "지금은 회복할 수 없습니다."
	return "체력이 이미 가득 찼습니다." if context.health().current() >= context.health().maximum() else ""

func apply(context: ItemUseContext) -> bool:
	return unavailable_reason(context).is_empty() and context.health().heal(amount, context.allow_paused) > 0
