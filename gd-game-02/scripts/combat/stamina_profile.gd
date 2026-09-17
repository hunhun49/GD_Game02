class_name StaminaProfile
extends Resource

@export_range(1.0, 10000.0) var maximum: float = 100.0
@export_range(0.0, 1000.0) var recovery_per_second: float = 18.0
@export_range(0.0, 30.0) var recovery_delay: float = 1.0

func is_valid() -> bool:
	return is_finite(maximum) and maximum > 0 and is_finite(recovery_per_second) and recovery_per_second >= 0 and is_finite(recovery_delay) and recovery_delay >= 0
