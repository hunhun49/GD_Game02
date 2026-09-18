class_name StatusBehavior
extends Resource

# Immutable settings; keep timers/tokens in context.state, never this Resource.
func is_valid() -> bool:
	return true

func enter(_context: StatusEffectContext) -> void:
	pass

func advance(_context: StatusEffectContext, _delta: float) -> void:
	pass

func exit(_context: StatusEffectContext) -> void:
	pass

# Pure aggregation: no node changes or signals in this hook.
func contribute(_modifiers: StatusModifiers, _stacks: int) -> void:
	pass
