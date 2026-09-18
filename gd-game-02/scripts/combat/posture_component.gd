class_name PostureComponent
extends Node

signal changed(current: float, maximum: float)
signal broken

@export var maximum: float = 100.0
@export var recovery_delay: float = 1.0
@export var break_duration: float = 0.8
var current: float = 0.0
var break_remaining: float = 0.0
var _wait: float = 0.0
var _dispatching: bool = false

func is_broken() -> bool:
	return break_remaining > 0.0

# Combat owns the clock. This transient state is reset only when an encounter ends.
func tick(delta: float, health_ratio: float) -> void:
	if _dispatching or delta <= 0 or not is_finite(delta):
		return
	if is_broken():
		break_remaining = maxf(0, break_remaining - delta)
		if break_remaining == 0:
			current = maximum * 0.35
			_wait = recovery_delay
			_publish()
		return
	var usable := maxf(0, delta - _wait)
	_wait = maxf(0, _wait - delta)
	var next := maxf(0, current - usable * (4.0 + 12.0 * clampf(health_ratio, 0, 1)))
	if next != current:
		current = next
		_publish()

func add(amount: float) -> bool:
	if _dispatching or not is_inside_tree() or not can_process() or not (get_parent() as SchoolCharacter).can_act(SchoolCharacter.Action.COMBAT_TICK) or is_broken() or not is_finite(amount) or amount <= 0:
		return false
	current = minf(maximum, current + amount)
	_wait = recovery_delay
	_dispatching = true
	if current >= maximum:
		break_remaining = break_duration
		broken.emit()
	changed.emit(current, maximum)
	_dispatching = false
	return true

func reset() -> void:
	if _dispatching:
		return
	current = 0
	break_remaining = 0
	_wait = 0
	_publish()

func _publish() -> void:
	_dispatching = true
	changed.emit(current, maximum)
	_dispatching = false
