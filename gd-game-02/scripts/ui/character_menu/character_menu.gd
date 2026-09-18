class_name CharacterMenu
extends CanvasLayer

signal close_requested
signal use_requested(slot: int)
signal equip_requested(skill_id: StringName)
signal unequip_requested

var _root: Control
var _tabs: Array[Button] = []
var _pages: Array[Control] = []
var _message: Label
var selected_tab: int = 1

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.07, 0.10, 0.85)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 64
	panel.offset_right = -64
	panel.offset_top = 28
	panel.offset_bottom = -28
	panel.add_theme_stylebox_override("panel", CharacterMenuStyle.box(Color("152b38"), 12, Color("4a6468"), 24))
	_root.add_child(panel)
	var rows := CharacterMenuStyle.column(16)
	panel.add_child(rows)
	var header := HBoxContainer.new()
	rows.add_child(header)
	var title := CharacterMenuStyle.label("방과 후의 기록", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(CharacterMenuStyle.label("게임 일시정지", 15, CharacterMenuStyle.ACCENT))
	var close_button := CharacterMenuStyle.button("닫기  [I / Esc]")
	close_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close_button)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	rows.add_child(tab_row)
	for i in range(3):
		var button := CharacterMenuStyle.button(["캐릭터 상태", "인벤토리", "스킬"][i])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.pressed.connect(select_tab.bind(i))
		tab_row.add_child(button)
		_tabs.append(button)
	var status := CharacterStatusTab.new()
	var inventory := InventoryTab.new()
	var skills := SkillsTab.new()
	_pages.assign([status, inventory, skills])
	for page in _pages:
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rows.add_child(page)
	inventory.use_requested.connect(func(slot: int) -> void: use_requested.emit(slot))
	skills.equip_requested.connect(func(id: StringName) -> void: equip_requested.emit(id))
	skills.unequip_requested.connect(func() -> void: unequip_requested.emit())
	_message = CharacterMenuStyle.label("아이템 사용과 스킬 장착을 여기에서 관리합니다.", 14, CharacterMenuStyle.MUTED)
	rows.add_child(_message)
	select_tab(selected_tab)
	close()

func open() -> void:
	_root.show()
	_tabs[selected_tab].grab_focus()

func close() -> void:
	if _root != null:
		_root.hide()

func is_open() -> bool:
	return _root != null and _root.visible

func select_tab(index: int) -> void:
	selected_tab = clampi(index, 0, 2)
	for i in range(_pages.size()):
		_pages[i].visible = i == selected_tab
		_tabs[i].button_pressed = i == selected_tab

func present(data: Dictionary) -> void:
	(_pages[0] as CharacterStatusTab).present(data.get("character", {}))
	(_pages[1] as InventoryTab).present(data.get("inventory", {}))
	(_pages[2] as SkillsTab).present(data.get("skills", {}))

func show_message(text: String) -> void:
	_message.text = text

func _input(event: InputEvent) -> void:
	if is_open() and (event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_I)):
		get_viewport().set_input_as_handled()
		close_requested.emit()
