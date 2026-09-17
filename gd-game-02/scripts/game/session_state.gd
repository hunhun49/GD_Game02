class_name SessionState
extends RefCounted

signal flag_changed(key: StringName, value: bool)

var characters := CharacterStateStore.new()
var relationships := RelationshipService.new()
var clock := GameClock.new()
var needs := NeedsService.new(clock, characters)
var _in_use: bool = false

var _flags: Dictionary[StringName, bool] = {}

func has_flag(key: StringName) -> bool:
	return _flags.get(key, false)

func set_flag(key: StringName, value: bool) -> void:
	if key.is_empty() or (_flags.has(key) and _flags[key] == value):
		return
	_flags[key] = value
	flag_changed.emit(key, value)

func snapshot_flags() -> Dictionary[StringName, bool]:
	return _flags.duplicate()

func mark_in_use() -> void:
	_in_use = true

func snapshot() -> Dictionary:
	return {"schema_version": 1, "flags": snapshot_flags(), "characters": characters.snapshot(), "relationships": relationships.snapshot(), "clock": clock.snapshot()}

# Restore into a fresh session before configuring a world. Commit all domains together.
func restore(data: Dictionary) -> bool:
	if _in_use or not _flags.is_empty() or not characters.all_states().is_empty() or not relationships.snapshot().edges.is_empty():
		return false
	if not DataValidation.is_finite_number(data.get("schema_version")) or data.schema_version != 1:
		return false
	for key in ["flags", "characters", "relationships", "clock"]:
		if not data.get(key) is Dictionary:
			return false
	var restored_flags: Dictionary[StringName, bool] = {}
	for key in data.flags:
		if not (key is String or key is StringName) or String(key).strip_edges().is_empty() or not data.flags[key] is bool:
			return false
		restored_flags[StringName(key)] = data.flags[key]
	var restored_characters := CharacterStateStore.new()
	var restored_relationships := RelationshipService.new()
	var restored_clock := GameClock.new()
	if not restored_characters.restore(data.characters) or not restored_relationships.restore(data.relationships) or not restored_clock.restore(data.clock):
		return false
	for character in restored_characters.all_states():
		if character.needs != null and character.needs.last_updated_minutes > restored_clock.total_minutes():
			return false
	_flags = restored_flags
	characters = restored_characters
	relationships = restored_relationships
	clock = restored_clock
	needs = NeedsService.new(clock, characters)
	return true
