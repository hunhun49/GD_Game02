class_name DamageType
extends RefCounted

# Independent of AttackDefinition.Kind (the defense/counter rule).
enum Type { GENERIC, SLASH, BLUNT, PIERCE, FIRE, POISON, BLEED }

static func is_valid(value: int) -> bool:
	return value in Type.values()
