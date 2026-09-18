class_name InventoryTab
extends HBoxContainer

signal use_requested(slot: int)
var _grid: GridContainer
var _detail: VBoxContainer
var _count: Label
var _filters: Array[Button] = []
var _items: Array = []
var _selected: int = -1
var _category: int = -1

func _ready() -> void:
	add_theme_constant_override("separation", 24)
	var left := CharacterMenuStyle.column()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(left)
	var filters := HBoxContainer.new()
	left.add_child(filters)
	for i in range(4):
		var button := CharacterMenuStyle.button(["전체", "음식", "치료", "중요"][i])
		button.toggle_mode = true
		button.button_pressed = i == 0
		button.pressed.connect(_filter.bind(i - 1))
		filters.add_child(button)
		_filters.append(button)
	_count = CharacterMenuStyle.label("", 14, CharacterMenuStyle.MUTED)
	left.add_child(_count)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 294
	panel.add_theme_stylebox_override("panel", CharacterMenuStyle.box(Color("243b44"), 8, Color("39545a"), 20))
	add_child(panel)
	_detail = CharacterMenuStyle.column(14)
	panel.add_child(_detail)

func present(data: Dictionary) -> void:
	_items = data.get("items", [])
	_count.text = "%d / 24칸 사용  ·  아이템을 선택해 확인하세요" % _items.size()
	var current := _selected_item()
	if current.is_empty() or (_category != -1 and current.category != _category):
		_selected = -1
		for item in _items:
			if _category == -1 or item.category == _category:
				_selected = int(item.slot_id)
				break
	_render()

func _filter(category: int) -> void:
	_category = category
	for i in range(_filters.size()):
		_filters[i].button_pressed = i - 1 == category
	var selected := _selected_item()
	if not selected.is_empty() and category != -1 and selected.category != category:
		_selected = -1
	_render()

func _selected_item() -> Dictionary:
	for item in _items:
		if item.slot_id == _selected:
			return item
	return {}

func _render() -> void:
	CharacterMenuStyle.clear(_grid)
	var visible_count := 0
	for item in _items:
		if _category != -1 and item.category != _category:
			continue
		visible_count += 1
		var button := CharacterMenuStyle.button("%s  ×%d" % [item.name, item.quantity])
		button.custom_minimum_size = Vector2(92, 84)
		button.add_theme_font_size_override("font_size", 13)
		button.icon = item.icon
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 40)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.toggle_mode = true
		button.button_pressed = item.slot_id == _selected
		button.tooltip_text = item.name
		button.pressed.connect(_select.bind(int(item.slot_id)))
		_grid.add_child(button)
	for i in range(24 - visible_count if _category == -1 else 0):
		var empty := PanelContainer.new()
		empty.custom_minimum_size = Vector2(92, 84)
		empty.add_theme_stylebox_override("panel", CharacterMenuStyle.box(Color("192f3b"), 6, Color("2b444f"), 0))
		_grid.add_child(empty)
	if visible_count == 0:
		_grid.add_child(CharacterMenuStyle.label("해당 아이템이 없습니다.", 16, CharacterMenuStyle.MUTED))
	_render_detail()

func _select(slot: int) -> void:
	_selected = slot
	_render()
	for child in _grid.get_children():
		if child is Button and child.button_pressed:
			child.grab_focus()

func _render_detail() -> void:
	CharacterMenuStyle.clear(_detail)
	var item := _selected_item()
	if item.is_empty():
		_detail.add_child(CharacterMenuStyle.label("아이템을 선택하세요", 22))
		return
	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(100, 96)
	_detail.add_child(icon)
	_detail.add_child(CharacterMenuStyle.label(item.name, 26))
	_detail.add_child(CharacterMenuStyle.label(["음식 · 음료", "치료 도구", "중요한 물건"][int(item.category)] + "  /  보유 %d" % item.quantity, 15, CharacterMenuStyle.ACCENT))
	var description := CharacterMenuStyle.label(item.description, 17)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(description)
	var hint := CharacterMenuStyle.label(item.reason, 14, CharacterMenuStyle.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(hint)
	var use := CharacterMenuStyle.button("사용하기")
	use.disabled = not item.reason.is_empty()
	use.pressed.connect(func() -> void: use_requested.emit(_selected))
	_detail.add_child(use)
