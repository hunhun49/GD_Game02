class_name CleanseItemEffect
extends ItemUseEffect

@export var tag: StringName

func is_valid() -> bool:
	return not tag.is_empty()

func unavailable_reason(context: ItemUseContext) -> String:
	if not context.available() or context.actor().status_effects() == null:
		return "지금은 치료할 수 없습니다."
	return "" if context.actor().status_effects().has_tag(tag) else "치료할 상태 이상이 없습니다."

func apply(context: ItemUseContext) -> bool:
	return unavailable_reason(context).is_empty() and context.actor().status_effects().cleanse(tag) > 0
