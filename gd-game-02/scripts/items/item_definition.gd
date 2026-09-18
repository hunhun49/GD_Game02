class_name ItemDefinition
extends Resource

enum Category { FOOD, MEDICINE, KEY }
@export var item_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var category: Category = Category.FOOD
@export_range(1, 999) var max_stack: int = 10
@export var icon: Texture2D
@export var use_effect: ItemUseEffect

func is_valid() -> bool:
	return not item_id.is_empty() and not display_name.strip_edges().is_empty() and category in Category.values() and max_stack >= 1 and max_stack <= 999 and (use_effect == null or use_effect.is_valid())
