class_name DialogueEffectHandler
extends RefCounted

# Extend this boundary for inventory/quest effects. Validation must have no effects.
# Return an empty string only for a complete, valid payload.
func validate(_parameters: Dictionary) -> String:
	return "Effect handler must implement validate()."

func apply(_parameters: Dictionary) -> void:
	push_error("Effect handler must implement apply().")
