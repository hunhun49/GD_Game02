extends "res://tests/ui_world_test.gd"

class FailedEffect extends ItemUseEffect:
	func is_valid() -> bool:
		return true
	func unavailable_reason(_context: ItemUseContext) -> String:
		return ""
	func apply(_context: ItemUseContext) -> bool:
		return false

var game: Node
var actor: SchoolCharacter
var inventory: InventoryState
var context: ItemUseContext

func slot(id: StringName) -> int:
	for entry in inventory.entries():
		if entry.item_id == String(id):
			return entry.slot_id
	return -1

func button(text: String) -> Button:
	for node in game.ui.get_character_menu().find_children("*", "Button", true, false):
		if node.is_visible_in_tree() and node.text == text:
			return node
	return null

func test_storage() -> void:
	var bag := InventoryState.new()
	check(bag.add(&"rice_ball", 23) == 0 and bag.count(&"rice_ball") == 23 and bag.entries().size() == 3, "Acquisition splits by item stack limit")
	check(bag.entry(0).quantity == 10 and bag.entry(2).quantity == 3, "Stacks use stable numbered slots")
	check(bag.remove(0, 4) and bag.add(&"rice_ball", 5) == 0 and bag.entry(0).quantity == 10 and bag.entry(2).quantity == 4, "Acquisition fills partial stacks first")
	var before := bag.snapshot()
	check(not bag.remove(0, 999) and not bag.remove(0, -1) and bag.snapshot() == before, "Invalid removals cannot alter quantity")
	check(bag.add(&"missing", 2) == 2 and bag.snapshot() == before, "Unknown IDs are rejected without mutation")
	var copy := bag.entries()
	copy[0].quantity = 999
	check(bag.entry(0).quantity == 10, "Inventory views are detached values")
	var definition := bag.catalog.get_definition(&"rice_ball")
	definition.max_stack = 1
	check(bag.catalog.get_definition(&"rice_ball").max_stack == 10, "Catalog configuration cannot be mutated through lookup")
	var full := InventoryState.new()
	check(full.add(&"student_card", 25) == 1 and full.entries().size() == 24, "Capacity returns unaccepted remainder rather than dropping items")
	check(full.add(&"water", 1) == 1 and full.count(&"water") == 0, "Full bag never consumes an unaccepted grant")
	check(full.remove(5, 1) and full.add(&"water", 1) == 0 and full.entry(5).item_id == "water", "Freed slots are reused")
	var restored := InventoryState.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(bag.snapshot()))) and restored.snapshot() == bag.snapshot(), "Inventory round-trips through JSON")
	for field in ["slot_id", "quantity"]:
		for invalid_value in [-1, 0.5, true, INF, "1"]:
			var invalid := bag.snapshot()
			invalid.slots[0][field] = invalid_value
			var target := InventoryState.new()
			check(not target.restore(invalid) and target.entries().is_empty(), "Malformed inventory rejected atomically: %s=%s" % [field, invalid_value])
	var duplicate := bag.snapshot()
	duplicate.slots.append(duplicate.slots[0].duplicate())
	check(not InventoryState.new().restore(duplicate), "Duplicate slot IDs are rejected")
	var unknown := bag.snapshot()
	unknown.slots[0].item_id = "removed_item"
	check(not InventoryState.new().restore(unknown), "Unknown saved item is not silently discarded")
	var oversize := bag.snapshot()
	oversize.slots[0].quantity = 11
	check(not InventoryState.new().restore(oversize), "Saved quantity cannot exceed stack limit")

func test_session() -> void:
	var state := SessionState.new()
	state.mark_in_use()
	state.inventory.remove(0, 1)
	state.mark_in_use()
	check(state.inventory.count(&"rice_ball") == 2, "Repeated world binding never duplicates starting items")
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.snapshot()))
	var loaded := SessionState.new()
	check(loaded.restore(data) and loaded.snapshot() == state.snapshot(), "Session restores inventory together with other domains")
	loaded.mark_in_use()
	check(loaded.inventory.count(&"rice_ball") == 2, "Restored inventory does not receive another starter grant")
	var corrupted := data.duplicate(true)
	corrupted.inventory.slots[0].quantity = 99999
	corrupted.flags.test_flag = true
	var clean := SessionState.new()
	check(not clean.restore(corrupted) and not clean.has_flag(&"test_flag") and clean.inventory.entries().is_empty(), "Corrupt inventory cannot partially restore session")
	var legacy := data.duplicate(true)
	legacy.schema_version = 1
	legacy.erase("inventory")
	legacy.erase("inventory_initialized")
	var migrated := SessionState.new()
	check(migrated.restore(legacy), "Version-one sessions migrate without inventory")
	migrated.mark_in_use()
	check(migrated.inventory.count(&"rice_ball") == 3, "Migrated sessions receive one starting loadout")
	for row in loaded.inventory.entries():
		loaded.inventory.remove(row.slot_id, row.quantity)
	var empty := SessionState.new()
	check(empty.restore(loaded.snapshot()), "Intentionally empty inventory can be restored")
	empty.mark_in_use()
	check(empty.inventory.entries().is_empty(), "Empty restored bag is not refilled")

func test_effects() -> void:
	var health := actor.get_node("Health") as HealthComponent
	check(inventory.use_reason(slot(&"student_card"), context) != "" and not inventory.use(slot(&"student_card"), context), "Key item cannot be consumed")
	check(not inventory.use(slot(&"first_aid"), context) and inventory.count(&"first_aid") == 2, "Full-health healing does not consume an item")
	health.take_damage(DamageEvent.new(&"test", 50))
	var reentrant: Array[bool] = []
	var callback := func(_current: float, _maximum: float) -> void:
		reentrant.append(inventory.use(slot(&"first_aid"), context))
		reentrant.append(inventory.remove(slot(&"first_aid"), 1))
		reentrant.append(inventory.add(&"water", 1) == 0)
	health.changed.connect(callback, CONNECT_ONE_SHOT)
	check(inventory.use(slot(&"first_aid"), context) and health.current() == 80 and inventory.count(&"first_aid") == 1, "Healing consumes exactly one item after applying health")
	check(reentrant == [false, false, false], "Effect callbacks cannot recursively mutate the inventory")
	actor.status_effects().apply_status(load("res://data/status/poison.tres"), &"test")
	actor.status_effects().apply_status(load("res://data/status/bleed.tres"), &"test")
	check(inventory.use(slot(&"antidote"), context) and not actor.status_effects().has_status(&"poison") and actor.status_effects().has_status(&"bleed"), "Antidote treats matching status only")
	var remaining := inventory.count(&"antidote")
	check(not inventory.use(slot(&"antidote"), context) and inventory.count(&"antidote") == remaining, "Unnecessary treatment does not consume stock")
	check(inventory.use(slot(&"bandage"), context) and not actor.status_effects().has_status(&"bleed"), "Bandage removes bleeding")
	var failed := ItemDefinition.new()
	failed.item_id = &"failure_probe"
	failed.display_name = "검사용"
	failed.use_effect = FailedEffect.new()
	inventory.catalog.register(failed)
	inventory.add(failed.item_id, 1)
	check(not inventory.use(slot(failed.item_id), context) and inventory.count(failed.item_id) == 1, "Failed effect returns reserved item to original slot")
	inventory.remove(slot(failed.item_id), 1)
	var token := actor.acquire_control_lock()
	check(not inventory.use(slot(&"rice_ball"), context), "External interaction lock blocks item use")
	actor.release_control_lock(token)
	paused = true
	check(not inventory.use(slot(&"first_aid"), context), "Ordinary item context cannot bypass pause")
	var menu_context := ItemUseContext.new(actor, game.session_state.needs, true)
	check(inventory.use(slot(&"first_aid"), menu_context) and health.current() == 100, "Explicit menu context supports paused healing")
	check(health.take_damage(DamageEvent.new(&"test", 5)) == 0, "Menu healing does not enable combat damage while paused")
	paused = false

func test_menu() -> void:
	var menu: CharacterMenu = game.ui.get_character_menu()
	var clock_before: float = game.session_state.clock.total_minutes()
	await key(KEY_I)
	check(menu.is_open() and paused and game.session_state.clock.is_paused(), "I opens three-tab menu and owns simulation pause")
	await frames(3)
	check(game.session_state.clock.total_minutes() == clock_before, "Menu freezes school time")
	check(button("캐릭터 상태") != null and button("인벤토리") != null and button("스킬") != null, "Three navigation tabs are available at top")
	await click(button("캐릭터 상태"))
	check(menu.selected_tab == 0, "Status tab is selectable through real pointer input")
	await click(button("인벤토리"))
	check(menu.selected_tab == 1 and button("삼각김밥  ×3") != null, "Inventory shows owned stacks")
	await click(button("삼각김밥  ×3"))
	await click(button("사용하기"))
	check(inventory.count(&"rice_ball") == 2 and game.session_state.needs.values(actor.character_id).hunger == 0, "Inventory use button reduces hunger and consumes one rice ball")
	check(button("사용하기").disabled, "UI disables food with no remaining benefit")
	await click(button("치료"))
	check(button("삼각김밥  ×2") == null and button("붕대  ×1") != null, "Category filter limits displayed items")
	await click(button("스킬"))
	var skills := (actor.get_node("Combat") as CombatComponent).skills()
	var skill_id := skills.skill_id(0)
	await click(button("장착 해제"))
	check(skills.skill_id(0).is_empty() and button("Q 슬롯에 장착") != null, "Skill tab can unequip Q slot")
	await click(button("Q 슬롯에 장착"))
	check(skills.skill_id(0) == skill_id, "Skill tab can equip learned skill")
	await key(KEY_ESCAPE)
	check(not paused and not menu.is_open() and not game.ui.is_pause_open(), "Escape closes menu without opening pause screen")
	await key(KEY_I)
	await key(KEY_I)
	check(not paused and not menu.is_open(), "I toggles the menu without reopening on same event")
	var count_before := inventory.count(&"rice_ball")
	check(game.ingame.load_zone("building", "Entrance") and game.ingame.load_zone("courtyard", "FromBuilding"), "Zone transitions remain available")
	check(inventory.count(&"rice_ball") == count_before, "Zone transitions preserve inventory without regranting items")
	paused = true
	game.coordinator.request_character_menu()
	check(not menu.is_open(), "Menu cannot take ownership of an external pause")
	paused = false
	game.coordinator.request_character_menu()
	check(menu.is_open(), "Menu reopens after external pause ends")

func run() -> void:
	create_timer(40).timeout.connect(func() -> void: quit(1))
	test_storage()
	test_session()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(2)
	actor = game.ingame.get_player()
	actor.get_node("CombatFeedback").sound_enabled = false
	inventory = game.session_state.inventory
	context = ItemUseContext.new(actor, game.session_state.needs)
	test_effects()
	await test_menu()
	game.queue_free()
	await frames(2)
	check(not paused, "Destroying open menu owner releases pause")
	print("INVENTORY/MENU TESTS: %d checks, %d failure(s)" % [checks, failures])
	quit(1 if failures else 0)
