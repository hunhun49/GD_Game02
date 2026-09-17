class_name GameCoordinator
extends Node

var _world: InGame
var _ui: GameUI
var _dialogue: DialogueController
var _owns_pause: bool = false
var _clock: GameClock
var _pause_clock_token: int = 0
var _configured: bool = false
var _connections: Array[Dictionary] = []

func configure(world: InGame, ui: GameUI, dialogue: DialogueController, state: SessionState, pause_locks: NodePauseLocks, sources: PackedStringArray) -> void:
	assert(not _configured, "GameCoordinator is configured once.")
	_configured = true
	_world = world
	_clock = state.clock
	_ui = ui
	_dialogue = dialogue
	var effects := DialogueEffectRegistry.new()
	effects.register_handler(&"set_flag", SetFlagDialogueEffect.new(state))
	effects.register_handler(&"add_affinity", AffinityDialogueEffect.new(state))
	var notifications := NotifyDialogueEffect.new()
	_bind(notifications.notification_requested, _ui.show_status)
	effects.register_handler(&"notify", notifications)
	effects.seal()
	var repository := DialogueRepository.new(effects)
	var content_ready := repository.load_files(sources)
	_dialogue.configure(repository, effects, _world.get_player(), _world.get_detector(), _ui.get_dialogue_view(), pause_locks, state.clock)
	_bind(_dialogue.effect_failed, _on_dialogue_effect_failed)
	_world.configure(state, _prepare_zone_change)
	_bind(_world.health_changed, _ui.show_health)
	_bind(_world.stamina_changed, _ui.show_stamina)
	_bind(_world.clock_changed, _ui.show_clock)
	_bind(_world.needs_changed, _ui.show_needs)
	_bind(state.relationships.affinity_changed, _on_affinity_changed)
	_bind(_world.zone_changed, _dialogue.set_zone)
	_bind(_world.location_changed, _ui.show_location)
	_bind(_world.movement_mode_changed, _ui.show_movement_mode)
	_bind(_world.interaction_prompt_changed, _ui.show_interaction)
	_bind(_world.status_changed, _ui.show_status)
	_bind(_world.dialogue_requested, _request_dialogue)
	_bind(_ui.pause_requested, request_pause)
	_bind(_ui.resume_requested, resume)
	_world.start()
	if not content_ready:
		push_error("Dialogue content rejected:\n" + "\n".join(repository.errors()))
		_ui.show_status("대화를 불러오지 못했습니다.")

func _bind(event: Signal, callback: Callable) -> void:
	event.connect(callback)
	_connections.append({"event": event, "callback": callback})

func _prepare_zone_change() -> bool:
	if _dialogue.is_busy() and not _dialogue.cancel():
		return false
	return _dialogue.set_zone(null)

func request_pause() -> void:
	if get_tree().paused or _dialogue.is_busy() or not _world.can_pause():
		return
	_owns_pause = true
	_pause_clock_token = _clock.acquire_pause()
	get_tree().paused = true
	_ui.set_paused(true)

func resume() -> void:
	if not _owns_pause:
		return
	_owns_pause = false
	_clock.release_pause(_pause_clock_token)
	_pause_clock_token = 0
	get_tree().paused = false
	_ui.set_paused(false)

func _request_dialogue(id: StringName) -> void:
	var result := _dialogue.start(id)
	if result != OK:
		push_warning("Cannot start dialogue '%s' (error %d)." % [id, result])
		_ui.show_status("이 대화를 시작할 수 없습니다.")

func _on_affinity_changed(from_id: StringName, to_id: StringName, previous: float, current: float) -> void:
	_ui.show_relationship("%s → %s  호감도 %+.0f (현재 %.0f)" % [_character_name(from_id), _character_name(to_id), current - previous, current])

func _character_name(id: StringName) -> String:
	# Names are content data, with an ID fallback for off-screen/unknown actors.
	for actor in _world.find_children("*", "CharacterBody2D", true, false):
		if actor is SchoolCharacter and actor.character_id == id:
			return actor.definition.display_name
	return String(id)

func _on_dialogue_effect_failed(id: StringName) -> void:
	push_error("Completion effects failed for dialogue '%s'." % id)
	_ui.show_status("대화 결과를 적용하지 못했습니다.")

func _exit_tree() -> void:
	if not _configured:
		return
	if is_instance_valid(_dialogue):
		_dialogue.cancel()
	if is_instance_valid(_world):
		_world.clear_transition_guard()
	if _owns_pause:
		_clock.release_pause(_pause_clock_token)
		_pause_clock_token = 0
		get_tree().paused = false
		_owns_pause = false
	if is_instance_valid(_ui):
		_ui.set_paused(false)
	for connection in _connections:
		var event: Signal = connection.event
		if is_instance_valid(event.get_object()) and event.is_connected(connection.callback):
			event.disconnect(connection.callback)
	_connections.clear()
	_configured = false
