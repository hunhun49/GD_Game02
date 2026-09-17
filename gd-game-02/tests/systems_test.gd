extends SceneTree

var failures: int = 0
var checks: int = 0
var game: Node
var player: SchoolPlayer
const ACTIONS := ["move_left", "move_right", "move_up", "move_down"]

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

func release_movement() -> void:
	for action in ACTIONS:
		Input.action_release(action)

func place(at: Vector2, direction: Vector2 = Vector2.UP) -> void:
	release_movement()
	player.position = at
	player.facing = direction
	player.reset_motion()
	await frames(3)

func input_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = InputEventKey.new()
	event.physical_keycode = key
	Input.parse_input_event(event)
	await frames(1)

func walk(direction: Vector2, count: int) -> void:
	if direction.x != 0:
		Input.action_press("move_right" if direction.x > 0 else "move_left")
	if direction.y != 0:
		Input.action_press("move_down" if direction.y > 0 else "move_up")
	await frames(count)
	release_movement()

func run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("Test timeout: a runtime error may have interrupted the suite.")
		quit(1)
	)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	player = game.ingame.get_player()
	await frames(5)
	check(player.movement.mode == MovementComponent.MovementMode.EIGHT_DIRECTIONS, "Eight-direction movement is the default")
	var resting := player.position
	await frames(30)
	check(player.position == resting, "Idle player does not fall or drift")
	var speeds: Array[float] = []
	var facings: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		await place(Vector2(1220, 800))
		var start := player.position
		await walk(direction, 24)
		var displacement := player.position - start
		# A render frame can contain multiple physics ticks. Compare actual steady
		# speed rather than assuming each frames() iteration spans one physics tick.
		speeds.append(player.velocity.length())
		check(displacement.length() > 60 and displacement.normalized().dot(direction.normalized()) > 0.99, "Movement follows direction %s" % direction)
		check(facings.has(player.facing), "Artwork retains a cardinal facing for %s" % direction)
	check(speeds.all(func(speed: float) -> bool: return absf(speed - player.definition.run_speed) < 0.01), "Diagonal and cardinal movement reach the same configured speed")
	await frames(12)
	check(player.velocity.is_zero_approx(), "Releasing input brakes to a stop")
	# Physical W/S and arrow-key mappings, plus the real F2 toggle.
	await place(Vector2(1220, 800))
	await input_key(KEY_W)
	check(player.position.y < 800, "Physical W key moves up")
	await input_key(KEY_DOWN)
	check(player.facing == Vector2.DOWN, "Down-arrow key changes facing down")
	await input_key(KEY_F2)
	check(player.movement.mode == MovementComponent.MovementMode.FOUR_DIRECTIONS and "4방향" in game.ui.get_node("HUD").displayed_movement(), "F2 selects four-direction movement and updates HUD")
	await place(Vector2(1220, 800))
	Input.action_press("move_right")
	await frames(6)
	Input.action_press("move_up")
	await frames(1)
	check(absf(player.velocity.x) < 0.01 and player.velocity.y < 0, "Four-direction turn chooses the newly pressed axis without diagonal drift")
	await frames(8)
	check(player.facing == Vector2.UP and absf(player.velocity.x) < 0.01, "Held diagonal input keeps a stable cardinal direction in four-direction mode")
	release_movement()
	await input_key(KEY_F2)
	check(player.movement.mode == MovementComponent.MovementMode.EIGHT_DIRECTIONS, "F2 returns to eight-direction movement")
	# Collisions use ground footprints rather than full artwork rectangles.
	await place(Vector2(800, 420))
	await walk(Vector2.UP, 40)
	check(player.position.y >= 359, "School building blocks entry through its facade")
	await place(Vector2(320, 720))
	await walk(Vector2.UP, 35)
	check(player.position.y >= 659, "Tree trunk blocks movement")
	await place(Vector2(365, 650))
	await walk(Vector2.UP, 35)
	check(player.position.y < 570, "Player can walk under the edge of a tree canopy")
	# Door interactions use real input, without platformer floor checks.
	await place(Vector2(800, 420))
	await input_key(KEY_E)
	check(game.dialogue.is_busy() and game.ingame.zone_id == "courtyard", "Locked door opens requirement dialogue")
	await input_key(KEY_ESCAPE)
	check(not game.dialogue.is_busy() and not paused, "Esc cancels dialogue without pausing gameplay")
	await place(Vector2(600, 540))
	await input_key(KEY_E)
	check(game.ui.get_dialogue_view().displayed_speaker() == "서윤 · 반장", "Facing an NPC and pressing E starts the correct dialogue")
	var before := player.position
	await walk(Vector2.RIGHT, 10)
	check(player.position == before and player.is_control_locked(), "Dialogue locks player movement")
	await input_key(KEY_ESCAPE)
	check(not game.session_state.has_flag(&"building_access"), "Cancelling dialogue does not unlock the building")
	await input_key(KEY_E)
	for i in range(3):
		await input_key(KEY_SPACE)
	check(game.session_state.has_flag(&"building_access") and not game.dialogue.is_busy(), "Completing dialogue grants building access")
	await place(Vector2(800, 420))
	await input_key(KEY_E)
	await frames(4)
	check(game.ingame.zone_id == "building" and player.position.distance_to(Vector2(180, 845)) < 1, "Unlocked door loads the classroom at its safe spawn")
	await place(Vector2(365, 410))
	game.ingame.get_detector().refresh()
	check(game.ingame.get_detector().candidates.size() == 2 and is_instance_valid(game.ingame.get_detector().focused) and game.ingame.get_detector().focused.get_parent().name == "Minjae", "Distance and facing rank nearby interaction targets")
	await input_key(KEY_TAB)
	check(is_instance_valid(game.ingame.get_detector().focused) and game.ingame.get_detector().focused.get_parent().name == "Timetable", "Tab cycles to the nearby notice board")
	player.facing = Vector2.DOWN
	await frames(2)
	check(game.ingame.get_detector().focused == null, "Targets behind the player are not selected")
	player.facing = Vector2.UP
	var wall: SchoolProp = load("res://scenes/world_prop.tscn").instantiate()
	wall.position = Vector2(340, 402)
	wall.footprint = Vector2(14, 28)
	game.ingame.current_zone.add_child(wall)
	await frames(3)
	check(not game.ingame.get_detector().candidates.has(game.ingame.current_zone.get_node("Minjae/Interaction")), "Walls block interaction rays")
	wall.queue_free()
	await frames(2)
	await place(Vector2(320, 445))
	await walk(Vector2.UP, 35)
	check(player.position.y >= 394, "NPC footprint blocks walking through the NPC")
	await place(Vector2(540, 520))
	await walk(Vector2.UP, 40)
	check(player.position.y >= 449, "Desk footprint blocks movement")
	await place(Vector2(80, 200))
	await walk(Vector2(-1, -1), 60)
	check(player.position.x >= 33 and player.position.y >= 149, "Diagonal motion cannot escape the room boundary")
	await place(Vector2(1150, 875))
	await input_key(KEY_E)
	check(game.ingame.checkpoint.distance_to(player.position) < 1, "Checkpoint records a reachable position outside its own collider")
	await walk(Vector2.LEFT, 20)
	await input_key(KEY_R)
	check(player.position.distance_to(game.ingame.checkpoint) < 1, "R returns the player to the checkpoint")
	player.position = Vector2(-100, 400)
	await frames(3)
	check(player.position.distance_to(game.ingame.checkpoint) < 1, "Out-of-bounds recovery returns to the checkpoint")
	await input_key(KEY_ESCAPE)
	before = player.position
	await walk(Vector2.RIGHT, 6)
	check(paused and player.position == before, "Pause freezes gameplay")
	await input_key(KEY_ESCAPE)
	check(not paused, "Pause can be resumed")
	await place(Vector2(180, 875), Vector2.DOWN)
	await input_key(KEY_E)
	await frames(4)
	check(game.ingame.zone_id == "courtyard" and game.session_state.has_flag(&"building_access"), "Exit returns outside while preserving access")
	check(player.position.distance_to(Vector2(800, 410)) < 1, "Return spawn is outside the solid building")
	var targets := get_nodes_in_group("interactables")
	check(targets.size() == 9 and targets.all(func(target: Node) -> bool: return game.ingame.current_zone.is_ancestor_of(target)), "Zone changes remove stale interaction targets")
	game.queue_free()
	await frames(2)
	print("SYSTEM TESTS: %d checks, %d failure(s)" % [checks, failures])
	quit(1 if failures else 0)
