class_name TrainingResetInteraction
extends InteractionAction

@export var target_id: StringName = &"training_dummy"

func _execute(context: InteractionContext) -> bool:
	# Restrict reset to a training target in this actor's combat scope.
	var source := context.actor.get_node_or_null("Combat") as CombatComponent
	if source == null or not is_instance_valid(source.get_scope()):
		return false
	for node in context.actor.get_tree().get_nodes_in_group("combatants"):
		var combat := node as CombatComponent
		if combat == null or combat.actor().character_id != target_id or combat.get_scope() != source.get_scope():
			continue
		var controller := combat.actor().controller as TrainingController
		if controller == null:
			return false
		controller.reset_training()
		var health := combat.health()
		if health == null:
			return false
		if health.current() <= 0:
			health.revive(health.maximum())
		else:
			health.heal(health.maximum())
		context.notification_requested.emit("훈련 대상 회복 완료 · J / 패드 B로 공격하세요.")
		return true
	return false
