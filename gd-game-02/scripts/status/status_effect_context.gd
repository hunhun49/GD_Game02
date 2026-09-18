class_name StatusEffectContext
extends RefCounted

var instance: StatusEffectInstance
var state: Dictionary
var _owner: WeakRef

func _init(owner: StatusEffectComponent, effect: StatusEffectInstance, index: int) -> void:
	_owner = weakref(owner)
	instance = effect
	state = effect.behavior_states[index]

func owner() -> StatusEffectComponent:
	return _owner.get_ref() as StatusEffectComponent

func is_current() -> bool:
	return is_instance_valid(owner()) and owner().owns(instance)

func is_running() -> bool:
	return is_current() and owner().time_running()

func deal_damage(amount: float, type: DamageType.Type, sequence: int) -> void:
	if not is_running():
		return
	var applied := owner().bridge.damage(instance, amount, type, sequence)
	if is_instance_valid(owner()):
		owner().periodic_damage.emit(instance.definition.status_id, applied)

func heal(amount: float) -> void:
	if not is_running():
		return
	var applied := owner().bridge.heal(amount)
	if is_instance_valid(owner()):
		owner().periodic_heal.emit(instance.definition.status_id, applied)
