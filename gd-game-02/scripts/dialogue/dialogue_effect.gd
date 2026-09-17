class_name DialogueEffect
extends RefCounted

var type: StringName
var parameters: Dictionary

func _init(p_type: StringName = &"", p_parameters: Dictionary = {}) -> void:
	type = p_type
	parameters = p_parameters.duplicate(true)

func copy() -> DialogueEffect:
	return DialogueEffect.new(type, parameters)
