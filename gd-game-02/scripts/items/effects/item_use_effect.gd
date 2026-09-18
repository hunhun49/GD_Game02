class_name ItemUseEffect
extends Resource

# Immutable configuration. Inventory consumes only after a successful effect.
func is_valid() -> bool:
	return false

func unavailable_reason(_context: ItemUseContext) -> String:
	return "사용할 수 없는 아이템입니다."

func apply(_context: ItemUseContext) -> bool:
	return false
