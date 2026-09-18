class_name StatusEffectRunner
extends RefCounted

static func start(owner: StatusEffectComponent, effect: StatusEffectInstance) -> void:
	for i in range(effect.definition.behaviors.size()):
		if not owner.owns(effect):
			return
		effect.entered[i] = true
		effect.definition.behaviors[i].enter(StatusEffectContext.new(owner, effect, i))

static func advance(owner: StatusEffectComponent, effect: StatusEffectInstance, delta: float) -> void:
	for i in range(effect.definition.behaviors.size()):
		if not owner.owns(effect) or not owner.time_running():
			return
		if effect.entered[i]:
			effect.definition.behaviors[i].advance(StatusEffectContext.new(owner, effect, i), delta)

static func stop(owner: StatusEffectComponent, effect: StatusEffectInstance) -> void:
	# Reverse order, exactly once, even if exit callbacks reenter the manager.
	for i in range(effect.definition.behaviors.size() - 1, -1, -1):
		if effect.entered[i]:
			effect.entered[i] = false
			effect.definition.behaviors[i].exit(StatusEffectContext.new(owner, effect, i))

static func contribute(effect: StatusEffectInstance, modifiers: StatusModifiers) -> void:
	for behavior in effect.definition.behaviors:
		behavior.contribute(modifiers, effect.stacks)
