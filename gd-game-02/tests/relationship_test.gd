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

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	Input.parse_input_event(event)
	await frames(1)

func test_graph() -> void:
	var service := RelationshipService.new()
	var changes: Array = []
	service.affinity_changed.connect(func(a: StringName, b: StringName, old: float, current: float) -> void: changes.append([a, b, old, current]))
	check(service.get_affinity(&"a", &"b") == 0 and service.snapshot().edges.is_empty(), "Reading a missing relationship does not allocate an edge")
	check(service.add_affinity(&"a", &"b", 70) and service.add_affinity(&"b", &"a", 20), "Both directions can be written independently")
	check(service.get_affinity(&"a", &"b") == 70 and service.get_affinity(&"b", &"a") == 20, "Directed affinity values are asymmetric")
	service.add_affinity(&"a", &"b", 90)
	service.add_affinity(&"b", &"a", -900)
	check(service.get_affinity(&"a", &"b") == 100 and service.get_affinity(&"b", &"a") == -100, "Affinity changes clamp to configured bounds")
	var count := changes.size()
	service.add_affinity(&"a", &"b", 10)
	check(changes.size() == count, "Clamped no-op does not emit a false relationship change")
	check(changes[0] == [&"a", &"b", 0.0, 70.0], "Change signals include direction and before/after values")
	check(not service.add_affinity(&"a", &"a", 1) and not service.add_affinity(&"", &"b", 1) and not service.add_affinity(&"a", &"b", NAN), "Invalid IDs, self-relations and non-finite deltas are rejected")
	var data: Dictionary = JSON.parse_string(JSON.stringify(service.snapshot()))
	var restored := RelationshipService.new()
	check(restored.restore(data) and restored.get_affinity(&"a", &"b") == 100 and restored.get_affinity(&"b", &"a") == -100, "JSON round-trip preserves both independent edges")
	data.edges[0].affinity = 17
	check(service.get_affinity(&"a", &"b") == 100, "Snapshots cannot mutate the live graph")
	service.set_affinity(&"a", &"b", 0)
	check(service.snapshot().edges.size() == 1 and service.get_affinity(&"b", &"a") == -100, "Returning to default removes only the affected edge")
	var invalids: Array[Dictionary] = [
		{"schema_version": true, "edges": []},
		{"schema_version": 1, "edges": [{"from": "a", "to": "a", "affinity": 2}]},
		{"schema_version": 1, "edges": [{"from": "a", "to": "b", "affinity": 101}]},
		{"schema_version": 1, "edges": [{"from": "a", "to": "b", "affinity": INF}]},
		{"schema_version": 1, "edges": [{"from": "a", "to": "b", "affinity": "5"}]},
	]
	var duplicate := restored.snapshot()
	duplicate.edges.append(duplicate.edges[0].duplicate())
	invalids.append(duplicate)
	for invalid in invalids:
		var graph := RelationshipService.new()
		check(not graph.restore(invalid) and graph.snapshot().edges.is_empty(), "Invalid graph restore is atomic: %s" % invalid)
	check(not restored.restore(service.snapshot()), "Restoring cannot replace a graph already in use")

func test_effects() -> void:
	var session := SessionState.new()
	var handler := AffinityDialogueEffect.new(session)
	var payload := {"from": "seoyun", "to": "player", "amount": 5.0, "once_key": "first_reward"}
	check(handler.validate(payload).is_empty(), "Affinity effect validates directional IDs and optional one-time key")
	for changed in [{"amount": "5"}, {"amount": true}, {"amount": INF}, {"to": "seoyun"}, {"from": " "}, {"once_key": ""}, {"typo": 1}]:
		var invalid := payload.duplicate()
		invalid.merge(changed, true)
		check(not handler.validate(invalid).is_empty(), "Malformed affinity effect is rejected: %s" % changed)
	var registry := DialogueEffectRegistry.new()
	registry.register_handler(&"add_affinity", handler)
	registry.seal()
	var effects: Array[DialogueEffect] = [DialogueEffect.new(&"add_affinity", payload)]
	check(registry.execute(effects) and session.relationships.get_affinity(&"seoyun", &"player") == 5, "Validated effect changes the requested direction")
	registry.execute(effects)
	check(session.relationships.get_affinity(&"seoyun", &"player") == 5 and session.has_flag(&"first_reward"), "One-time effect cannot farm affinity by replaying dialogue")
	check(session.relationships.get_affinity(&"player", &"seoyun") == 0, "Affinity effect never implicitly changes the reverse edge")
	effects = [DialogueEffect.new(&"add_affinity", {"from": "a", "to": "b", "amount": 3}), DialogueEffect.new(&"add_affinity", {"amount": 3})]
	check(not registry.execute(effects) and session.relationships.get_affinity(&"a", &"b") == 0, "Invalid effect batch applies no partial relationship changes")

func test_game() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	var player: SchoolPlayer = game.ingame.get_player()
	player.position = Vector2(600, 540)
	player.facing = Vector2.UP
	player.reset_motion()
	await frames()
	await key(KEY_E)
	check(game.dialogue.is_busy() and "전학생" in game.ui.get_dialogue_view().displayed_text(), "New acquaintance selects the original dialogue through E")
	await key(KEY_ESCAPE)
	check(game.session_state.relationships.get_affinity(&"seoyun", &"player") == 0 and not game.session_state.has_flag(&"seoyun_first_greeting_reward"), "Cancelling a dialogue grants no relationship reward")
	await key(KEY_E)
	for i in range(3):
		await key(KEY_SPACE)
	check(game.session_state.relationships.get_affinity(&"seoyun", &"player") == 5, "Completing the introduction increases NPC-to-player affinity")
	check("서윤" in game.ui.get_node("HUD").displayed_relationship() and "+5" in game.ui.get_node("HUD").displayed_relationship(), "Relationship changes are displayed through value-only HUD messages")
	await key(KEY_E)
	check("다시 왔네" in game.ui.get_dialogue_view().displayed_text(), "Affinity threshold selects the friendly revisit dialogue")
	game.dialogue.cancel()
	game.dialogue.start(&"seoyun")
	for i in range(3):
		game.dialogue.advance()
	check(game.session_state.relationships.get_affinity(&"seoyun", &"player") == 5, "Even direct replay of the original dialogue cannot duplicate its reward")
	game.ingame.load_zone("building", "Entrance")
	game.ingame.load_zone("courtyard", "FromBuilding")
	check(game.session_state.relationships.get_affinity(&"seoyun", &"player") == 5, "Relationships survive NPC and map replacement")
	game.queue_free()
	await frames()

func run() -> void:
	create_timer(30.0).timeout.connect(func() -> void: quit(1))
	test_graph()
	test_effects()
	await test_game()
	print("RELATIONSHIP TESTS: %d checks, %d failure(s)" % [checks, failures])
	quit(1 if failures else 0)
