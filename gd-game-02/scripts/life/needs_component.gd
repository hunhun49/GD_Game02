class_name NeedsComponent
extends Node

signal changed(hunger: float, thirst: float, fatigue: float)
var _service: NeedsService
var _character_id: StringName

func configure(service: NeedsService, id: StringName, profile: NeedsProfile) -> void:
	_disconnect()
	_character_id = id
	if profile == null:
		return
	_service = service
	_service.changed.connect(_on_changed)
	if not _service.register_character(id, profile):
		_disconnect()

func values() -> Dictionary:
	return _service.values(_character_id) if _service != null else {}

func consume(item: ConsumableDefinition) -> bool:
	var actor := get_parent() as SchoolCharacter
	return actor.can_act(SchoolCharacter.Action.INTERACT) and _service != null and _service.consume(_character_id, item)

func rest(minutes: float, sleeping: bool = false) -> bool:
	var actor := get_parent() as SchoolCharacter
	if not actor.can_act(SchoolCharacter.Action.INTERACT) or _service == null:
		return false
	var token := actor.acquire_control_lock()
	var result := _service.rest(_character_id, minutes, sleeping)
	if is_instance_valid(actor):
		if result:
			var stamina := actor.get_node_or_null("Stamina") as StaminaComponent
			if stamina != null:
				stamina.restore_full()
		actor.release_control_lock(token)
	return result

func _on_changed(id: StringName, hunger: float, thirst: float, fatigue: float) -> void:
	if id == _character_id:
		changed.emit(hunger, thirst, fatigue)

func _disconnect() -> void:
	if _service != null and _service.changed.is_connected(_on_changed):
		_service.changed.disconnect(_on_changed)
	_service = null

func _exit_tree() -> void:
	_disconnect()
