class_name DamageEvent
extends RefCounted

var source_id: StringName
var amount: float

func _init(source: StringName, damage: float) -> void:
	source_id = source
	amount = damage

func copy() -> DamageEvent:
	return DamageEvent.new(source_id, amount)
