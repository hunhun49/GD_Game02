class_name AffinityDialogueEffect
extends DialogueEffectHandler

var _session: SessionState

func _init(session: SessionState) -> void:
	_session = session

func validate(parameters: Dictionary) -> String:
	for key in parameters:
		if key not in ["from", "to", "amount", "once_key"]:
			return "add_affinity: unknown field '%s'." % key
	if not parameters.get("from") is String or not parameters.get("to") is String or not RelationshipGraph.valid_pair(StringName(parameters.from), StringName(parameters.to)):
		return "add_affinity requires distinct, non-empty from/to IDs."
	if not DataValidation.is_finite_number(parameters.get("amount")):
		return "add_affinity.amount must be a finite number."
	if parameters.has("once_key") and (not parameters.once_key is String or parameters.once_key.strip_edges().is_empty()):
		return "add_affinity.once_key must be a non-empty string."
	return ""

func apply(parameters: Dictionary) -> void:
	var once := StringName(parameters.get("once_key", ""))
	if not once.is_empty() and _session.has_flag(once):
		return
	# Mark before publishing a relationship signal to avoid duplicate reentrant rewards.
	if not once.is_empty():
		_session.set_flag(once, true)
	_session.relationships.add_affinity(StringName(parameters.from), StringName(parameters.to), float(parameters.amount))
