@tool
class_name CharacterVisual
extends Node2D

var _focused: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var interaction := get_parent().get_node_or_null("Interaction") as InteractionComponent
	if interaction != null:
		interaction.focus_changed.connect(_on_focus_changed)

func _on_focus_changed(value: bool) -> void:
	_focused = value
	# Dialogue can pause the zone before the next _process redraw.
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var actor := get_parent() as SchoolCharacter
	if actor == null or actor.definition == null:
		return
	var facing := actor.facing
	var step := sin(actor.movement.walk_phase) * 2.5 if is_instance_valid(actor.movement) else 0.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 16, Color(0.10, 0.20, 0.20, 0.22))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-10, -13 + step, 8, 13), Color("263b50"))
	draw_rect(Rect2(2, -13 - step, 8, 13), Color("263b50"))
	draw_rect(Rect2(-13, -33, 26, 23), actor.definition.outfit_color)
	draw_circle(Vector2(0, -42), 12, Color("f3cba7"))
	draw_rect(Rect2(-12, -54, 24, 10), Color("273744"))
	if facing == Vector2.UP:
		draw_circle(Vector2(0, -43), 12, Color("273744"))
		draw_rect(Rect2(-8, -30, 16, 17), Color("d8ad68"))
	elif facing == Vector2.DOWN:
		draw_circle(Vector2(-4, -41), 1.6, Color("273744"))
		draw_circle(Vector2(4, -41), 1.6, Color("273744"))
		draw_line(Vector2(-5, -30), Vector2(0, -20), Color.WHITE, 2)
		draw_rect(Rect2(-3, -22, 6, 8), Color("f8d279"))
	else:
		draw_circle(Vector2(facing.x * 6, -42), 2, Color("273744"))
		draw_rect(Rect2(-facing.x * 9 - 3, -30, 6, 17), Color("d8ad68"))
	if _focused:
		draw_arc(Vector2(0, -10), 36, PI * 0.05, PI * 0.95, 20, Color("f8d279"), 3)
		draw_circle(Vector2(0, -78), 5, Color("f8d279"))
