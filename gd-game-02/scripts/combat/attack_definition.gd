class_name AttackDefinition
extends Resource

@export var on_hit_statuses: Array[StatusEffectDefinition] = []
@export var attack_id: StringName
@export var damage_type: DamageType.Type = DamageType.Type.GENERIC

enum Kind { NORMAL, BLUE, RED, PURPLE }
@export var kind: Kind = Kind.NORMAL
@export var clash_recovery_seconds: float = 0.3

@export_range(0.0, 1000.0) var stamina_cost: float = 0.0
@export_range(0.1, 10000.0) var damage: float = 12.0
@export_range(1.0, 500.0) var reach: float = 85.0
@export_range(1.0, 360.0) var arc_degrees: float = 100.0
@export var windup_seconds: float = 0.12
@export var active_seconds: float = 0.06
@export var recovery_seconds: float = 0.22
@export var guard_cancel_seconds: float = 0.06
@export var posture_damage: float = 8.0
@export var guard_posture_damage: float = 18.0
@export var deflect_posture_damage: float = 12.0
@export var blockable: bool = true
# Kept for existing resources; total action length is at least this duration.
@export_range(0.05, 10.0) var cooldown_seconds: float = 0.4

func is_valid() -> bool:
	for effect in on_hit_statuses:
		if effect == null or not effect.is_valid():
			return false
	for value in [clash_recovery_seconds, stamina_cost, damage, reach, arc_degrees, cooldown_seconds, windup_seconds, active_seconds, recovery_seconds, guard_cancel_seconds, posture_damage, guard_posture_damage, deflect_posture_damage]:
		if not is_finite(value) or value < 0:
			return false
	return DamageType.is_valid(damage_type) and kind in [Kind.NORMAL, Kind.BLUE, Kind.RED, Kind.PURPLE] and clash_recovery_seconds > 0 and damage > 0 and reach > 0 and arc_degrees > 0 and arc_degrees <= 360 and cooldown_seconds > 0 and windup_seconds > 0 and active_seconds > 0 and recovery_seconds > 0 and guard_cancel_seconds <= windup_seconds

func effective_kind() -> Kind:
	# Legacy unblockable resources remain red until explicitly migrated.
	return Kind.RED if kind == Kind.NORMAL and not blockable else kind
