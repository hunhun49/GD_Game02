class_name AttackDefinition
extends Resource

@export_range(0.0, 1000.0) var stamina_cost: float = 0.0
@export_range(0.1, 10000.0) var damage: float = 25.0
@export_range(1.0, 500.0) var reach: float = 85.0
@export_range(1.0, 360.0) var arc_degrees: float = 100.0
@export_range(0.05, 10.0) var cooldown_seconds: float = 0.45

func is_valid() -> bool:
	return is_finite(stamina_cost) and stamina_cost >= 0 and is_finite(damage) and damage > 0 and is_finite(reach) and reach > 0 and is_finite(arc_degrees) and arc_degrees > 0 and arc_degrees <= 360 and is_finite(cooldown_seconds) and cooldown_seconds > 0
