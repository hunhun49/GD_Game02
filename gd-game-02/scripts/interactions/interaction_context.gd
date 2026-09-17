class_name InteractionContext
extends RefCounted

signal notification_requested(message: String)
signal dialogue_requested(id: StringName)
signal travel_requested(zone: String, spawn: String)
signal checkpoint_requested(position: Vector2)

var actor: SchoolCharacter
var session: SessionState

func _init(acting_character: SchoolCharacter, session_state: SessionState) -> void:
	actor = acting_character
	session = session_state
