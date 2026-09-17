class_name DialogueInteraction
extends InteractionAction

@export var dialogue_id: StringName

func can_interact(_context: InteractionContext) -> bool:
	return not dialogue_id.is_empty()

func _execute(context: InteractionContext) -> bool:
	context.dialogue_requested.emit(dialogue_id)
	return true
