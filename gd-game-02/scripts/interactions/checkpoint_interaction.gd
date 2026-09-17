class_name CheckpointInteraction
extends InteractionAction

func _execute(context: InteractionContext) -> bool:
	context.checkpoint_requested.emit(context.actor.global_position)
	return true
