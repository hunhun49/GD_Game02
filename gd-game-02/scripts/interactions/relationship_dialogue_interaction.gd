class_name RelationshipDialogueInteraction
extends DialogueInteraction

@export var from_id: StringName
@export var to_id: StringName = &"player"
@export_range(-100.0, 100.0) var minimum_affinity: float = 5.0
@export var matched_dialogue_id: StringName

func can_interact(context: InteractionContext) -> bool:
	return super.can_interact(context) and RelationshipGraph.valid_pair(from_id, to_id) and is_finite(minimum_affinity) and not matched_dialogue_id.is_empty()

func _execute(context: InteractionContext) -> bool:
	var id := matched_dialogue_id if context.session.relationships.get_affinity(from_id, to_id) >= minimum_affinity else dialogue_id
	context.dialogue_requested.emit(id)
	return true
