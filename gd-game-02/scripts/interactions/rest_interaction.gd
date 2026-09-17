class_name RestInteraction
extends InteractionAction

@export_range(1.0, 1440.0) var minutes: float = 30.0
@export var sleeping: bool = false

func can_interact(context: InteractionContext) -> bool:
	var needs := context.actor.get_node_or_null("Needs") as NeedsComponent
	return is_finite(minutes) and minutes > 0 and minutes <= 1440 and needs != null and not needs.values().is_empty()

func _execute(context: InteractionContext) -> bool:
	var needs := context.actor.get_node("Needs") as NeedsComponent
	if not needs.rest(minutes, sleeping):
		return false
	context.notification_requested.emit("%d분 %s 완료 · 시간이 지났습니다." % [int(minutes), "수면" if sleeping else "휴식"])
	return true
