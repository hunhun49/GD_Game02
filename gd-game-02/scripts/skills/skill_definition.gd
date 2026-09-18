class_name SkillDefinition
extends Resource

@export var skill_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var attack: AttackDefinition
# Reuse cooldown is independent of attack animation/recovery.
@export var cooldown_seconds: float = 0.0

func is_valid() -> bool:
	return not skill_id.is_empty() and attack != null and attack.is_valid() and is_finite(cooldown_seconds) and cooldown_seconds >= 0
