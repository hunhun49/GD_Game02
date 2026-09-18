class_name StatusEffectComponent
extends Node

signal changed(statuses: Array[Dictionary])
signal applied(status_id: StringName)
signal removed(status_id: StringName, reason: StringName)
signal periodic_damage(status_id: StringName, amount: float)
signal periodic_heal(status_id: StringName, amount: float)

@export var immune_tags: Array[StringName] = []
var bridge: StatusCharacterBridge
var _effects: Dictionary[String, StatusEffectInstance] = {}
var _ticking: bool = false
var _closing: bool = false

func _ready() -> void:
	_closing = false
	bridge = StatusCharacterBridge.new(get_parent() as SchoolCharacter)
	var health := get_parent().get_node_or_null("Health") as HealthComponent
	var on_death := clear.bind(&"incapacitated")
	if health != null and not health.incapacitated.is_connected(on_death):
		health.incapacitated.connect(on_death)

func _exit_tree() -> void:
	_closing = true
	clear(&"removed_from_tree")
	if bridge != null:
		bridge.release()

func movement_multiplier() -> float:
	return stat_multiplier(&"movement_speed")

func action_multiplier() -> float:
	return stat_multiplier(&"action_speed")

func stat_multiplier(stat: StringName) -> float:
	return bridge.modifiers.multiplier(stat) if bridge != null else 1.0

func has_tag(tag: StringName) -> bool:
	for effect in _effects.values():
		if tag in effect.definition.tags:
			return true
	return false

func has_status(id: StringName) -> bool:
	for effect in _effects.values():
		if effect.definition.status_id == id:
			return true
	return false

func owns(effect: StatusEffectInstance) -> bool:
	return _effects.get(effect.key) == effect

func snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect in _effects.values():
		result.append(effect.snapshot())
	return result

func apply_status(settings: StatusEffectDefinition, source_id: StringName = &"") -> bool:
	if settings == null or not settings.is_valid() or not _available():
		return false
	for tag in settings.tags:
		if tag in immune_tags:
			return false
	var incoming := StatusEffectInstance.new(settings, source_id if not source_id.is_empty() else bridge.actor().character_id)
	var current: StatusEffectInstance = _effects.get(incoming.key)
	var selected := incoming
	if current != null:
		# The established instance owns reapplication rules until it is removed.
		selected = current.definition.reapply_policy.resolve(current, incoming)
		if selected == null:
			return false
		if selected != current:
			_detach([current], &"replaced")
			# Exit/signals may have installed another instance; never overwrite it.
			if not _available() or _effects.has(incoming.key):
				return false
	_effects[selected.key] = selected
	_rebuild()
	if not owns(selected):
		return true
	if selected != current:
		StatusEffectRunner.start(self, selected)
	if owns(selected):
		applied.emit(selected.definition.status_id)
	changed.emit(snapshots())
	return true

func remove_status(id: StringName, reason: StringName = &"removed") -> bool:
	var matches: Array[StatusEffectInstance] = []
	for effect in _effects.values():
		if effect.definition.status_id == id:
			matches.append(effect)
	_detach(matches, reason)
	return not matches.is_empty()

func cleanse(tag: StringName) -> int:
	var matches: Array[StatusEffectInstance] = []
	for effect in _effects.values():
		if tag in effect.definition.tags:
			matches.append(effect)
	_detach(matches, &"cleansed")
	return matches.size()

func clear(reason: StringName = &"reset") -> void:
	var matches: Array[StatusEffectInstance] = []
	matches.assign(_effects.values())
	_detach(matches, reason)

func _detach(effects: Array[StatusEffectInstance], reason: StringName) -> void:
	# Detach the whole selection before invoking any callback.
	for effect in effects:
		if owns(effect):
			_effects.erase(effect.key)
	_rebuild()
	for effect in effects:
		StatusEffectRunner.stop(self, effect)
		removed.emit(effect.definition.status_id, reason)
	if not effects.is_empty():
		changed.emit(snapshots())

func _rebuild() -> void:
	var modifiers := StatusModifiers.new()
	for effect in _effects.values():
		StatusEffectRunner.contribute(effect, modifiers)
	if bridge != null:
		bridge.update(modifiers)

func _available() -> bool:
	return not _closing and is_inside_tree() and not is_queued_for_deletion() and bridge != null and bridge.available()

func time_running() -> bool:
	return _available() and can_process() and bridge.time_running()

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if _ticking or not is_finite(delta) or delta <= 0 or not time_running():
		return
	_ticking = true
	var batch := _effects.values()
	for effect: StatusEffectInstance in batch:
		if not owns(effect) or not time_running():
			continue
		var elapsed := minf(delta, effect.remaining)
		effect.remaining = maxf(0, effect.remaining - elapsed)
		StatusEffectRunner.advance(self, effect, elapsed)
		if owns(effect) and effect.remaining <= 0:
			_detach([effect], &"expired")
	_ticking = false
	if not batch.is_empty():
		changed.emit(snapshots())
