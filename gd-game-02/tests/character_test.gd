extends SceneTree

var checks: int = 0
var failures: int = 0
var requests: Array[StringName] = []

class CustomInteraction extends InteractionAction:
	func _execute(context: InteractionContext) -> bool:
		context.session.set_flag(&"custom_action", true)
		return true

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func test_state() -> void:
	var definition := CharacterDefinition.new()
	definition.max_health = 120.0
	var store := CharacterStateStore.new()
	var first := store.get_or_create(&"a", definition)
	var second := store.get_or_create(&"b", definition)
	first.current_health = 42.0
	first.facing = Vector2.LEFT
	first.activity = CharacterState.Activity.SLEEPING
	check(second.current_health == 120.0 and definition.max_health == 120.0, "Characters sharing a definition have independent mutable state")
	check(store.get_or_create(&"a", definition) == first, "Stable character ID returns the same state")
	check(store.get_or_create(&"", definition) == null, "Empty character IDs cannot enter the state store")
	var snapshot := store.snapshot()
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	var restored := CharacterStateStore.new()
	check(restored.restore(decoded), "Character states round-trip through JSON-compatible snapshots")
	var loaded := restored.get_or_create(&"a", definition)
	check(loaded.current_health == 42.0 and loaded.facing == Vector2.LEFT and loaded.activity == CharacterState.Activity.SLEEPING, "Restore preserves health, direction and activity")
	snapshot.characters[0].current_health = 999.0
	check(first.current_health == 42.0, "Snapshot mutation cannot change live state")
	check(not restored.restore(decoded) and restored.get_or_create(&"a", definition) == loaded, "Restore cannot replace a store already bound to live states")
	var baseline := loaded.snapshot()
	for replacement in [{"current_health": -1}, {"current_health": INF}, {"current_health": "42"}, {"facing": [1, 1]}, {"activity": 0.5}, {"character_id": "other"}]:
		var invalid := baseline.duplicate(true)
		invalid.merge(replacement, true)
		check(not loaded.restore(invalid) and loaded.snapshot() == baseline, "Invalid state is rejected atomically: %s" % replacement)
	var duplicate := decoded.duplicate(true)
	duplicate.characters.append(duplicate.characters[0])
	var empty := CharacterStateStore.new()
	check(not empty.restore(duplicate) and empty.snapshot().characters.is_empty(), "Duplicate saved IDs reject the entire snapshot")
	decoded.schema_version = 99
	check(not empty.restore(decoded), "Unknown save schema is rejected")

func test_characters_and_interactions() -> void:
	var world: InGame = load("res://scenes/game/ingame.tscn").instantiate()
	root.add_child(world)
	var session := SessionState.new()
	world.configure(session, Callable())
	world.dialogue_requested.connect(func(id: StringName) -> void: requests.append(id))
	await frames(2)
	var player := world.get_player()
	var npc: SchoolCharacter = world.current_zone.get_node("Seoyun")
	var ai := npc.controller as AIController
	var interaction: InteractionComponent = npc.get_node("Interaction")
	var detector := world.get_detector()
	check(player is SchoolCharacter and npc is SchoolCharacter and player.controller is PlayerController and ai != null, "Player and NPC share a character base with distinct controllers")
	check(player.character_id == &"player" and npc.character_id == &"seoyun", "Scene instances have stable explicit identities")
	check(interaction.target_name() == "서윤" and interaction.action is DialogueInteraction, "NPC label comes from character data and behavior from its action")
	player.position = Vector2(1220, 800)
	var before := npc.position
	Input.action_press("move_right")
	await frames(8)
	Input.action_release("move_right")
	check(npc.position == before, "Keyboard input never moves an AI-controlled NPC")
	ai.steer(Vector2(10, 10))
	await frames(15)
	check(npc.position.x > before.x and npc.position.y > before.y and absf(npc.velocity.length() - npc.definition.run_speed) < 0.01, "AI uses shared movement with normalized diagonal speed")
	ai.stop()
	await frames(12)
	check(npc.velocity.is_zero_approx(), "AI stop uses shared braking")
	ai.steer(Vector2.RIGHT)
	var outer := npc.acquire_control_lock()
	var inner := npc.acquire_control_lock()
	before = npc.position
	npc.release_control_lock(inner)
	await frames(8)
	check(npc.position == before and npc.is_control_locked(), "Independent lock owners cannot unlock another owner's NPC")
	npc.release_control_lock(outer)
	await frames(8)
	check(npc.position.x > before.x, "AI movement resumes after its final lock is released")
	ai.stop()
	npc.reset_motion()
	npc.position = Vector2(600, 490)
	player.position = Vector2(600, 540)
	player.reset_motion()
	player.facing = Vector2.UP
	await frames(2)
	check(detector.focused == interaction and interaction.focused, "Character interaction participates in existing proximity focus")
	check(detector.interact() and requests.back() == &"seoyun", "Interaction dispatches the character's dialogue action")
	var move_lock := player.acquire_action_lock(SchoolCharacter.Action.MOVE)
	check(not player.can_act(SchoolCharacter.Action.MOVE) and interaction.interact(detector.context), "Movement-only restrictions preserve permitted interactions")
	player.release_action_lock(move_lock)
	var action_lock := player.acquire_action_lock(SchoolCharacter.Action.INTERACT)
	check(player.can_act(SchoolCharacter.Action.MOVE) and not interaction.interact(detector.context), "Interaction-only restrictions preserve movement")
	player.release_action_lock(action_lock)
	for activity in [CharacterState.Activity.SLEEPING, CharacterState.Activity.INCAPACITATED]:
		player.state.activity = activity
		check(not player.can_act(SchoolCharacter.Action.MOVE) and not interaction.interact(detector.context), "Inactive character cannot move or interact: %d" % activity)
	player.state.activity = CharacterState.Activity.ACTIVE
	interaction.enabled = false
	check(not interaction.interact(detector.context), "Execution rechecks target availability after focus")
	detector.refresh()
	check(detector.focused == null and not interaction.focused, "Disabled target loses focus and highlight")
	interaction.enabled = true
	player.position = Vector2(600, 700)
	check(not interaction.interact(detector.context), "Direct interaction cannot bypass range validation")
	player.position = Vector2(600, 540)
	player.facing = Vector2.DOWN
	check(not interaction.interact(detector.context), "Direct interaction cannot bypass facing validation")
	player.facing = Vector2.UP
	var wall: SchoolProp = load("res://scenes/world_prop.tscn").instantiate()
	wall.position = Vector2(600, 520)
	wall.footprint = Vector2(60, 12)
	world.current_zone.add_child(wall)
	await frames(2)
	check(not interaction.interact(detector.context), "Direct interaction cannot bypass an obstructing wall")
	wall.queue_free()
	await frames(2)
	paused = true
	check(not interaction.interact(detector.context), "Paused gameplay rejects direct interaction")
	paused = false
	var existing_action := interaction.action
	interaction.action = CustomInteraction.new()
	check(interaction.interact(detector.context) and session.has_flag(&"custom_action"), "A new action subclass works without changing character, detector or world")
	interaction.action = existing_action
	# A second loaded world must not contribute interaction candidates.
	var other: InGame = load("res://scenes/game/ingame.tscn").instantiate()
	root.add_child(other)
	other.position = Vector2(3000, 0)
	var foreign: InteractionComponent = other.current_zone.get_node("Seoyun/Interaction")
	foreign.get_parent().global_position = Vector2(640, 490)
	await frames(2)
	detector.refresh()
	check(not detector.candidates.has(foreign), "Detector scopes candidates to its own current zone")
	other.queue_free()
	await frames(2)
	npc.state.current_health = 37.0
	npc.state.facing = Vector2.RIGHT
	var retained := npc.state
	check(world.load_zone("building", "Entrance"), "Character migration preserves map transitions")
	await frames(2)
	check(not is_instance_valid(npc) and retained.current_health == 37.0, "Session retains character data after the scene node is freed")
	check(world.load_zone("courtyard", "FromBuilding"), "Return map loads after NPC removal")
	await frames(2)
	npc = world.current_zone.get_node("Seoyun")
	check(npc.state == retained and npc.state.facing == Vector2.RIGHT, "Recreated NPC rebinds its saved state by character ID")
	check(detector.focused == null and detector.candidates.all(func(target: InteractionComponent) -> bool: return world.current_zone.is_ancestor_of(target)), "Map replacement clears stale component references")
	world.queue_free()
	await frames(2)

func run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("Character tests timed out.")
		quit(1)
	)
	test_state()
	await test_characters_and_interactions()
	print("CHARACTER TESTS: %d checks, %d failure(s)" % [checks, failures])
	quit(1 if failures else 0)
