class_name HitResolver
extends RefCounted

# Pure policy. Eligibility (geometry, timing and source identity) is checked by combat.
enum Outcome { HIT, BLOCK, DEFLECT, DODGE, DASH_PARRY, CLASH }

static func resolve(blockable: bool, covered: bool, timed: bool) -> Outcome:
	return resolve_kind(AttackDefinition.Kind.NORMAL if blockable else AttackDefinition.Kind.RED, covered, timed)

static func resolve_kind(kind: AttackDefinition.Kind, covered: bool, timed: bool, evading: bool = false, dash_counter: bool = false, clash: bool = false) -> Outcome:
	match kind:
		AttackDefinition.Kind.PURPLE:
			return Outcome.CLASH if clash else Outcome.HIT
		AttackDefinition.Kind.RED:
			return Outcome.DASH_PARRY if dash_counter else Outcome.HIT
	if evading:
		return Outcome.DODGE
	if not covered:
		return Outcome.HIT
	return Outcome.DEFLECT if timed else Outcome.BLOCK
