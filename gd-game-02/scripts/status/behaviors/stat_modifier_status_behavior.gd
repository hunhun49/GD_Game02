class_name StatModifierStatusBehavior
extends StatusBehavior

@export var stat: StringName = &"movement_speed"
@export var group: StringName = &"status_speed"
@export_range(0.1, 3.0) var factor: float = 1.0
@export var scale_with_stacks: bool = false

func is_valid() -> bool:
	return not stat.is_empty() and not group.is_empty() and is_finite(factor) and factor >= 0.1 and factor <= 3.0

func contribute(modifiers: StatusModifiers, stacks: int) -> void:
	modifiers.add_multiplier(stat, group, pow(factor, stacks) if scale_with_stacks else factor)
