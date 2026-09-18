class_name ItemCatalog
extends RefCounted

const PATHS := ["rice_ball", "water", "first_aid", "antidote", "bandage", "burn_gel", "student_card"]
var _definitions: Dictionary[StringName, ItemDefinition] = {}

static func standard() -> ItemCatalog:
	var catalog := ItemCatalog.new()
	for id in PATHS:
		assert(catalog.register(load("res://data/items/%s.tres" % id)), "Invalid item: " + id)
	return catalog

func register(item: ItemDefinition) -> bool:
	if item == null or not item.is_valid() or _definitions.has(item.item_id):
		return false
	_definitions[item.item_id] = item.duplicate(true) as ItemDefinition
	return true

func get_definition(id: StringName) -> ItemDefinition:
	return _definitions[id].duplicate(true) as ItemDefinition if _definitions.has(id) else null

func has_item(id: StringName) -> bool:
	return _definitions.has(id)
