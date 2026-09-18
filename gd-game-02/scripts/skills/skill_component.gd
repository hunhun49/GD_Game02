class_name SkillComponent
extends Node

signal loadout_changed
signal used(slot: int, skill_id: StringName)
signal cooldown_changed(skill_id: StringName, remaining: float)

const MAX_SLOTS: int = 8

@export var initial_skills: Array[SkillDefinition] = []
var _known: Dictionary[StringName, SkillDefinition] = {}
var _slots: Dictionary[int, StringName] = {}
var _cooldowns: Dictionary[StringName, float] = {}
var _using: bool = false

func _ready() -> void:
	for slot in range(initial_skills.size()):
		if slot >= MAX_SLOTS or not learn(initial_skills[slot]) or not equip(slot, initial_skills[slot].skill_id):
			push_error("Invalid initial skill or duplicate ID at slot %d" % slot)

func combat() -> CombatComponent:
	return get_parent() as CombatComponent

func learn(definition: SkillDefinition) -> bool:
	if _using or definition == null or not definition.is_valid() or _known.has(definition.skill_id):
		return false
	_known[definition.skill_id] = definition.duplicate(true) as SkillDefinition
	loadout_changed.emit()
	return true

func equip(slot: int, id: StringName) -> bool:
	if _using or slot < 0 or slot >= MAX_SLOTS or not _known.has(id):
		return false
	_slots[slot] = id
	loadout_changed.emit()
	return true

func unequip(slot: int) -> void:
	if not _using and _slots.erase(slot):
		loadout_changed.emit()

func skill_id(slot: int) -> StringName:
	return _slots.get(slot, &"")

func definition(id: StringName) -> SkillDefinition:
	return _known[id].duplicate(true) as SkillDefinition if _known.has(id) else null

func remaining(id: StringName) -> float:
	return _cooldowns.get(id, 0.0)

func can_use(slot: int) -> bool:
	var id := skill_id(slot)
	return not _using and _known.has(id) and remaining(id) <= 0 and combat() != null and combat().can_attack(_known[id].attack, SchoolCharacter.Action.SKILL)

func try_use(slot: int, target: CombatComponent = null) -> bool:
	if not can_use(slot):
		return false
	var id := skill_id(slot)
	var skill := _known[id]
	_using = true
	# Reserve before attack_started callbacks; failure restores the previous state.
	_cooldowns[id] = skill.cooldown_seconds
	var accepted := combat().try_attack(target, skill.attack, false, SchoolCharacter.Action.SKILL)
	if not accepted:
		_cooldowns.erase(id)
	else:
		cooldown_changed.emit(id, remaining(id))
		used.emit(slot, id)
	_using = false
	return accepted

# Only Combat advances the clock. Cancel/unequip do not refund a committed skill.
func tick(delta: float) -> void:
	if _using or not is_finite(delta) or delta <= 0 or combat() == null or not combat().time_running():
		return
	_using = true
	for id in _cooldowns.keys():
		var next := maxf(0, _cooldowns[id] - delta)
		if next <= 0:
			_cooldowns.erase(id)
		else:
			_cooldowns[id] = next
		cooldown_changed.emit(id, next)
	_using = false

func known_skills() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	for id in _known:
		result.append(definition(id))
	return result
