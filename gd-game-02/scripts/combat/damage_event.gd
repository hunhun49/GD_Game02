class_name DamageEvent
extends RefCounted

var source_id: StringName
var amount: float
var damage_type: DamageType.Type = DamageType.Type.GENERIC
var attack_id: StringName
var emitter_id: int
var sequence: int

func _init(source: StringName, damage: float) -> void:
	source_id = source
	amount = damage

func copy() -> DamageEvent:
	var result := DamageEvent.new(source_id, amount)
	result.damage_type = damage_type
	result.attack_id = attack_id
	result.emitter_id = emitter_id
	result.sequence = sequence
	return result

static func from_result(result: DamageResult) -> DamageEvent:
	var event := DamageEvent.new(result.request.source_id, result.health_damage)
	event.damage_type = result.request.damage_type
	event.attack_id = result.request.attack_id
	event.emitter_id = result.request.emitter_id
	event.sequence = result.request.sequence
	return event
