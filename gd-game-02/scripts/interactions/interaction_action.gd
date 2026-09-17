class_name InteractionAction
extends Resource

# Shared, immutable configuration. Per-use state belongs to context/session.
@export var required_flag: StringName
@export var locked_dialogue_id: StringName = &"locked"

func can_interact(_context: InteractionContext) -> bool:
	return true

func execute(context: InteractionContext) -> bool:
	if not can_interact(context):
		return false
	if not required_flag.is_empty() and not context.session.has_flag(required_flag):
		if locked_dialogue_id.is_empty():
			return false
		context.dialogue_requested.emit(locked_dialogue_id)
		return true
	return _execute(context)

func _execute(_context: InteractionContext) -> bool:
	return false
