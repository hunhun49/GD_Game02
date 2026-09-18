class_name DamageResolver
extends RefCounted

# Pure calculation; callers validate contact/defense and apply the returned values.
static func resolve(request: DamageRequest, outcome: HitResolver.Outcome, defense: DefenseProfile = null) -> DamageResult:
	if request == null or not request.is_valid() or outcome not in HitResolver.Outcome.values() or (defense != null and not defense.is_valid()):
		return null
	var result := DamageResult.new()
	result.request = request.copy()
	result.outcome = outcome
	match outcome:
		HitResolver.Outcome.HIT:
			var armor := defense.armor if defense != null else 0.0
			var resistance := defense.resistance(request.damage_type) if defense != null else 0.0
			result.health_damage = request.amount if request.execution else maxf(0, request.amount - armor) * (1.0 - resistance)
			result.target_posture = 0.0 if request.execution else request.hit_posture
		HitResolver.Outcome.BLOCK:
			result.target_posture = request.guard_posture * (3.0 if request.kind == AttackDefinition.Kind.BLUE else 1.0)
		HitResolver.Outcome.DEFLECT:
			result.source_posture = request.deflect_posture
		HitResolver.Outcome.DASH_PARRY:
			result.source_posture = request.deflect_posture * 2.0
	for value in [result.health_damage, result.target_posture, result.source_posture]:
		if not is_finite(value):
			return null
	return result

# Already-applied ailments bypass guard/dodge and flat armor, but retain typed
# resistance and HealthComponent invulnerability. Never request melee contact.
static func resolve_periodic(request: DamageRequest, defense: DefenseProfile = null) -> DamageResult:
	if request == null or request.execution or (defense != null and not defense.is_valid()):
		return null
	var periodic_defense := defense.duplicate(true) as DefenseProfile if defense != null else null
	if periodic_defense != null:
		periodic_defense.armor = 0.0
	return resolve(request, HitResolver.Outcome.HIT, periodic_defense)
