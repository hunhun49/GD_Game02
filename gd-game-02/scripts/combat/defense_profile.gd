class_name DefenseProfile
extends Resource

@export var armor: float = 0.0
# 0.25 = 25% reduction, 1 = immunity, -0.5 = 50% vulnerability.
@export var resistances: Dictionary[int, float] = {}

func is_valid() -> bool:
	if not is_finite(armor) or armor < 0:
		return false
	for type in resistances:
		if not DamageType.is_valid(type) or not is_finite(resistances[type]) or resistances[type] < -1 or resistances[type] > 1:
			return false
	return true

func resistance(type: DamageType.Type) -> float:
	return resistances.get(type, 0.0)
