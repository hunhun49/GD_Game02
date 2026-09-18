class_name InventoryState
extends RefCounted

signal changed
const CAPACITY: int = 24
var catalog: ItemCatalog
var _slots: Dictionary[int, ItemStack] = {}
var _busy: bool = false

func _init(definitions: ItemCatalog = null) -> void:
	catalog = definitions if definitions != null else ItemCatalog.standard()

func count(id: StringName) -> int:
	var total := 0
	for stack in _slots.values():
		if stack.item_id == id:
			total += stack.quantity
	return total

func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in range(CAPACITY):
		if _slots.has(slot):
			result.append(_slots[slot].snapshot())
	return result

func entry(slot: int) -> Dictionary:
	return _slots[slot].snapshot() if _slots.has(slot) else {}

# Returns unaccepted quantity. Existing partial stacks are filled first.
func add(id: StringName, quantity: int) -> int:
	if _busy or quantity <= 0 or not catalog.has_item(id):
		return quantity
	var maximum := catalog.get_definition(id).max_stack
	var remaining := quantity
	for slot in range(CAPACITY):
		var stack: ItemStack = _slots.get(slot)
		if stack != null and stack.item_id == id:
			var amount := mini(remaining, maximum - stack.quantity)
			stack.quantity += amount
			remaining -= amount
	for slot in range(CAPACITY):
		if remaining <= 0:
			break
		if not _slots.has(slot):
			var amount := mini(remaining, maximum)
			_slots[slot] = ItemStack.new(slot, id, amount)
			remaining -= amount
	if remaining != quantity:
		changed.emit()
	return remaining

func remove(slot: int, quantity: int) -> bool:
	if _busy or quantity <= 0 or not _slots.has(slot) or _slots[slot].quantity < quantity:
		return false
	_slots[slot].quantity -= quantity
	if _slots[slot].quantity == 0:
		_slots.erase(slot)
	changed.emit()
	return true

func use_reason(slot: int, context: ItemUseContext) -> String:
	if _busy:
		return "아이템 사용 중입니다."
	if not _slots.has(slot):
		return "아이템을 선택하세요."
	var item := catalog.get_definition(_slots[slot].item_id)
	if item.use_effect == null:
		return "보관하는 중요한 물건입니다."
	if context == null or not context.available():
		return "지금은 아이템을 사용할 수 없습니다."
	return item.use_effect.unavailable_reason(context)

func use(slot: int, context: ItemUseContext) -> bool:
	if not use_reason(slot, context).is_empty():
		return false
	var item := catalog.get_definition(_slots[slot].item_id)
	_busy = true
	# Reserve before callbacks; reentrant add/remove/use/restore are rejected.
	var stack := _slots[slot]
	stack.quantity -= 1
	if stack.quantity == 0:
		_slots.erase(slot)
	var applied := item.use_effect.apply(context)
	if not applied:
		stack.quantity += 1
		_slots[slot] = stack
	_busy = false
	changed.emit()
	return applied

func snapshot() -> Dictionary:
	return {"schema_version": 1, "capacity": CAPACITY, "slots": entries()}

func restore(data: Dictionary) -> bool:
	if _busy or not _slots.is_empty() or not _integer(data.get("schema_version"), 1, 1) or not _integer(data.get("capacity"), CAPACITY, CAPACITY) or not data.get("slots") is Array or data.slots.size() > CAPACITY:
		return false
	var restored: Dictionary[int, ItemStack] = {}
	for value in data.slots:
		if not value is Dictionary or not _integer(value.get("slot_id"), 0, CAPACITY - 1) or not value.get("item_id") is String:
			return false
		var slot := int(value.slot_id)
		var id := StringName(value.item_id)
		if restored.has(slot) or not catalog.has_item(id):
			return false
		if not _integer(value.get("quantity"), 1, catalog.get_definition(id).max_stack):
			return false
		restored[slot] = ItemStack.new(slot, id, int(value.quantity))
	_slots = restored
	return true

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return DataValidation.is_finite_number(value) and value == floor(value) and value >= minimum and value <= maximum
