class_name NeedsState
extends RefCounted

var hunger: float = 0.0
var thirst: float = 0.0
var fatigue: float = 0.0
var last_updated_minutes: float = -1.0

func snapshot() -> Dictionary:
	return {"hunger": hunger, "thirst": thirst, "fatigue": fatigue, "last_updated_minutes": last_updated_minutes}

func restore(data: Dictionary) -> bool:
	if data.size() != 4:
		return false
	for key in ["hunger", "thirst", "fatigue"]:
		var value: Variant = data.get(key)
		if not DataValidation.is_finite_number(value) or value < 0 or value > 100:
			return false
	var time: Variant = data.get("last_updated_minutes")
	if not DataValidation.is_finite_number(time) or (time < 0 and time != -1):
		return false
	hunger = data.hunger
	thirst = data.thirst
	fatigue = data.fatigue
	last_updated_minutes = time
	return true
