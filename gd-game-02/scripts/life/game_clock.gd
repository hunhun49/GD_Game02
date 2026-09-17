class_name GameClock
extends RefCounted

const MAX_MINUTES: float = 525600000.0

signal advanced(previous_minutes: float, current_minutes: float)
var minutes_per_real_second: float = 1.0
var _minutes: float = 480.0
var _locks: Dictionary[int, bool] = {}
var _next_token: int = 0
var _advancing: bool = false

func total_minutes() -> float:
	return _minutes

func is_paused() -> bool:
	return not _locks.is_empty()

func acquire_pause() -> int:
	_next_token += 1
	_locks[_next_token] = true
	return _next_token

func release_pause(token: int) -> void:
	_locks.erase(token)

func advance_real_seconds(seconds: float) -> bool:
	if not is_finite(seconds) or seconds < 0 or not is_finite(minutes_per_real_second) or minutes_per_real_second < 0:
		return false
	return advance_minutes(seconds * minutes_per_real_second)

func advance_minutes(amount: float) -> bool:
	if is_paused() or _advancing or not is_finite(amount) or amount < 0 or (not is_finite(_minutes + amount) or _minutes + amount > MAX_MINUTES):
		return false
	if amount == 0:
		return true
	var previous := _minutes
	_minutes += amount
	_advancing = true
	advanced.emit(previous, _minutes)
	_advancing = false
	return true

func display_text() -> String:
	var whole := int(floor(_minutes))
	return "%d일차 %02d:%02d" % [whole / 1440 + 1, (whole / 60) % 24, whole % 60]

func snapshot() -> Dictionary:
	return {"schema_version": 1, "total_minutes": _minutes, "minutes_per_real_second": minutes_per_real_second}

func restore(data: Dictionary) -> bool:
	if _advancing or is_paused() or not DataValidation.is_finite_number(data.get("schema_version")) or data.schema_version != 1:
		return false
	var time: Variant = data.get("total_minutes")
	var speed: Variant = data.get("minutes_per_real_second")
	if not DataValidation.is_finite_number(time) or time < 0 or time > MAX_MINUTES or not DataValidation.is_finite_number(speed) or speed < 0:
		return false
	_minutes = time
	minutes_per_real_second = speed
	return true
