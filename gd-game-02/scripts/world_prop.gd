@tool
class_name SchoolProp
extends StaticBody2D

enum Kind { WALL, DESK, TREE, BENCH, BUILDING, CABINET }

@export var kind: Kind = Kind.WALL:
	set(value):
		kind = value
		queue_redraw()
@export var footprint: Vector2 = Vector2(100, 40):
	set(value):
		footprint = value
		_refresh()
@export var tint: Color = Color("75938b"):
	set(value):
		tint = value
		queue_redraw()

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	queue_redraw()
	if not is_node_ready():
		return
	var shape := RectangleShape2D.new()
	shape.size = footprint
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position = Vector2(0, -footprint.y * 0.5)

func _draw() -> void:
	var base := Rect2(Vector2(-footprint.x * 0.5, -footprint.y), footprint)
	match kind:
		Kind.WALL:
			draw_rect(base, tint)
			draw_line(base.position + Vector2(0, footprint.y), base.end, tint.darkened(0.2), 4)
		Kind.DESK, Kind.BENCH, Kind.CABINET:
			var lift := 22.0 if kind != Kind.CABINET else 65.0
			draw_rect(Rect2(base.position, footprint), tint.darkened(0.3))
			draw_rect(Rect2(base.position - Vector2(0, lift), footprint), tint)
			draw_rect(Rect2(base.position - Vector2(0, lift), footprint), tint.lightened(0.2), false, 3)
			if kind == Kind.DESK:
				draw_rect(Rect2(base.position + Vector2(14, -lift + 10), Vector2(24, 20)), Color("f7f0db"))
			elif kind == Kind.BENCH:
				draw_line(base.position - Vector2(0, lift + 8), base.position + Vector2(footprint.x, -lift - 8), tint.darkened(0.2), 8)
		Kind.TREE:
			draw_rect(Rect2(-10, -68, 20, 68), Color("806447"))
			draw_circle(Vector2(0, -87), 53, tint.darkened(0.18))
			draw_circle(Vector2(-24, -104), 34, tint)
			draw_circle(Vector2(23, -103), 35, tint)
			draw_circle(Vector2(0, -123), 30, tint.lightened(0.08))
		Kind.BUILDING:
			draw_rect(base, Color("d4c8aa"))
			draw_rect(Rect2(-footprint.x / 2, -100, footprint.x, 100), Color("ece0bd"))
			for x in range(int(-footprint.x / 2 + 35), int(footprint.x / 2), 100):
				draw_rect(Rect2(x, -80, 55, 46), Color("668c9b"))
				draw_line(Vector2(x + 27, -80), Vector2(x + 27, -34), Color("d9d8bc"), 4)
			draw_rect(Rect2(-footprint.x / 2 - 16, -footprint.y - 75, footprint.x + 32, footprint.y - 15), Color("4a6b80"))
			for y in range(int(-footprint.y - 60), -90, 22):
				draw_line(Vector2(-footprint.x / 2 - 12, y), Vector2(footprint.x / 2 + 12, y), Color("587d90"), 3)
			draw_rect(Rect2(-115, -98, 230, 27), Color("f5e9ce"))
			draw_string(ThemeDB.fallback_font, Vector2(-101, -78), "H A E S O L   S C H O O L", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("324c60"))
