class_name StatusEffectDefinition
extends Resource

# Configuration only. New mechanics implement StatusBehavior, not this class.
@export var status_id: StringName
@export var display_name: String
@export var tags: Array[StringName] = []
@export var duration_seconds: float = 4.0
@export var priority: int = 0
@export var behaviors: Array[StatusBehavior] = []
@export var reapply_policy: StatusReapplyPolicy = RefreshStatusPolicy.new()
@export var presentation_key: StringName
@export var color: Color = Color.WHITE

func is_valid() -> bool:
	if status_id.is_empty() or display_name.is_empty() or not is_finite(duration_seconds) or duration_seconds <= 0 or reapply_policy == null or not reapply_policy.is_valid() or behaviors.is_empty():
		return false
	for behavior in behaviors:
		if behavior == null or not behavior.is_valid():
			return false
	return true
