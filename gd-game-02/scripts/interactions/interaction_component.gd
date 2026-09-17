class_name InteractionComponent
extends Node2D

signal focus_changed(value: bool)

@export var display_name: String
@export var action_text: String = "조사하기"
@export var action: InteractionAction
@export_range(1.0, 500.0) var interaction_radius: float = 90.0
@export var enabled: bool = true
var focused: bool = false:
	set(value):
		if focused != value:
			focused = value
			focus_changed.emit(value)

func _ready() -> void:
	add_to_group("interactables")

func target_name() -> String:
	if not display_name.is_empty():
		return display_name
	var character := get_parent() as SchoolCharacter
	return character.definition.display_name if character != null and character.definition != null else ""

func get_prompt(_context: InteractionContext) -> String:
	return action_text

func can_interact(context: InteractionContext) -> bool:
	if context == null or not is_instance_valid(context.actor) or context.session == null or action == null:
		return false
	var actor := context.actor
	if not enabled or not is_inside_tree() or is_queued_for_deletion() or not can_process() or not is_visible_in_tree() or not actor.can_act(SchoolCharacter.Action.INTERACT):
		return false
	var body := get_parent() as CollisionObject2D
	if body == actor or (body != null and body.is_queued_for_deletion()):
		return false
	if get_world_2d() != actor.get_world_2d():
		return false
	var offset := global_position - actor.global_position
	if offset.length() > interaction_radius:
		return false
	if offset.length() > 8.0 and offset.normalized().dot(actor.facing) < -0.15:
		return false
	var ray := PhysicsRayQueryParameters2D.create(actor.global_position, global_position, 1)
	ray.exclude = [actor.get_rid()]
	if body != null:
		ray.exclude = [actor.get_rid(), body.get_rid()]
	if not actor.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		return false
	return action.can_interact(context)

func interact(context: InteractionContext) -> bool:
	# Revalidate on execution: the target may have moved/disabled since focus.
	return action.execute(context) if can_interact(context) else false
