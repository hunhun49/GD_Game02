class_name ItemStack
extends RefCounted

var slot_id: int
var item_id: StringName
var quantity: int

func _init(slot: int, id: StringName, count: int) -> void:
	slot_id = slot
	item_id = id
	quantity = count

func snapshot() -> Dictionary:
	return {"slot_id": slot_id, "item_id": String(item_id), "quantity": quantity}
