class_name HealthComponent
extends Node

signal changed(current: float, maximum: float)
signal damaged(event: DamageEvent, applied: float)
signal incapacitated
signal revived

var _actor: SchoolCharacter
var _dispatching: bool = false
var _invulnerability: Dictionary[int, bool] = {}
var _next_token: int = 0

func bind_character(actor: SchoolCharacter) -> bool:
	if _dispatching or actor.state == null or actor.definition == null or not is_finite(actor.definition.max_health) or actor.definition.max_health <= 0:
		return false
	_actor = actor
	_actor.state.current_health = clampf(_actor.state.current_health, 0, maximum())
	if current() <= 0:
		_actor.state.activity = CharacterState.Activity.INCAPACITATED
		_actor.reset_motion()
	changed.emit(current(), maximum())
	return true

func current() -> float:
	return _actor.state.current_health if is_instance_valid(_actor) and _actor.state != null else 0.0

func maximum() -> float:
	return _actor.definition.max_health if is_instance_valid(_actor) and _actor.definition != null else 0.0

func can_take_damage() -> bool:
	return not _dispatching and _invulnerability.is_empty() and _available() and current() > 0

func take_damage(event: DamageEvent) -> float:
	if event == null or not is_finite(event.amount) or event.amount <= 0 or not can_take_damage():
		return 0.0
	var applied := minf(current(), event.amount)
	_actor.state.current_health -= applied
	var depleted := current() == 0.0
	if depleted:
		_actor.state.activity = CharacterState.Activity.INCAPACITATED
		_actor.reset_motion()
	_dispatching = true
	changed.emit(current(), maximum())
	damaged.emit(event.copy(), applied)
	if depleted:
		incapacitated.emit()
	_dispatching = false
	return applied

func heal(amount: float, allow_paused: bool = false) -> float:
	if _dispatching or not _available(allow_paused) or current() <= 0 or not is_finite(amount) or amount <= 0:
		return 0.0
	var applied := minf(maximum() - current(), amount)
	if applied <= 0:
		return 0.0
	_actor.state.current_health += applied
	_dispatching = true
	changed.emit(current(), maximum())
	_dispatching = false
	return applied

func revive(amount: float) -> bool:
	if _dispatching or not _available() or current() > 0 or not is_finite(amount) or amount <= 0:
		return false
	_actor.state.current_health = minf(maximum(), amount)
	_actor.state.activity = CharacterState.Activity.ACTIVE
	_actor.reset_motion()
	_dispatching = true
	changed.emit(current(), maximum())
	revived.emit()
	_dispatching = false
	return true

func acquire_invulnerability() -> int:
	_next_token += 1
	_invulnerability[_next_token] = true
	return _next_token

func release_invulnerability(token: int) -> void:
	_invulnerability.erase(token)

func _available(allow_paused: bool = false) -> bool:
	return is_instance_valid(_actor) and _actor.state != null and is_inside_tree() and (can_process() or (allow_paused and get_tree().paused)) and not is_queued_for_deletion() and not _actor.is_queued_for_deletion()
