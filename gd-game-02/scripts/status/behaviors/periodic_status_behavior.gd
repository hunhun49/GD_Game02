class_name PeriodicStatusBehavior
extends StatusBehavior

@export var interval: float = 1.0

func is_valid() -> bool:
	return is_finite(interval) and interval >= 0.01

func enter(context: StatusEffectContext) -> void:
	context.state.until_tick = interval
	context.state.sequence = 0

func advance(context: StatusEffectContext, delta: float) -> void:
	context.state.until_tick -= delta
	while context.state.until_tick <= 0.000001 and context.is_running():
		context.state.until_tick += interval
		context.state.sequence += 1
		pulse(context)

func pulse(_context: StatusEffectContext) -> void:
	pass
