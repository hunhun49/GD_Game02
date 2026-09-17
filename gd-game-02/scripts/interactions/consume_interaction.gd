class_name ConsumeInteraction
extends InteractionAction

@export var item: ConsumableDefinition

func can_interact(context: InteractionContext) -> bool:
	var needs := context.actor.get_node_or_null("Needs") as NeedsComponent
	return item != null and item.is_valid() and needs != null and not needs.values().is_empty()

func _execute(context: InteractionContext) -> bool:
	var needs := context.actor.get_node("Needs") as NeedsComponent
	if not needs.consume(item):
		return false
	context.notification_requested.emit("%s 섭취 완료" % item.display_name)
	return true
