class_name SetFlagDialogueEffect
extends DialogueEffectHandler

var _state: SessionState

func _init(state: SessionState) -> void:
	_state = state

func validate(parameters: Dictionary) -> String:
	if parameters.size() != 2 or not parameters.has("key") or not parameters.has("value"):
		return "set_flag requires exactly 'key' and 'value'."
	if parameters.key is not String or parameters.key.strip_edges().is_empty():
		return "set_flag.key must be a non-empty string."
	if parameters.value is not bool:
		return "set_flag.value must be a boolean."
	return ""

func apply(parameters: Dictionary) -> void:
	_state.set_flag(StringName(parameters.key), parameters.value)
