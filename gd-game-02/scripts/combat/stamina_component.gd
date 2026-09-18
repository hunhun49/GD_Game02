class_name StaminaComponent
extends Node

signal changed(current: float, maximum: float)
var _actor: SchoolCharacter
var _profile: StaminaProfile
var _recovery_wait: float = 0.0
var _dispatching: bool = false

func bind_character(actor: SchoolCharacter) -> void:
	_actor = actor
	_profile = actor.definition.stamina_profile if actor.definition != null else null
	if _profile == null or not _profile.is_valid():
		_profile = null
		return
	if actor.state.current_stamina < 0:
		actor.state.current_stamina = _profile.maximum
	else:
		actor.state.current_stamina = clampf(actor.state.current_stamina, 0, _profile.maximum)
	_publish()

func is_enabled() -> bool:
	return _profile != null and is_instance_valid(_actor) and _actor.state != null

func current() -> float:
	return _actor.state.current_stamina if is_enabled() else 0.0

func maximum() -> float:
	return _profile.maximum if is_enabled() else 0.0

func can_spend(amount: float) -> bool:
	return not _dispatching and _available() and is_finite(amount) and amount >= 0 and current() >= amount

func spend(amount: float) -> bool:
	if not can_spend(amount):
		return false
	if amount == 0:
		return true
	_actor.state.current_stamina -= amount
	_recovery_wait = _profile.recovery_delay
	_publish()
	return true

func restore_full() -> bool:
	if _dispatching or not _available():
		return false
	_actor.state.current_stamina = maximum()
	_recovery_wait = 0
	_publish()
	return true

func _physics_process(delta: float) -> void:
	if not is_enabled() or not _actor.can_act(SchoolCharacter.Action.COMBAT_TICK):
		return
	var usable := maxf(0, delta - _recovery_wait)
	_recovery_wait = maxf(0, _recovery_wait - delta)
	var value := minf(maximum(), current() + usable * _profile.recovery_per_second)
	if value != current():
		_actor.state.current_stamina = value
		_publish()

func _available() -> bool:
	return is_enabled() and is_inside_tree() and can_process() and not is_queued_for_deletion() and not _actor.is_queued_for_deletion()

func _publish() -> void:
	_dispatching = true
	changed.emit(current(), maximum())
	_dispatching = false
