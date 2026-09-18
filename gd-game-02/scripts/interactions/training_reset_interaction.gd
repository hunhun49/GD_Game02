class_name TrainingResetInteraction
extends InteractionAction

@export var reset_all_training: bool = false
@export var target_id: StringName = &"training_dummy"

func _execute(context: InteractionContext) -> bool:
	# Restrict reset to a training target in this actor's combat scope.
	var source := context.actor.get_node_or_null("Combat") as CombatComponent
	if source == null or not is_instance_valid(source.get_scope()):
		return false
	var targets: Array[CombatComponent] = []
	for node in context.actor.get_tree().get_nodes_in_group("combatants"):
		var combat := node as CombatComponent
		if combat == null or (not reset_all_training and combat.actor().character_id != target_id) or combat.get_scope() != source.get_scope():
			continue
		var controller := combat.actor().controller as TrainingController
		if controller != null and combat.health() != null:
			targets.append(combat)
	if targets.is_empty():
		return false
	if source.resolver() != null:
		source.resolver().clear()
	source.reset_encounter()
	if context.actor.status_effects() != null:
		context.actor.status_effects().clear()
	for combat in targets:
		if combat.actor().status_effects() != null:
			combat.actor().status_effects().clear()
		(combat.actor().controller as TrainingController).reset_training()
		var health := combat.health()
		if health.current() <= 0:
			health.revive(health.maximum())
		else:
			health.heal(health.maximum())
	context.notification_requested.emit("훈련 초기화 · 파랑: 튕김 · 빨강: Shift 돌진 · 보라: Q 상쇄")
	return true
