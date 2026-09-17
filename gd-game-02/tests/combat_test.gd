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

func place(player: SchoolCharacter, at: Vector2, direction: Vector2 = Vector2.UP) -> void:
	player.position = at
	player.facing = direction
	player.reset_motion()
	await frames()

func test_health_and_stamina() -> void:
	var world: InGame = load("res://scenes/game/ingame.tscn").instantiate()
	root.add_child(world)
	await frames()
	var player := world.get_player()
	var health: HealthComponent = player.get_node("Health")
	var stamina: StaminaComponent = player.get_node("Stamina")
	check(health.current() == 100 and health.maximum() == 100 and stamina.current() == 100, "Character components bind independent health and stamina state")
	for amount in [-1.0, 0.0, INF, NAN]:
		check(health.take_damage(DamageEvent.new(&"test", amount)) == 0 and health.current() == 100, "Invalid damage is rejected: %s" % amount)
	var first := health.acquire_invulnerability()
	var second := health.acquire_invulnerability()
	health.release_invulnerability(second)
	check(health.take_damage(DamageEvent.new(&"test", 25)) == 0, "Invulnerability owners cannot release another owner's protection")
	health.release_invulnerability(first)
	check(health.take_damage(DamageEvent.new(&"test", 25)) == 25 and health.current() == 75, "Damage is applied after the last protection is released")
	check(health.heal(50) == 25 and health.current() == 100, "Healing reports actual recovery and clamps at maximum")
	check(health.heal(NAN) == 0 and health.heal(-5) == 0, "Invalid healing is rejected")
	var knockouts: Array[bool] = []
	var reentrant: Array[float] = []
	health.incapacitated.connect(func() -> void: knockouts.append(true))
	var recursive := func(_event: DamageEvent, _applied: float) -> void: reentrant.append(health.take_damage(DamageEvent.new(&"recursive", 1)))
	health.damaged.connect(recursive)
	check(health.take_damage(DamageEvent.new(&"test", 999)) == 100 and health.current() == 0, "Overkill clamps health at zero")
	health.damaged.disconnect(recursive)
	check(knockouts.size() == 1 and reentrant == [0.0] and player.state.activity == CharacterState.Activity.INCAPACITATED, "Knockout is emitted once and damage callbacks cannot reenter")
	check(not player.can_act(SchoolCharacter.Action.MOVE) and not player.can_act(SchoolCharacter.Action.INTERACT) and not player.can_act(SchoolCharacter.Action.ATTACK), "Zero health blocks movement, interaction and attack")
	check(health.heal(25) == 0 and health.take_damage(DamageEvent.new(&"test", 1)) == 0 and knockouts.size() == 1, "Ordinary healing cannot implicitly revive and a downed actor cannot be damaged again")
	var held := player.acquire_control_lock()
	check(health.revive(40) and health.current() == 40 and not player.can_act(SchoolCharacter.Action.MOVE), "Explicit revival preserves external action locks")
	player.release_control_lock(held)
	check(player.can_act(SchoolCharacter.Action.ATTACK) and not health.revive(100), "Revival restores activity only for depleted health")
	var fatigue := player.state.needs.fatigue
	check(stamina.spend(80) and stamina.current() == 20 and player.state.needs.fatigue == fatigue, "Spending short-term stamina does not alter long-term fatigue")
	check(not stamina.spend(21) and not stamina.spend(-1) and not stamina.spend(INF), "Overspending and invalid stamina costs are rejected")
	var token := player.acquire_control_lock()
	var before := stamina.current()
	await create_timer(1.2).timeout
	check(stamina.current() == before, "Control locks freeze stamina recovery")
	player.release_control_lock(token)
	await create_timer(1.3).timeout
	check(stamina.current() > before and stamina.current() < stamina.maximum(), "Stamina recovers in real time after its recovery delay")
	stamina.spend(5)
	check(player.get_node("Needs").rest(30) and stamina.current() == stamina.maximum(), "Rest restores stamina through the optional sibling component")
	stamina.spend(30)
	check(player.get_node("Needs").rest(60, true) and stamina.current() == stamina.maximum(), "Sleep also restores the separate action resource")
	paused = true
	check(not stamina.spend(1) and health.take_damage(DamageEvent.new(&"test", 1)) == 0 and not health.revive(100), "Paused components reject direct gameplay mutations")
	paused = false
	world.queue_free()
	await frames()

func test_attack_validation() -> void:
	var world: InGame = load("res://scenes/game/ingame.tscn").instantiate()
	root.add_child(world)
	await frames()
	var player := world.get_player()
	var combat: CombatComponent = player.get_node("Combat")
	var stamina: StaminaComponent = player.get_node("Stamina")
	var dummy: SchoolCharacter = world.current_zone.get_node("TrainingDummy")
	dummy.controller.set_physics_process(false)
	var target: CombatComponent = dummy.get_node("Combat")
	var health: HealthComponent = dummy.get_node("Health")
	combat.attack = combat.attack.duplicate()
	combat.attack.cooldown_seconds = 0.1
	await place(player, Vector2(1420, 750))
	check(not combat.try_attack(target) and stamina.current() == 100, "Explicit out-of-range target is rejected without spending stamina")
	await place(player, Vector2(1420, 625), Vector2.DOWN)
	check(not combat.try_attack(target), "Attacks cannot hit a target behind the facing cone")
	player.facing = Vector2.UP
	var wall: SchoolProp = load("res://scenes/world_prop.tscn").instantiate()
	wall.position = Vector2(1420, 600)
	wall.footprint = Vector2(50, 8)
	world.current_zone.add_child(wall)
	await frames()
	check(not combat.try_attack(target), "Walls block melee attacks")
	wall.queue_free()
	await frames()
	target.team = 1
	check(not combat.try_attack(target), "Team mask rejects friendly targets")
	target.team = 2
	target.enabled = false
	check(not combat.try_attack(target), "Disabled combat component is excluded from combat")
	target.enabled = true
	check(not combat.valid_target(combat) and world.current_zone.get_node("Seoyun").get_node_or_null("Combat") == null, "Self-attacks and ordinary noncombat NPCs are excluded")
	var locks := player.acquire_control_lock()
	check(not combat.try_attack(target), "Existing full control locks also block newly added attacks")
	player.release_control_lock(locks)
	var hits: Array[float] = []
	combat.hit_landed.connect(func(_id: StringName, _name: String, amount: float) -> void: hits.append(amount))
	check(combat.try_attack(target) and health.current() == 75 and stamina.current() == 80, "Successful attack applies one hit and one stamina cost")
	check(not combat.try_attack(target) and health.current() == 75 and stamina.current() == 80, "Cooldown prevents repeated hits and duplicate resource spending")
	await create_timer(0.15).timeout
	stamina.spend(stamina.current())
	check(not combat.try_attack(target) and health.current() == 75, "Insufficient stamina prevents damage")
	stamina.restore_full()
	player.facing = Vector2.DOWN
	check(combat.try_attack() and hits.size() == 1 and stamina.current() == 80, "An empty swing consumes its normal cooldown and stamina without hitting")
	await create_timer(0.15).timeout
	player.facing = Vector2.UP
	var other: InGame = load("res://scenes/game/ingame.tscn").instantiate()
	root.add_child(other)
	other.position = Vector2(3000, 0)
	var foreign: CombatComponent = other.current_zone.get_node("TrainingDummy/Combat")
	foreign.actor().global_position = Vector2(1420, 570)
	check(not combat.try_attack(foreign), "Combat cannot cross independently composed world scopes")
	other.queue_free()
	await frames()
	# Signal listeners can move or delete targets: execution checks again after dispatch.
	var move_target := func(_direction: Vector2) -> void: dummy.position = Vector2(1450, 300)
	combat.attack_started.connect(move_target)
	check(combat.try_attack(target) and health.current() == 75, "Moving target during attack notification cannot bypass range validation")
	combat.attack_started.disconnect(move_target)
	await create_timer(0.15).timeout
	dummy.position = Vector2(1420, 570)
	var recurse_results: Array[bool] = []
	var recursive := func(_direction: Vector2) -> void: recurse_results.append(combat.try_attack(target))
	combat.attack_started.connect(recursive)
	check(combat.try_attack(target) and health.current() == 50 and recurse_results == [false], "Attack notifications cannot recursively trigger extra attacks")
	combat.attack_started.disconnect(recursive)
	dummy.state.current_health = 0
	dummy.state.activity = CharacterState.Activity.INCAPACITATED
	var saved := dummy.state
	world.load_zone("building", "Entrance")
	world.load_zone("courtyard", "FromBuilding")
	check(world.current_zone.get_node("TrainingDummy").state == saved and saved.current_health == 0, "Map replacement preserves a defeated character's state")
	world.queue_free()
	await frames()

func test_game_input() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	var player: SchoolPlayer = game.ingame.get_player()
	var combat: CombatComponent = player.get_node("Combat")
	var health: HealthComponent = player.get_node("Health")
	var stamina: StaminaComponent = player.get_node("Stamina")
	var target: CombatComponent = game.ingame.current_zone.get_node("TrainingDummy/Combat")
	await place(player, Vector2(1420, 625))
	await key(KEY_J)
	check(target.health().current() == 75 and stamina.current() <= 80, "Physical J input executes the player's attack")
	await create_timer(0.85).timeout
	check(health.current() == 90, "Training controller responds with a delayed counterattack")
	check("체력 90" in game.ui.get_node("HUD").displayed_combat() and "스태미나" in game.ui.get_node("HUD").displayed_combat(), "HUD displays independent health and stamina values")
	game.dialogue.start(&"notice")
	var target_health := target.health().current()
	var remaining := combat.cooldown_remaining()
	var resource := stamina.current()
	await key(KEY_J)
	await create_timer(0.2).timeout
	check(target.health().current() == target_health and stamina.current() == resource and combat.cooldown_remaining() == remaining, "Dialogue suspends attacks, cooldowns and stamina recovery")
	check(health.take_damage(DamageEvent.new(&"environment", 10)) == 0, "Dialogue also protects against direct environmental damage")
	var external := health.acquire_invulnerability()
	game.dialogue.cancel()
	check(not health.can_take_damage(), "Dialogue releases only its own invulnerability token")
	health.release_invulnerability(external)
	game.coordinator.request_pause()
	await key(KEY_J)
	check(target.health().current() == target_health and not combat.try_attack(target), "Pause prevents both input and direct attacks")
	game.coordinator.resume()
	health.take_damage(DamageEvent.new(&"test", 1000))
	check(game.ingame.can_pause() and player.can_act(SchoolCharacter.Action.RECOVER), "Downed player can still pause and explicitly recover")
	var before := player.position
	Input.action_press("move_left")
	await frames(4)
	Input.action_release("move_left")
	await key(KEY_J)
	await key(KEY_E)
	check(player.position == before and health.current() == 0 and not game.dialogue.is_busy(), "Downed player cannot move, attack or interact")
	await key(KEY_R)
	check(health.current() == 100 and stamina.current() == 100 and player.position.distance_to(game.ingame.checkpoint) < 1, "R explicitly revives at the checkpoint with restored action resources")
	await place(player, Vector2(1420, 625))
	target.health().take_damage(DamageEvent.new(&"test", 1000))
	await key(KEY_E)
	check(target.health().current() == 100 and target.actor().state.activity == CharacterState.Activity.ACTIVE, "E resets the defeated training target")
	var saved_clock: GameClock = game.session_state.clock
	game.dialogue.start(&"notice")
	game.queue_free()
	await frames()
	check(not saved_clock.is_paused(), "Combat integration preserves dialogue cleanup on scene teardown")
	# Removing the opt-in combat capability must not break walking/UI composition.
	var world: InGame = load("res://scenes/game/ingame.tscn").instantiate()
	world.get_node("Player/Combat").free()
	root.add_child(world)
	await frames()
	await key(KEY_J)
	check(world.zone_id == "courtyard" and world.get_player().get_node_or_null("Combat") == null, "World remains usable when the player's Combat component is omitted")
	world.queue_free()
	await frames()

func test_save() -> void:
	var session := SessionState.new()
	var definition: CharacterDefinition = load("res://data/characters/player.tres")
	var state := session.characters.get_or_create(&"player", definition)
	state.current_health = 0
	state.activity = CharacterState.Activity.INCAPACITATED
	state.current_stamina = 23
	var data: Dictionary = JSON.parse_string(JSON.stringify(session.snapshot()))
	var restored := SessionState.new()
	check(restored.restore(data) and restored.characters.get_state(&"player").current_stamina == 23 and restored.characters.get_state(&"player").current_health == 0, "Session snapshot preserves health, knockout and stamina")
	for version in [1, 2]:
		var legacy := data.duplicate(true)
		legacy.characters.schema_version = version
		legacy.characters.characters[0].erase("current_stamina")
		var migrated := SessionState.new()
		check(migrated.restore(legacy) and migrated.characters.get_state(&"player").current_stamina == -1, "Old character schema migrates optional stamina: %d" % version)
	for value in [-2.0, INF, "20"]:
		var bad := data.duplicate(true)
		bad.characters.characters[0].current_stamina = value
		var empty := SessionState.new()
		check(not empty.restore(bad) and empty.characters.all_states().is_empty(), "Malformed stamina snapshot rejects the entire load: %s" % value)

func run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("Combat tests timed out.")
		quit(1)
	)
	test_save()
	await test_health_and_stamina()
	await test_attack_validation()
	await test_game_input()
	print("COMBAT TESTS: %d checks, %d failure(s)" % [checks, failures])
	quit(1 if failures else 0)
