@tool
class_name SchoolInteractable
extends StaticBody2D

# Prop appearance/collision only. Behavior is owned by the Interaction child.
enum Kind { BOARD = 1, DOOR = 2, CHECKPOINT = 3 }
@export var kind: Kind = Kind.BOARD
@export var floor_doorway: bool = false
var focused: bool = false:
	set(value):
		focused = value
		queue_redraw()

func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(56, 16) if kind == Kind.BOARD else Vector2(24, 16)
	$CollisionShape2D.shape = shape
	$CollisionShape2D.disabled = kind == Kind.DOOR
	if not Engine.is_editor_hint():
		$Interaction.focus_changed.connect(func(value: bool) -> void: focused = value)

func _draw() -> void:
	# Artwork rises above a ground-level origin shared with the player's feet.
	draw_set_transform(Vector2(0, -20))
	var accent := Color("f8d279") if focused else Color("aac5d4")
	match kind:
		Kind.BOARD:
			draw_rect(Rect2(-34, -65, 68, 62), Color("956e52"))
			draw_rect(Rect2(-29, -60, 58, 51), Color("dfd8bc"))
			for i in range(3):
				draw_rect(Rect2(-22, -51 + i * 13, 40 - i * 6, 5), Color("7a8b8c"))
			draw_line(Vector2(0, -3), Vector2(0, 20), Color("956e52"), 6)
		Kind.DOOR:
			if floor_doorway:
				draw_rect(Rect2(-38, -4, 76, 24), Color("253d53"))
				draw_rect(Rect2(-32, 0, 64, 15), Color("729994"))
				draw_colored_polygon(PackedVector2Array([Vector2(-10, 2), Vector2(10, 2), Vector2(0, 14)]), accent)
			else:
				draw_rect(Rect2(-30, -86, 60, 106), Color("253d53"))
				draw_rect(Rect2(-25, -81, 50, 96), Color("50738a"))
				draw_rect(Rect2(-19, -74, 38, 34), Color("a4c7cf"))
				draw_circle(Vector2(17, -20), 3, accent)
		Kind.CHECKPOINT:
			draw_line(Vector2(0, -75), Vector2(0, 20), Color("abc4d0"), 4)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -75), Vector2(40, -62), Vector2(0, -48)]), Color("68d8cf"))
	if focused:
		draw_arc(Vector2(0, 10), 36, PI * 0.05, PI * 0.95, 20, accent, 3)
		if not floor_doorway:
			draw_circle(Vector2(0, -99 if kind == Kind.DOOR else -78), 5, accent)
	draw_set_transform(Vector2.ZERO)
