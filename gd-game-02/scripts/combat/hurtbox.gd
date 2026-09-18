class_name Hurtbox
extends Area2D

@export var combat_path: NodePath = NodePath("../Combat")
@export var enabled: bool = true

func _ready() -> void:
	# These sensors never obstruct movement. Contacts use current shape transforms.
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	add_to_group("combat_hurtboxes")

func combat() -> CombatComponent:
	return get_node_or_null(combat_path) as CombatComponent

func shapes() -> Array[CollisionShape2D]:
	var result: Array[CollisionShape2D] = []
	if not enabled or not is_inside_tree() or is_queued_for_deletion() or not is_visible_in_tree():
		return result
	for child in get_children():
		if child is CollisionShape2D and child.shape != null and not child.disabled:
			result.append(child)
	return result
