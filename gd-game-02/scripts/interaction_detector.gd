class_name InteractionDetector
extends Node

signal focus_changed(target: InteractionComponent)

var context: InteractionContext
var focused: InteractionComponent
var candidates: Array[InteractionComponent] = []
var manual_target: InteractionComponent
var _scope: Node

func configure(value: InteractionContext) -> void:
	clear()
	context = value

func set_scope(value: Node) -> void:
	clear()
	_scope = value

func _physics_process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	candidates.clear()
	if context != null and is_instance_valid(_scope):
		for node in get_tree().get_nodes_in_group("interactables"):
			var target := node as InteractionComponent
			if target != null and _scope.is_ancestor_of(target) and target.can_interact(context):
				candidates.append(target)
	candidates.sort_custom(func(a: InteractionComponent, b: InteractionComponent) -> bool: return _score(a) < _score(b))
	if not is_instance_valid(manual_target) or not candidates.has(manual_target):
		manual_target = null
	var next: InteractionComponent = manual_target
	if next == null and not candidates.is_empty():
		next = candidates[0]
	_set_focus(next)

func interact() -> bool:
	refresh()
	return focused.interact(context) if is_instance_valid(focused) else false

func _score(target: InteractionComponent) -> float:
	var offset := target.global_position - context.actor.global_position
	return offset.length() + (1.0 - offset.normalized().dot(context.actor.facing)) * 30.0

func cycle() -> void:
	refresh()
	if candidates.size() < 2:
		return
	manual_target = candidates[(candidates.find(focused) + 1) % candidates.size()]
	_set_focus(manual_target)

func clear() -> void:
	manual_target = null
	candidates.clear()
	_set_focus(null)

func _set_focus(target: InteractionComponent) -> void:
	if is_instance_valid(focused) and focused == target:
		return
	if focused == null and target == null:
		return
	if is_instance_valid(focused):
		focused.focused = false
	focused = target
	if is_instance_valid(focused):
		focused.focused = true
	focus_changed.emit(focused)
