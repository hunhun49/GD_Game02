class_name NeedsService
extends RefCounted

signal changed(character_id: StringName, hunger: float, thirst: float, fatigue: float)
var _clock: GameClock
var _characters: CharacterStateStore
var _profiles: Dictionary[StringName, NeedsProfile] = {}
var _resting: bool = false
var _rest_id: StringName
var _sleeping: bool = false
var _updating: bool = false

func _init(clock: GameClock, characters: CharacterStateStore) -> void:
	_clock = clock
	_characters = characters
	_clock.advanced.connect(_on_time_advanced)

func register_character(id: StringName, profile: NeedsProfile) -> bool:
	var character := _characters.get_state(id)
	if _updating or character == null or profile == null or not profile.is_valid():
		return false
	if character.needs != null and character.needs.last_updated_minutes > _clock.total_minutes():
		return false
	_profiles[id] = profile
	if character.needs == null:
		character.needs = NeedsState.new()
		character.needs.hunger = profile.initial_hunger
		character.needs.thirst = profile.initial_thirst
		character.needs.fatigue = profile.initial_fatigue
	_update(id, _clock.total_minutes())
	_publish(id)
	return true

func values(id: StringName) -> Dictionary:
	var character := _characters.get_state(id)
	return character.needs.snapshot() if character != null and character.needs != null else {}

func consume(id: StringName, item: ConsumableDefinition) -> bool:
	var character := _characters.get_state(id)
	if _updating or _resting or not _profiles.has(id) or character == null or character.activity != CharacterState.Activity.ACTIVE or item == null or not item.is_valid():
		return false
	var needs := character.needs
	needs.hunger = maxf(0.0, needs.hunger - item.hunger_relief)
	needs.thirst = maxf(0.0, needs.thirst - item.thirst_relief)
	_publish(id)
	return true

func rest(id: StringName, minutes: float, sleeping: bool = false) -> bool:
	var character := _characters.get_state(id)
	if _updating or _resting or not _profiles.has(id) or character == null or character.activity != CharacterState.Activity.ACTIVE or not is_finite(minutes) or minutes <= 0 or minutes > 1440 or _clock.is_paused():
		return false
	_resting = true
	_rest_id = id
	_sleeping = sleeping
	var result := _clock.advance_minutes(minutes)
	_rest_id = &""
	_sleeping = false
	_resting = false
	return result

func _on_time_advanced(_previous: float, current: float) -> void:
	_updating = true
	var ids := _profiles.keys()
	for id in ids:
		_update(id, current)
	# Publish only after every character is consistent with the new clock.
	for id in ids:
		_publish(id)
	_updating = false

func _update(id: StringName, current: float) -> void:
	var character := _characters.get_state(id)
	var needs := character.needs
	var profile := _profiles[id]
	if needs.last_updated_minutes < 0:
		needs.last_updated_minutes = current
	var hours := maxf(0.0, current - needs.last_updated_minutes) / 60.0
	needs.hunger = clampf(needs.hunger + hours * profile.hunger_per_hour, 0.0, 100.0)
	needs.thirst = clampf(needs.thirst + hours * profile.thirst_per_hour, 0.0, 100.0)
	var rate := profile.fatigue_per_hour
	if character.activity == CharacterState.Activity.SLEEPING or (_rest_id == id and _sleeping):
		rate = -profile.sleep_recovery_per_hour
	elif _rest_id == id:
		rate = -profile.rest_recovery_per_hour
	needs.fatigue = clampf(needs.fatigue + hours * rate, 0.0, 100.0)
	needs.last_updated_minutes = current

func _publish(id: StringName) -> void:
	var needs := _characters.get_state(id).needs
	changed.emit(id, needs.hunger, needs.thirst, needs.fatigue)
