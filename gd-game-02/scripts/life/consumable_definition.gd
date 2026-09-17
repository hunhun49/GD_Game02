class_name ConsumableDefinition
extends Resource

@export var display_name: String = "음식"
@export_range(0.0, 100.0) var hunger_relief: float = 0.0
@export_range(0.0, 100.0) var thirst_relief: float = 0.0

func is_valid() -> bool:
	return not display_name.strip_edges().is_empty() and is_finite(hunger_relief) and is_finite(thirst_relief) and hunger_relief >= 0 and thirst_relief >= 0 and hunger_relief <= 100 and thirst_relief <= 100 and hunger_relief + thirst_relief > 0
