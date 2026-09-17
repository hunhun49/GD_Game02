class_name NeedsProfile
extends Resource

@export_range(0.0, 100.0) var initial_hunger: float = 20.0
@export_range(0.0, 100.0) var initial_thirst: float = 15.0
@export_range(0.0, 100.0) var initial_fatigue: float = 10.0
@export_range(0.0, 100.0) var hunger_per_hour: float = 4.0
@export_range(0.0, 100.0) var thirst_per_hour: float = 6.0
@export_range(0.0, 100.0) var fatigue_per_hour: float = 3.0
@export_range(0.0, 100.0) var rest_recovery_per_hour: float = 12.0
@export_range(0.0, 100.0) var sleep_recovery_per_hour: float = 20.0

func is_valid() -> bool:
	for value in [initial_hunger, initial_thirst, initial_fatigue, hunger_per_hour, thirst_per_hour, fatigue_per_hour, rest_recovery_per_hour, sleep_recovery_per_hour]:
		if not is_finite(value) or value < 0 or value > 100:
			return false
	return true
