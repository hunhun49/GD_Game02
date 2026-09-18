class_name CharacterMenuPresenter
extends RefCounted

var _world: InGame
var _state: SessionState
var _view: CharacterMenu

func configure(world: InGame, state: SessionState, view: CharacterMenu) -> void:
	_world = world
	_state = state
	_view = view
	_view.use_requested.connect(use_item)
	_view.equip_requested.connect(equip)
	_view.unequip_requested.connect(unequip)
	_state.inventory.changed.connect(refresh)

func dispose() -> void:
	if _state != null and _state.inventory.changed.is_connected(refresh):
		_state.inventory.changed.disconnect(refresh)
	if is_instance_valid(_view):
		for pair in [[_view.use_requested, use_item], [_view.equip_requested, equip], [_view.unequip_requested, unequip]]:
			if pair[0].is_connected(pair[1]):
				pair[0].disconnect(pair[1])
	_view = null
	_world = null
	_state = null

func _context() -> ItemUseContext:
	return ItemUseContext.new(_world.get_player(), _state.needs, _view.is_open() and _world.get_tree().paused)

func view_data() -> Dictionary:
	var actor := _world.get_player()
	var health := actor.get_node("Health") as HealthComponent
	var combat := actor.get_node("Combat") as CombatComponent
	var needs := actor.get_node("Needs").values() as Dictionary
	var stats: Array[Dictionary] = [{"name": "체력", "value": health.current(), "maximum": health.maximum()}, {"name": "체간", "value": combat.posture().current, "maximum": combat.posture().maximum}]
	for pair in [["허기", "hunger"], ["갈증", "thirst"], ["피로", "fatigue"]]:
		stats.append({"name": pair[0], "value": needs.get(pair[1], 0), "maximum": 100, "need": true})
	var stamina := actor.get_node("Stamina") as StaminaComponent
	if stamina.is_enabled():
		stats.insert(1, {"name": "스태미나", "value": stamina.current(), "maximum": stamina.maximum()})
	var effects := PackedStringArray()
	for effect in actor.status_effects().snapshots():
		effects.append("%s ×%d · %.1f초" % [effect.name, effect.stacks, effect.remaining])
	var inventory: Array[Dictionary] = []
	for stack in _state.inventory.entries():
		var definition := _state.inventory.catalog.get_definition(StringName(stack.item_id))
		inventory.append({"slot_id": stack.slot_id, "quantity": stack.quantity, "name": definition.display_name, "description": definition.description, "category": definition.category, "icon": definition.icon, "reason": _state.inventory.use_reason(stack.slot_id, _context())})
	var skills: Array[Dictionary] = []
	var current: StringName = combat.skills().skill_id(0)
	var equipped := "비어 있음"
	for definition in combat.skills().known_skills():
		skills.append({"id": String(definition.skill_id), "name": definition.display_name, "description": definition.description, "damage": definition.attack.damage, "cooldown": definition.cooldown_seconds, "remaining": combat.skills().remaining(definition.skill_id)})
		if definition.skill_id == current:
			equipped = definition.display_name
	return {"character": {"name": actor.definition.display_name, "location": {"courtyard": "운동장", "building": "본관", "combat_arena": "훈련장"}.get(_world.zone_id, "학교"), "clock": _state.clock.display_text(), "stats": stats, "effects": "\n".join(effects) if not effects.is_empty() else "정상 · 적용 중인 효과가 없습니다."}, "inventory": {"items": inventory}, "skills": {"skills": skills, "equipped_id": String(current), "equipped_name": equipped}}

func refresh() -> void:
	if is_instance_valid(_view) and _view.is_open():
		_view.present(view_data())

func use_item(slot: int) -> void:
	if not is_instance_valid(_view) or not _view.is_open() or not _world.get_tree().paused:
		return
	var stack := _state.inventory.entry(slot)
	var success := _state.inventory.use(slot, _context())
	refresh()
	_view.show_message(_state.inventory.catalog.get_definition(StringName(stack.item_id)).display_name + " 사용 완료" if success else "사용할 수 없습니다. 아이템은 소모되지 않았습니다.")

func equip(id: StringName) -> void:
	if not _view.is_open() or not _world.get_tree().paused:
		return
	var skills := (_world.get_player().get_node("Combat") as CombatComponent).skills()
	if skills.equip(0, id):
		refresh()
		_view.show_message("Q 슬롯에 스킬을 장착했습니다.")

func unequip() -> void:
	if not _view.is_open() or not _world.get_tree().paused:
		return
	(_world.get_player().get_node("Combat") as CombatComponent).skills().unequip(0)
	refresh()
	_view.show_message("Q 슬롯을 비웠습니다.")
