class_name DamageResult
extends RefCounted

var request: DamageRequest
var outcome: HitResolver.Outcome = HitResolver.Outcome.HIT
var health_damage: float = 0.0
var target_posture: float = 0.0
var source_posture: float = 0.0
# Filled by the receiver after health clamps overkill / rejects mutation.
var applied_health: float = 0.0

func copy() -> DamageResult:
	var result := DamageResult.new()
	result.request = request.copy() if request != null else null
	result.outcome = outcome
	result.health_damage = health_damage
	result.target_posture = target_posture
	result.source_posture = source_posture
	result.applied_health = applied_health
	return result
