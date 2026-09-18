class_name ItemUseContext
extends RefCounted

var _actor: WeakRef
var needs: NeedsService
var allow_paused: bool

func _init(actor: SchoolCharacter, needs_service: NeedsService, paused_use: bool = false) -> void:
	_actor = weakref(actor)
	needs = needs_service
	allow_paused = paused_use

func actor() -> SchoolCharacter:
	return _actor.get_ref() as SchoolCharacter

func available() -> bool:
	var target := actor()
	return is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion() and target.state != null and target.state.activity == CharacterState.Activity.ACTIVE and target.state.current_health > 0 and not target.is_action_locked(SchoolCharacter.Action.INTERACT) and (target.can_process() or (allow_paused and target.get_tree().paused))

func health() -> HealthComponent:
	return actor().get_node_or_null("Health") as HealthComponent if is_instance_valid(actor()) else null
