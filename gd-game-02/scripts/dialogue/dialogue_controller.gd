class_name DialogueController
extends Node

# Scene adapter only: runner/catalog remain usable without a SceneTree.
signal effect_failed(id: StringName)

var _runner: DialogueRunner
var _effects: DialogueEffectRegistry
var _player: SchoolCharacter
var _detector: InteractionDetector
var _view: DialogueView
var _pause_locks: NodePauseLocks
var _zone: Node
var _input_token: int = 0
var _pause_token: int = 0
var _clock: GameClock
var _clock_token: int = 0
var _health: HealthComponent
var _invulnerability_token: int = 0

func configure(repository: DialogueRepository, effects: DialogueEffectRegistry, player: SchoolCharacter, detector: InteractionDetector, view: DialogueView, pause_locks: NodePauseLocks, clock: GameClock = null) -> void:
	assert(_runner == null, "DialogueController is configured once by its composition root.")
	_effects = effects
	_player = player
	_health = player.get_node_or_null("Health") as HealthComponent
	_detector = detector
	_view = view
	_pause_locks = pause_locks
	_clock = clock
	_runner = DialogueRunner.new(repository)
	_runner.started.connect(_on_started)
	_runner.line_changed.connect(_view.present)
	_runner.finished.connect(_on_finished)
	_view.advance_requested.connect(advance)
	_view.cancel_requested.connect(cancel)

func set_zone(zone: Node) -> bool:
	if is_busy():
		return false
	_zone = zone
	return true

func is_busy() -> bool:
	return _runner != null and _runner.is_busy()

func start(id: StringName) -> Error:
	if _runner == null or not is_instance_valid(_zone) or not is_inside_tree():
		return ERR_UNCONFIGURED
	if get_tree().paused:
		return ERR_BUSY
	return _runner.start(id)

func advance() -> bool:
	return _runner.advance() if _runner != null else false

func cancel() -> bool:
	return _runner.cancel() if _runner != null else false

func _on_started(_id: StringName) -> void:
	if _health != null:
		_invulnerability_token = _health.acquire_invulnerability()
	if _clock != null:
		_clock_token = _clock.acquire_pause()
	_input_token = _player.acquire_control_lock()
	_pause_token = _pause_locks.acquire(_zone)
	_detector.clear()

func _on_finished(id: StringName, reason: DialogueRunner.EndReason, effects: Array[DialogueEffect]) -> void:
	# Keep the session locked until all completion effects have been dispatched.
	var successful := true
	if reason == DialogueRunner.EndReason.COMPLETED:
		successful = _effects.execute(effects)
	_release_session()
	if not successful:
		effect_failed.emit(id)

func _release_session() -> void:
	if is_instance_valid(_health):
		_health.release_invulnerability(_invulnerability_token)
	_invulnerability_token = 0
	if _clock != null:
		_clock.release_pause(_clock_token)
	_clock_token = 0
	if is_instance_valid(_view):
		_view.close()
	if _pause_locks != null:
		_pause_locks.release(_pause_token)
	_pause_token = 0
	if is_instance_valid(_player):
		_player.release_control_lock(_input_token)
	_input_token = 0

func _exit_tree() -> void:
	if _runner != null:
		_runner.cancel()
	_release_session()
	if is_instance_valid(_view):
		if _view.advance_requested.is_connected(advance):
			_view.advance_requested.disconnect(advance)
		if _view.cancel_requested.is_connected(cancel):
			_view.cancel_requested.disconnect(cancel)
