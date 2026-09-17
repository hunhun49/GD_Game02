extends SceneTree

var checks: int = 0
var failures: int = 0
var _pause_requests: int = 0
var _resume_requests: int = 0
var _dialogue_requests: Array[StringName] = []

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

func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	# Headless windows may be 64x64 while UI layout uses a 1280px viewport.
	# These coordinates are already in viewport space; do not scale them twice.
	root.push_input(event, true)
	await frames(1)
	event = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	root.push_input(event, true)
	await frames(1)

func test_ui_alone() -> void:
	var ui: GameUI = load("res://scenes/ui/game_ui.tscn").instantiate()
	root.add_child(ui)
	ui.pause_requested.connect(func() -> void: _pause_requests += 1)
	ui.resume_requested.connect(func() -> void: _resume_requests += 1)
	ui.show_location("독립 UI 미리보기")
	ui.show_status("플레이어 없이 표시할 수 있습니다.")
	ui.show_interaction("학생", "대화하기")
	ui.show_movement_mode(4)
	var hud: SchoolHUD = ui.get_node("HUD")
	check(hud.displayed_location() == "독립 UI 미리보기" and hud.displayed_status() == "플레이어 없이 표시할 수 있습니다.", "HUD displays plain data without a world or player")
	check("학생" in hud.displayed_prompt() and "4방향" in hud.displayed_movement(), "Interaction and movement display require no gameplay objects")
	ui.show_interaction("", "")
	check(hud.displayed_prompt().is_empty(), "Clearing focus removes the presentation prompt")
	await key(KEY_ESCAPE)
	check(_pause_requests == 1 and not paused, "UI emits pause intent without changing global gameplay state")
	ui.set_paused(true)
	check(ui.is_pause_open() and not paused, "Opening the pause view alone never pauses gameplay")
	await key(KEY_ESCAPE)
	check(_resume_requests == 1 and _pause_requests == 1, "Pause view consumes resume input without emitting a second pause request")
	ui.set_paused(false)
	ui.queue_free()
	await frames(2)

func test_world_alone() -> void:
	var world: InGame = load("res://scenes/game/ingame.tscn").instantiate()
	root.add_child(world)
	world.dialogue_requested.connect(func(id: StringName) -> void: _dialogue_requests.append(id))
	await frames(2)
	check(world.zone_id == "courtyard" and is_instance_valid(world.current_zone), "InGame starts its map without a HUD, coordinator or dialogue UI")
	var player := world.get_player()
	var before := player.position
	Input.action_press("move_right")
	await frames(12)
	Input.action_release("move_right")
	check(player.position.x > before.x + 20, "Standalone world accepts movement input")
	player.position = Vector2(600, 540)
	player.facing = Vector2.UP
	player.reset_motion()
	await frames(2)
	await key(KEY_E)
	check(_dialogue_requests == [&"seoyun"] and not player.is_control_locked(), "Standalone world emits dialogue intent without owning a dialog system")
	var state := SessionState.new()
	world.configure(state, func() -> bool: return false)
	var old_zone := world.current_zone
	check(not world.load_zone("building", "Entrance") and world.current_zone == old_zone, "Transition guard can reject replacement without losing the old map")
	check(not player.is_control_locked() and not world.transitioning, "Rejected transition leaves gameplay usable")
	world.clear_transition_guard()
	check(world.load_zone("building", "Entrance"), "Standalone world can change maps without UI")
	world.queue_free()
	await frames(2)

func test_composed_game() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(2)
	var world: InGame = game.ingame
	var ui: GameUI = game.ui
	var hud: SchoolHUD = ui.get_node("HUD")
	var player := world.get_player()
	var resume_button: Button = ui.get_node("PauseMenu").get_node("%Resume")
	check("운동장" in hud.displayed_location(), "Coordinator publishes initial world location to HUD")
	await key(KEY_F2)
	check(world.movement_direction_count() == 4 and "4방향" in hud.displayed_movement(), "World movement mode signal updates HUD through coordinator")
	player.position = Vector2(600, 540)
	player.facing = Vector2.UP
	player.reset_motion()
	await frames(2)
	check("서윤" in hud.displayed_prompt(), "World focus produces a text-only HUD prompt")
	await key(KEY_ESCAPE)
	check(paused and ui.is_pause_open() and resume_button.has_focus(), "Pause intent pauses the game and focuses its resume button")
	var before := player.position
	Input.action_press("move_right")
	await frames(4)
	Input.action_release("move_right")
	await key(KEY_F2)
	check(player.position == before and world.movement_direction_count() == 4, "Paused game ignores movement and mode changes")
	await key(KEY_ESCAPE)
	check(not paused and not ui.is_pause_open() and not resume_button.has_focus(), "Escape resumes once and releases UI keyboard focus")
	await key(KEY_ESCAPE)
	await key(KEY_ENTER)
	check(not paused and not ui.is_pause_open(), "Focused resume button works with keyboard input")
	if paused:
		game.coordinator.resume()
	await key(KEY_ESCAPE)
	check(paused and resume_button.is_visible_in_tree(), "Pointer test starts with a visible paused menu")
	await click(resume_button)
	check(not paused and not ui.is_pause_open(), "Resume button works with real pointer input while gameplay is paused")
	if paused:
		game.coordinator.resume()
	await key(KEY_E)
	check(game.dialogue.is_busy() and ui.get_dialogue_view().is_open(), "Dialogue still starts from world interaction")
	ui.pause_requested.emit()
	check(not paused and not ui.is_pause_open(), "Coordinator rejects pause while a dialogue owns input")
	await key(KEY_ESCAPE)
	check(not game.dialogue.is_busy() and not paused, "Dialogue Escape closes dialogue without opening pause menu")
	check(world.load_zone("building", "Entrance") and "본관" in hud.displayed_location(), "Map replacement updates HUD without giving the world UI references")
	# A scene removed while it owns pause must not leave the next game frozen.
	await key(KEY_ESCAPE)
	check(paused, "Pause active before game teardown")
	game.queue_free()
	await frames(2)
	check(not paused, "Game teardown releases its own global pause")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(2)
	paused = true
	game.ui.resume_requested.emit()
	check(paused, "Coordinator never releases a pause owned by another system")
	game.queue_free()
	await frames(2)
	check(paused, "Game teardown preserves an external pause")
	paused = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(2)
	var detached: GameCoordinator = game.coordinator
	var detached_hud: SchoolHUD = game.ui.get_node("HUD")
	var displayed_mode := detached_hud.displayed_movement()
	game.remove_child(detached)
	await key(KEY_F2)
	check(game.ingame.movement_direction_count() == 4 and detached_hud.displayed_movement() == displayed_mode, "Removing the coordinator disconnects world-to-UI subscriptions")
	game.ui.pause_requested.emit()
	check(not paused, "Removed coordinator no longer receives UI requests")
	detached.free()
	game.queue_free()
	await frames(2)

func run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("UI/world tests timed out.")
		quit(1)
	)
	await test_ui_alone()
	await test_world_alone()
	await test_composed_game()
	print("UI/WORLD TESTS: %d checks, %d failure(s)" % [checks, failures])
	quit(1 if failures else 0)
