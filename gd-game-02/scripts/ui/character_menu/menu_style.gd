class_name CharacterMenuStyle
extends RefCounted

const INK := Color("e8eadc")
const MUTED := Color("a2b5b4")
const ACCENT := Color("8ed3bd")

static func box(color: Color, radius: int = 8, border: Color = Color.TRANSPARENT, padding: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

static func label(text: String, size: int = 18, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node

static func button(text: String) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 42
	node.add_theme_font_size_override("font_size", 17)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_hover_color", Color.WHITE)
	node.add_theme_color_override("font_pressed_color", Color("142c32"))
	node.add_theme_stylebox_override("normal", box(Color("243d48"), 6, Color("3a5660"), 10))
	node.add_theme_stylebox_override("hover", box(Color("365660"), 6, ACCENT, 10))
	node.add_theme_stylebox_override("pressed", box(ACCENT, 6, ACCENT, 10))
	node.add_theme_stylebox_override("disabled", box(Color("23333d"), 6, Color("34434a"), 10))
	var focus := box(Color.TRANSPARENT, 6, Color("f2d59a"), 0)
	focus.set_border_width_all(2)
	node.add_theme_stylebox_override("focus", focus)
	return node

static func column(separation: int = 12) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node

static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
