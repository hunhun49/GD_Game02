class_name RestoreNeedsItemEffect
extends ItemUseEffect

@export var nutrition: ConsumableDefinition

func is_valid() -> bool:
	return nutrition != null and nutrition.is_valid()

func unavailable_reason(context: ItemUseContext) -> String:
	if not context.available() or context.needs == null:
		return "지금은 섭취할 수 없습니다."
	var values := context.needs.values(context.actor().character_id)
	if values.is_empty():
		return "신체 상태를 확인할 수 없습니다."
	if (nutrition.hunger_relief > 0 and values.hunger > 0) or (nutrition.thirst_relief > 0 and values.thirst > 0):
		return ""
	return "이미 충분히 먹고 마셨습니다."

func apply(context: ItemUseContext) -> bool:
	return unavailable_reason(context).is_empty() and context.needs.consume(context.actor().character_id, nutrition)
