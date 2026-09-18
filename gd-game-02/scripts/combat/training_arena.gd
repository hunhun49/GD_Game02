@tool
extends SchoolZone

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, bounds), Color("38555b"))
	for x in range(0, int(bounds.x), 80):
		draw_line(Vector2(x, 0), Vector2(x, bounds.y), Color("406168"))
	for y in range(0, int(bounds.y), 80):
		draw_line(Vector2(0, y), Vector2(bounds.x, y), Color("406168"))
	draw_circle(Vector2(800, 605), 145, Color("476b70"))
	draw_arc(Vector2(800, 605), 145, 0, TAU, 64, Color("8fc5bc"), 3)
	draw_string(ThemeDB.fallback_font, Vector2(650, 500), "다수전 훈련  ·  3 TARGETS", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("edf4de"))
	draw_string(ThemeDB.fallback_font, Vector2(605, 815), "커서를 세 적의 중앙에 두고 공격해 보세요", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("edf4de"))
