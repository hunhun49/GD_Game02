class_name SessionState
extends RefCounted

signal flag_changed(key: StringName, value: bool)

var characters := CharacterStateStore.new()
var relationships := RelationshipService.new()
var clock := GameClock.new()
var needs := NeedsService.new(clock, characters)
const STARTING_ITEMS := {&"rice_ball": 3, &"water": 3, &"first_aid": 2, &"antidote": 2, &"bandage": 2, &"burn_gel": 2, &"student_card": 1}
var inventory := InventoryState.new()
var inventory_initialized: bool = false
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
	ensure_starting_items()
	_in_use = true

func ensure_starting_items() -> void:
	if inventory_initialized:
		return
	inventory_initialized = true
	for id in STARTING_ITEMS:
		inventory.add(id, STARTING_ITEMS[id])

func snapshot() -> Dictionary:
	return {"schema_version": 2, "inventory": inventory.snapshot(), "inventory_initialized": inventory_initialized, "flags": snapshot_flags(), "characters": characters.snapshot(), "relationships": relationships.snapshot(), "clock": clock.snapshot()}

# Restore into a fresh session before configuring a world. Commit all domains together.
func restore(data: Dictionary) -> bool:
	if _in_use or inventory_initialized or not inventory.entries().is_empty() or not _flags.is_empty() or not characters.all_states().is_empty() or not relationships.snapshot().edges.is_empty():
		return false
	if not DataValidation.is_finite_number(data.get("schema_version")) or (data.schema_version != 1 and data.schema_version != 2):
		return false
	for key in ["flags", "characters", "relationships", "clock"]:
		if not data.get(key) is Dictionary:
			return false
	var restored_inventory := InventoryState.new()
	var restored_initialized := false
	if data.schema_version == 2:
		if not data.get("inventory") is Dictionary or not data.get("inventory_initialized") is bool or not restored_inventory.restore(data.inventory):
			return false
		restored_initialized = data.inventory_initialized
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
	inventory = restored_inventory
	inventory_initialized = restored_initialized
	_flags = restored_flags
	characters = restored_characters
	relationships = restored_relationships
	clock = restored_clock
	needs = NeedsService.new(clock, characters)
	return true
