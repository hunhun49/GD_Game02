class_name DialogueRunner
extends RefCounted

signal started(id: StringName)
signal line_changed(line: DialogueLine, index: int, total: int)
signal finished(id: StringName, reason: EndReason, effects: Array[DialogueEffect])

enum State { IDLE, ACTIVE, FINISHING }
enum EndReason { COMPLETED, CANCELLED }

var _repository: DialogueRepository
var _state: State = State.IDLE
var _definition: DialogueDefinition
var _index: int = 0
var _dispatching: bool = false

func _init(repository: DialogueRepository) -> void:
	_repository = repository

func is_busy() -> bool:
	return _state != State.IDLE or _dispatching

func active_id() -> StringName:
	return _definition.id if _definition != null else &""

func start(id: StringName) -> Error:
	if is_busy():
		return ERR_BUSY
	if not _repository.is_loaded():
		return ERR_UNCONFIGURED
	var definition := _repository.get_dialogue(id)
	if definition == null:
		return ERR_DOES_NOT_EXIST
	_definition = definition
	_index = 0
	_state = State.ACTIVE
	_dispatching = true
	started.emit(id)
	_emit_line()
	_dispatching = false
	return OK

func advance() -> bool:
	if _state != State.ACTIVE or _dispatching:
		return false
	_dispatching = true
	_index += 1
	if _index == _definition.lines.size():
		_finish(EndReason.COMPLETED)
	else:
		_emit_line()
	_dispatching = false
	return true

func cancel() -> bool:
	if _state != State.ACTIVE or _dispatching:
		return false
	_dispatching = true
	_finish(EndReason.CANCELLED)
	_dispatching = false
	return true

func _emit_line() -> void:
	line_changed.emit(_definition.lines[_index].copy(), _index, _definition.lines.size())

func _finish(reason: EndReason) -> void:
	_state = State.FINISHING
	var id := _definition.id
	var effects: Array[DialogueEffect] = []
	if reason == EndReason.COMPLETED:
		for effect in _definition.on_complete:
			effects.append(effect.copy())
	_definition = null
	_index = 0
	finished.emit(id, reason, effects)
	_state = State.IDLE
