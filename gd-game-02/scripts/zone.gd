@tool
class_name SchoolZone
extends Node2D

@export var zone_title: String = "학교 운동장"
@export var bounds: Vector2 = Vector2(1600, 1000)
@export var indoors: bool = false

func _draw() -> void:
	if indoors:
		draw_rect(Rect2(Vector2.ZERO, bounds), Color("ded7c2"))
		for x in range(0, int(bounds.x), 80):
			draw_line(Vector2(x, 0), Vector2(x, bounds.y), Color("cec6b1"), 1)
		for y in range(0, int(bounds.y), 80):
			draw_line(Vector2(0, y), Vector2(bounds.x, y), Color("cec6b1"), 1)
		draw_rect(Rect2(430, 155, 530, 30), Color("335f57"))
		draw_rect(Rect2(425, 150, 540, 40), Color("b68e62"), false, 6)
		draw_rect(Rect2(120, 865, 120, 75), Color("729994"))
	else:
		draw_rect(Rect2(Vector2.ZERO, bounds), Color("91b181"))
		for x in range(30, int(bounds.x), 60):
			for y in range(30, int(bounds.y), 60):
				draw_line(Vector2(x, y), Vector2(x + 4, y - 5), Color("81a674"), 2)
		draw_rect(Rect2(725, 350, 150, 650), Color("ddd3b8"))
		draw_rect(Rect2(250, 435, 1100, 120), Color("ddd3b8"))
		draw_rect(Rect2(1010, 670, 430, 225), Color("c4ab7c"))
		draw_rect(Rect2(1030, 690, 390, 185), Color("ede5ce"), false, 3)
		draw_line(Vector2(1225, 690), Vector2(1225, 875), Color("ede5ce"), 3)
		draw_arc(Vector2(1225, 782), 42, 0, TAU, 40, Color("ede5ce"), 3)
		draw_rect(Rect2(1028, 739, 55, 86), Color("ede5ce"), false, 3)
		draw_rect(Rect2(1367, 739, 55, 86), Color("ede5ce"), false, 3)
