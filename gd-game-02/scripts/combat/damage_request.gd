class_name DamageRequest
extends RefCounted

# A value snapshot. No character/node/resource references travel through calculation.
const FIELDS: Array[StringName] = [&"source_id", &"target_id", &"attack_id", &"emitter_id", &"sequence", &"damage_type", &"kind", &"amount", &"hit_posture", &"guard_posture", &"deflect_posture", &"execution"]

var source_id: StringName
var target_id: StringName
var attack_id: StringName
var emitter_id: int
var sequence: int
var damage_type: DamageType.Type = DamageType.Type.GENERIC
var kind: AttackDefinition.Kind = AttackDefinition.Kind.NORMAL
var amount: float = 0.0
var hit_posture: float = 0.0
var guard_posture: float = 0.0
var deflect_posture: float = 0.0
var execution: bool = false

static func from_attack(source: StringName, target: StringName, definition: AttackDefinition, emitter: int, serial: int) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = source
	request.target_id = target
	request.attack_id = definition.attack_id
	request.emitter_id = emitter
	request.sequence = serial
	request.damage_type = definition.damage_type
	request.kind = definition.effective_kind()
	request.amount = definition.damage
	request.hit_posture = definition.posture_damage
	request.guard_posture = definition.guard_posture_damage
	request.deflect_posture = definition.deflect_posture_damage
	return request

func is_valid() -> bool:
	if source_id.is_empty() or target_id.is_empty() or not DamageType.is_valid(damage_type) or kind not in AttackDefinition.Kind.values():
		return false
	for value in [amount, hit_posture, guard_posture, deflect_posture]:
		if not is_finite(value) or value < 0:
			return false
	return true

func copy() -> DamageRequest:
	var result := DamageRequest.new()
	for field in FIELDS:
		result.set(field, get(field))
	return result

func matches(other: DamageRequest) -> bool:
	if other == null:
		return false
	for field in FIELDS:
		if get(field) != other.get(field):
			return false
	return true
