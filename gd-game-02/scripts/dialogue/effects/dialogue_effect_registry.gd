class_name DialogueEffectRegistry
extends RefCounted

var _handlers: Dictionary[StringName, DialogueEffectHandler] = {}
var _sealed: bool = false

func register_handler(type: StringName, handler: DialogueEffectHandler) -> bool:
	if _sealed or type.is_empty() or handler == null or _handlers.has(type):
		return false
	_handlers[type] = handler
	return true

# Freeze the handler contract before loading content or starting sessions.
func seal() -> void:
	_sealed = true

func is_sealed() -> bool:
	return _sealed

func validate(effect: DialogueEffect) -> String:
	if not _handlers.has(effect.type):
		return "Unknown effect type '%s'." % effect.type
	return _handlers[effect.type].validate(effect.parameters.duplicate(true))

func execute(effects: Array[DialogueEffect]) -> bool:
	if not _sealed:
		return false
	# Validate the entire batch before making any changes. Handlers execute in order.
	for effect in effects:
		if not validate(effect).is_empty():
			return false
	for effect in effects:
		_handlers[effect.type].apply(effect.parameters.duplicate(true))
	return true
