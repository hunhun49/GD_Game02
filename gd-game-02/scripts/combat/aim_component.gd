class_name AimComponent
extends Node

# Viewport coordinates are converted again as camera/actor move under the cursor.
var pointer_active: bool = false
var pointer_position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.DOWN

func track_pointer(viewport_position: Vector2) -> void:
	if not viewport_position.is_finite():
		return
	pointer_active = true
	pointer_position = viewport_position
	refresh()

func refresh() -> void:
	var actor := get_parent() as SchoolCharacter
	if not pointer_active or not actor.is_inside_tree() or not actor.can_act(SchoolCharacter.Action.COMBAT_TICK):
		return
	var point := actor.get_canvas_transform().affine_inverse() * pointer_position
	var offset := point - actor.global_position
	if offset.length_squared() > 1:
		direction = offset.normalized()
	actor.facing = Vector2(signf(direction.x), 0) if absf(direction.x) > absf(direction.y) else Vector2(0, signf(direction.y))
