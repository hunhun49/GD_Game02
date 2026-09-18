class_name SkillsTab
extends VBoxContainer

signal equip_requested(skill_id: StringName)
signal unequip_requested

func present(data: Dictionary) -> void:
	CharacterMenuStyle.clear(self)
	add_theme_constant_override("separation", 16)
	add_child(CharacterMenuStyle.label("사용 스킬", 26))
	add_child(CharacterMenuStyle.label("Q 슬롯에 장착한 스킬을 전투 중 사용할 수 있습니다.", 17, CharacterMenuStyle.MUTED))
	var slots := HBoxContainer.new()
	var equipped := CharacterMenuStyle.label("[ Q ]  " + data.get("equipped_name", "비어 있음"), 22, CharacterMenuStyle.ACCENT)
	equipped.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.add_child(equipped)
	var remove := CharacterMenuStyle.button("장착 해제")
	remove.disabled = data.get("equipped_id", "").is_empty()
	remove.pressed.connect(func() -> void: unequip_requested.emit())
	slots.add_child(remove)
	add_child(slots)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var list := CharacterMenuStyle.column(12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for skill in data.get("skills", []):
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", CharacterMenuStyle.box(Color("233b47"), 8, Color("405961"), 20))
		list.add_child(card)
		var rows := CharacterMenuStyle.column(10)
		card.add_child(rows)
		rows.add_child(CharacterMenuStyle.label(skill.name, 24))
		rows.add_child(CharacterMenuStyle.label(skill.description, 17, CharacterMenuStyle.MUTED))
		rows.add_child(CharacterMenuStyle.label("피해 %.0f  ·  재사용 %.1f초  ·  남은 시간 %.1f초" % [skill.damage, skill.cooldown, skill.remaining], 16, CharacterMenuStyle.ACCENT))
		var equip := CharacterMenuStyle.button("장착 중" if skill.id == data.get("equipped_id", "") else "Q 슬롯에 장착")
		equip.disabled = skill.id == data.get("equipped_id", "")
		equip.pressed.connect(func() -> void: equip_requested.emit(StringName(skill.id)))
		rows.add_child(equip)
	if data.get("skills", []).is_empty():
		list.add_child(CharacterMenuStyle.label("아직 배운 스킬이 없습니다.", 18, CharacterMenuStyle.MUTED))
