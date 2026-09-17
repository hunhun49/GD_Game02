class_name CharacterStateStore
extends RefCounted

var _states: Dictionary[StringName, CharacterState] = {}

func get_or_create(id: StringName, definition: CharacterDefinition) -> CharacterState:
	if id.is_empty() or definition == null:
		return null
	if not _states.has(id):
		var state := CharacterState.new()
		state.character_id = id
		state.current_health = definition.max_health
		_states[id] = state
	return _states[id]

func get_state(id: StringName) -> CharacterState:
	return _states.get(id)

func all_states() -> Array[CharacterState]:
	return _states.values()

func snapshot() -> Dictionary:
	var records: Array[Dictionary] = []
	for state in _states.values():
		records.append(state.snapshot())
	return {"schema_version": 3, "characters": records}

# Load before binding scene characters; replacing a bound store is disallowed.
func restore(data: Dictionary) -> bool:
	var version: Variant = data.get("schema_version")
	if not _states.is_empty() or not (version is int or version is float) or (version != 1 and version != 2 and version != 3) or not data.get("characters") is Array:
		return false
	var restored: Dictionary[StringName, CharacterState] = {}
	for record in data.characters:
		if not record is Dictionary or not record.get("character_id") is String or record.character_id.is_empty():
			return false
		if version >= 2 and not record.has("needs"):
			return false
		if version == 3 and not record.has("current_stamina"):
			return false
		var id := StringName(record.character_id)
		if restored.has(id):
			return false
		var state := CharacterState.new()
		state.character_id = id
		if not state.restore(record):
			return false
		restored[id] = state
	_states = restored
	return true
