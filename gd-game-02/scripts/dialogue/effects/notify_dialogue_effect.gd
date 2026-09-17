class_name NotifyDialogueEffect
extends DialogueEffectHandler

signal notification_requested(message: String)

func validate(parameters: Dictionary) -> String:
	if parameters.size() != 1 or not parameters.has("text"):
		return "notify requires exactly 'text'."
	if parameters.text is not String or parameters.text.strip_edges().is_empty():
		return "notify.text must be a non-empty string."
	return ""

func apply(parameters: Dictionary) -> void:
	notification_requested.emit(parameters.text)
