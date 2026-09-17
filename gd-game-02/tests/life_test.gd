extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func student(session: SessionState, id: StringName) -> CharacterState:
	var definition := CharacterDefinition.new()
	definition.needs_profile = NeedsProfile.new()
	var state := session.characters.get_or_create(id, definition)
	session.needs.register_character(id, definition.needs_profile)
	return state

func test_clock() -> void:
	var clock := GameClock.new()
	check(clock.display_text() == "1일차 08:00", "Clock begins at day one, 08:00")
	clock.minutes_per_real_second = 2
	clock.advance_real_seconds(30)
	check(clock.total_minutes() == 540 and clock.display_text() == "1일차 09:00", "Real seconds advance configurable game minutes")
	clock.advance_minutes(900)
	check(clock.display_text() == "2일차 00:00", "Clock crosses midnight into the next day")
	var outer := clock.acquire_pause()
	var inner := clock.acquire_pause()
	clock.release_pause(inner)
	check(not clock.advance_minutes(60) and clock.total_minutes() == 1440, "Clock owners release only their own pause tokens")
	clock.release_pause(outer)
	check(clock.advance_minutes(60), "Time resumes after the final pause is released")
	var before := clock.snapshot()
	for amount in [-1.0, INF, NAN, GameClock.MAX_MINUTES]:
		check(not clock.advance_minutes(amount) and clock.snapshot() == before, "Invalid/overflow time advance is rejected: %s" % amount)
	var reentrant: Array[bool] = []
	var recursive := func(_a: float, _b: float) -> void: reentrant.append(clock.advance_minutes(1))
	clock.advanced.connect(recursive)
	clock.advance_minutes(1)
	check(reentrant == [false], "Clock rejects recursive time advances from subscribers")
	clock.advanced.disconnect(recursive)
	var restored := GameClock.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(clock.snapshot()))) and restored.snapshot() == clock.snapshot(), "Clock and rate round-trip through JSON")
	var invalid := restored.snapshot()
	invalid.total_minutes = -1
	check(not restored.restore(invalid) and restored.snapshot() == clock.snapshot(), "Invalid clock restore leaves the previous time intact")

func test_needs() -> void:
	var session := SessionState.new()
	var a := student(session, &"a")
	var b := student(session, &"b")
	check(a.needs.hunger == 20 and a.needs.thirst == 15 and a.needs.fatigue == 10, "Profiles initialize independent needs at the current time")
	session.clock.advance_minutes(60)
	check(a.needs.hunger == 24 and a.needs.thirst == 21 and a.needs.fatigue == 13, "One game hour applies configured hunger, thirst and fatigue rates")
	var stepped := SessionState.new()
	var c := student(stepped, &"a")
	for i in range(60):
		stepped.clock.advance_minutes(1)
	check(is_equal_approx(c.needs.hunger, a.needs.hunger) and is_equal_approx(c.needs.thirst, a.needs.thirst) and is_equal_approx(c.needs.fatigue, a.needs.fatigue), "Large time jumps match incremental simulation")
	var food: ConsumableDefinition = load("res://data/life/snack.tres")
	var water: ConsumableDefinition = load("res://data/life/water.tres")
	check(session.needs.consume(&"a", food) and a.needs.hunger == 0 and a.needs.thirst == 21, "Food reduces hunger without modifying unrelated needs")
	check(session.needs.consume(&"a", water) and a.needs.thirst == 0, "Drinking reduces thirst and clamps at zero")
	check(b.needs.hunger == 24 and b.needs.thirst == 21, "Consumption affects only the consuming character")
	a.needs.fatigue = 60
	var time := session.clock.total_minutes()
	check(session.needs.rest(&"a", 30) and session.clock.total_minutes() == time + 30 and a.needs.fatigue == 54, "Rest advances game time and recovers fatigue")
	check(a.needs.hunger == 2 and a.needs.thirst == 3 and b.needs.fatigue == 14.5, "Hunger/thirst and other characters continue progressing during rest")
	check(session.needs.rest(&"a", 60, true) and a.needs.fatigue == 34 and a.activity == CharacterState.Activity.ACTIVE, "Sleep recovers fatigue faster and restores active control")
	var locked := session.clock.acquire_pause()
	check(not session.needs.rest(&"a", 30) and a.activity == CharacterState.Activity.ACTIVE, "Blocked rest cannot strand a character in a resting state")
	session.clock.release_pause(locked)
	a.activity = CharacterState.Activity.INCAPACITATED
	check(not session.needs.consume(&"a", food) and not session.needs.rest(&"a", 30), "Inactive actors cannot consume or initiate rest")
	a.activity = CharacterState.Activity.ACTIVE
	var invalid := ConsumableDefinition.new()
	invalid.hunger_relief = NAN
	check(not session.needs.consume(&"a", invalid) and not session.needs.rest(&"a", -1), "Invalid consumables and rest durations are rejected")
	var during_rest: Array[Dictionary] = []
	var reentrant: Array[bool] = []
	var observe := func(_id: StringName, _h: float, _t: float, _f: float) -> void:
		during_rest.append(session.snapshot())
		reentrant.append(session.needs.consume(&"b", food))
	session.needs.changed.connect(observe)
	session.needs.rest(&"a", 1, true)
	session.needs.changed.disconnect(observe)
	check(reentrant.all(func(value: bool) -> bool: return not value), "Needs notifications cannot recursively mutate an in-flight time update")
	check(during_rest[0].characters.characters.all(func(record: Dictionary) -> bool: return record.needs.last_updated_minutes == during_rest[0].clock.total_minutes), "Observers see all characters at the same game time")
	var saved_during_rest := SessionState.new()
	check(saved_during_rest.restore(during_rest[0]) and saved_during_rest.characters.get_state(&"a").activity == CharacterState.Activity.ACTIVE, "Saving during a time skip cannot persist a temporary sleep/control lock")
	session.clock.advance_minutes(60 * 100)
	check(a.needs.hunger == 100 and a.needs.thirst == 100 and a.needs.fatigue == 100, "Long absence clamps needs at their upper bounds")
	var copy := session.needs.values(&"a")
	copy.hunger = -100
	check(a.needs.hunger == 100, "Published needs snapshots do not expose mutable state")
	var baseline := a.needs.snapshot()
	for changed in [{"hunger": -1}, {"thirst": INF}, {"fatigue": "2"}, {"last_updated_minutes": -2}]:
		var bad := baseline.duplicate()
		bad.merge(changed, true)
		check(not a.needs.restore(bad) and a.needs.snapshot() == baseline, "Malformed needs restore is atomic: %s" % changed)

func test_save() -> void:
	var session := SessionState.new()
	student(session, &"player")
	student(session, &"offscreen")
	session.relationships.add_affinity(&"offscreen", &"player", 15)
	session.relationships.add_affinity(&"player", &"offscreen", -3)
	session.set_flag(&"rewarded", true)
	session.clock.advance_minutes(60)
	var data: Dictionary = JSON.parse_string(JSON.stringify(session.snapshot()))
	var restored := SessionState.new()
	check(restored.restore(data) and restored.snapshot() == session.snapshot(), "Session save restores flags, graph, clock and character needs together")
	var dormant := restored.characters.get_state(&"offscreen")
	var hunger := dormant.needs.hunger
	restored.clock.advance_minutes(120)
	check(dormant.needs.hunger == hunger, "Unbound restored NPC waits for its content profile")
	restored.needs.register_character(&"offscreen", NeedsProfile.new())
	check(dormant.needs.hunger == hunger + 8 and dormant.needs.last_updated_minutes == restored.clock.total_minutes(), "Returning restored NPC catches up the missed game time exactly once")
	restored.needs.register_character(&"offscreen", NeedsProfile.new())
	check(dormant.needs.hunger == hunger + 8, "Rebinding does not apply elapsed time twice")
	var bad := data.duplicate(true)
	bad.characters.characters[0].needs.last_updated_minutes = bad.clock.total_minutes + 1
	var empty := SessionState.new()
	check(not empty.restore(bad) and empty.characters.all_states().is_empty() and empty.relationships.snapshot().edges.is_empty() and not empty.has_flag(&"rewarded"), "Future needs timestamp rejects the entire session without partial writes")
	bad = data.duplicate(true)
	bad.relationships.edges[0].affinity = 1000
	check(not empty.restore(bad) and empty.characters.all_states().is_empty(), "Corrupt graph cannot partially load character data")
	var legacy := data.duplicate(true)
	legacy.characters.schema_version = 1
	for record in legacy.characters.characters:
		record.erase("needs")
	var migrated := SessionState.new()
	check(migrated.restore(legacy), "Legacy character schema one migrates without needs data")
	migrated.needs.register_character(&"player", NeedsProfile.new())
	check(migrated.characters.get_state(&"player").needs.hunger == 20, "Migrated characters initialize new needs at load time")
	restored.mark_in_use()
	check(not restored.restore(data), "Live session restore cannot replace services held by components")

func test_game() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	var session: SessionState = game.session_state
	var player: SchoolPlayer = game.ingame.get_player()
	var component: NeedsComponent = player.get_node("Needs")
	check("08:00" in game.ui.get_node("HUD").displayed_life() and "허기" in game.ui.get_node("HUD").displayed_life(), "HUD receives initial clock and needs values")
	var time := session.clock.total_minutes()
	await frames(6)
	check(session.clock.total_minutes() > time, "World physics advances the session clock")
	game.dialogue.start(&"seoyun")
	time = session.clock.total_minutes()
	var needs_before := player.state.needs.snapshot()
	await frames(6)
	check(session.clock.total_minutes() == time and player.state.needs.snapshot() == needs_before, "Dialogue freezes both clock and needs")
	var external := session.clock.acquire_pause()
	game.dialogue.cancel()
	check(session.clock.is_paused(), "Dialogue cancellation preserves another system's clock lock")
	session.clock.release_pause(external)
	game.coordinator.request_pause()
	time = session.clock.total_minutes()
	await frames(6)
	check(session.clock.total_minutes() == time and not component.rest(30), "Pause freezes time and blocks rest input")
	game.coordinator.resume()
	check(not session.clock.is_paused(), "Resume releases the menu's clock token")
	# Use the actual input path at the three courtyard stations.
	for sample in [[Vector2(900, 815), "SnackStand", "hunger"], [Vector2(1000, 815), "WaterStation", "thirst"], [Vector2(1080, 675), "Bench", "fatigue"]]:
		player.position = sample[0]
		player.facing = Vector2.UP
		player.reset_motion()
		player.state.needs.set(sample[2], 60.0)
		await frames()
		check(game.ingame.get_detector().focused.get_parent().name == sample[1], "Station can be reached and selected: %s" % sample[1])
		var event := InputEventKey.new()
		event.physical_keycode = KEY_E
		event.pressed = true
		Input.parse_input_event(event)
		await frames(1)
		event = InputEventKey.new()
		event.physical_keycode = KEY_E
		Input.parse_input_event(event)
		check(player.state.needs.get(sample[2]) < 59.0, "E executes the configured needs action: %s" % sample[1])
	var move_lock := player.acquire_action_lock(SchoolCharacter.Action.MOVE)
	check(component.rest(1) and not player.can_act(SchoolCharacter.Action.MOVE) and player.can_act(SchoolCharacter.Action.INTERACT), "Rest releases its temporary token while preserving an existing movement lock")
	player.release_action_lock(move_lock)
	var npc_state := session.characters.get_state(&"seoyun")
	var prior := npc_state.needs.hunger
	game.ingame.load_zone("building", "Entrance")
	await frames()
	session.clock.advance_minutes(60)
	check(npc_state.needs.hunger > prior + 3.9, "NPC needs keep advancing after their scene is unloaded")
	player.position = Vector2(1120, 295)
	player.facing = Vector2.UP
	player.reset_motion()
	player.state.needs.fatigue = 60
	await frames()
	time = session.clock.total_minutes()
	check(game.ingame.get_detector().interact() and session.clock.total_minutes() == time + 60 and player.state.needs.fatigue < 41, "Classroom bed advances one hour and applies sleep recovery")
	var retained := npc_state.needs.hunger
	game.ingame.load_zone("courtyard", "FromBuilding")
	check(session.characters.get_state(&"seoyun").needs.hunger == retained, "Map reload does not reset or double-advance needs")
	game.dialogue.start(&"seoyun")
	check(session.clock.is_paused(), "Dialogue owns a clock pause before teardown")
	game.queue_free()
	await frames()
	check(not session.clock.is_paused(), "Scene teardown releases dialogue clock ownership")
	var saved_time := session.clock.total_minutes()
	await frames()
	check(session.clock.total_minutes() == saved_time, "Freed world leaves no live clock driver")

func run() -> void:
	create_timer(30.0).timeout.connect(func() -> void: quit(1))
	test_clock()
	test_needs()
	test_save()
	await test_game()
	print("LIFE TESTS: %d checks, %d failure(s)" % [checks, failures])
	quit(1 if failures else 0)
