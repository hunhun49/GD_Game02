class_name DoorInteraction
extends InteractionAction

@export var destination_zone: String
@export var destination_spawn: String = "Entrance"

func can_interact(_context: InteractionContext) -> bool:
	return not destination_zone.is_empty() and not destination_spawn.is_empty()

func _execute(context: InteractionContext) -> bool:
	context.travel_requested.emit(destination_zone, destination_spawn)
	return true
