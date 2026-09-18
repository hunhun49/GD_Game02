extends SceneTree

var checks := 0
var failures := 0
var world: InGame
var player: SchoolCharacter
var robot: SchoolCharacter
var a: CombatComponent
var b: CombatComponent

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func prepare() -> void:
	world = load("res://scenes/game/ingame.tscn").instantiate()
	root.add_child(world)
	await frames()
	player = world.get_player()
	robot = world.current_zone.get_node("TrainingDummy")
	a = player.get_node("Combat")
	b = robot.get_node("Combat")
	player.controller.set_physics_process(false)
	robot.controller.set_physics_process(false)
	a.set_physics_process(false)
	b.set_physics_process(false)
	a.attack = a.attack.duplicate()
	b.attack = b.attack.duplicate()
	reset()
	await frames()

func reset() -> void:
	a.reset_encounter()
	b.reset_encounter()
	player.position = Vector2(1420, 625)
	player.facing = Vector2.UP
	robot.position = Vector2(1420, 570)
	robot.facing = Vector2.DOWN
	for c in [a, b]:
		if c.health().current() == 0:
			c.health().revive(c.health().maximum())
		else:
			c.health().heal(c.health().maximum())

func strike(source: CombatComponent, target: CombatComponent) -> void:
	check(source.try_attack(target), "Attack can enter windup")
	source._physics_process(source.attack.windup_seconds + 0.001)
	world.get_node("CombatResolver").flush()

func test_rules() -> void:
	check(HitResolver.resolve(true, true, true) == HitResolver.Outcome.DEFLECT, "Pure resolver chooses timed defense")
	check(HitResolver.resolve(false, true, true) == HitResolver.Outcome.HIT, "Dangerous attacks bypass both defenses")
	for field in ["windup_seconds", "active_seconds", "recovery_seconds", "posture_damage"]:
		var bad := a.attack.duplicate() as AttackDefinition
		bad.set(field, NAN)
		check(not bad.is_valid(), "Non-finite attack property rejected: " + field)
	var initial := b.health().current()
	check(a.try_attack(b) and b.health().current() == initial and a.phase == CombatComponent.Phase.WINDUP, "Attack commitment does not apply early damage")
	check(not a.try_attack(b) and not player.can_act(SchoolCharacter.Action.MOVE), "Windup prevents double attack and sliding")
	a._physics_process(0.121)
	world.get_node("CombatResolver").flush()
	check(b.health().current() == initial - 12 and a.phase == CombatComponent.Phase.ACTIVE, "Active phase applies damage at the telegraphed time")
	a._physics_process(0.02)
	world.get_node("CombatResolver").flush()
	check(b.health().current() == initial - 12, "Multi-frame hit window cannot hit one target twice")
	a._physics_process(0.05)
	world.get_node("CombatResolver").flush()
	check(a.phase == CombatComponent.Phase.RECOVERY and not a.set_guard(true), "Recovery commits the player; guard cannot cancel a completed strike")
	a._physics_process(0.5)
	world.get_node("CombatResolver").flush()
	check(a.phase == CombatComponent.Phase.READY and player.can_act(SchoolCharacter.Action.MOVE), "Recovery returns movement and attack permission")
	reset()
	a.try_attack(b)
	check(a.set_guard(true) and a.phase == CombatComponent.Phase.READY and a.guard().holding, "Early windup can be canceled into guard")
	a._physics_process(0.5)
	world.get_node("CombatResolver").flush()
	check(b.health().current() == b.health().maximum(), "Canceled windup cannot cause a later hit")
	reset()
	a.try_attack(b)
	a._physics_process(0.08)
	world.get_node("CombatResolver").flush()
	check(not a.set_guard(true), "Late windup cannot be canceled")
	reset()
	player.get_node("Stamina").spend(100)
	for i in range(10):
		a.try_attack(b)
		a._physics_process(0.5)
		world.get_node("CombatResolver").flush()
	check(b.health().current() == 40 and player.get_node("Stamina").current() == 0, "Ten attacks continue at zero stamina without regenerating/spending it")

func test_defense() -> void:
	reset()
	b.set_guard(true, false)
	strike(a, b)
	check(b.health().current() == 160 and b.posture().current == 8, "Ordinary guard routes pressure to posture, not health")
	reset()
	a.set_guard(true)
	strike(b, a)
	check(a.health().current() == 100 and a.posture().current == 0 and b.posture().current == 12, "Timed guard adds attacker posture and preserves defender health")
	reset()
	a.set_guard(true)
	a.guard().tick(0.13)
	strike(b, a)
	check(a.health().current() == 100 and a.posture().current == 18, "Expired deflect window becomes ordinary guard")
	reset()
	player.facing = Vector2.DOWN
	a.set_guard(true)
	strike(b, a)
	check(a.health().current() == 90, "Guard does not protect an attacker behind the player")
	reset()
	a.set_guard(true)
	a.set_guard(false)
	a.set_guard(true)
	check(not a.guard().can_deflect() and a.guard().holding, "Rapid guard spam cannot continuously refresh deflect but still guards")
	a.set_guard(false)
	a.guard().tick(0.2)
	a.set_guard(true)
	check(a.guard().can_deflect(), "Guard rearms after its minimum interval")
	reset()
	a.posture().add(99)
	a.set_guard(true)
	strike(b, a)
	check(not a.is_staggered() and a.health().current() == 100, "Successful deflect remains possible at high posture")
	reset()
	a.set_guard(true, false)
	a.posture().add(90)
	strike(b, a)
	check(a.is_staggered() and a.health().current() == 100 and not player.can_act(SchoolCharacter.Action.DEFEND), "Guard overload staggers without causing health knockout")
	check(world.can_pause(), "Transient stagger never prevents pausing")
	a._physics_process(0.66)
	world.get_node("CombatResolver").flush()
	check(not a.is_staggered() and is_equal_approx(a.posture().current, 35), "Player recovers from stagger with bounded residual posture")
	reset()
	b.attack.blockable = false
	a.set_guard(true)
	strike(b, a)
	await process_frame
	check(a.health().current() == 90, "Unblockable attack hits through a perfect guard input")
	b.attack.blockable = true

func test_target_safety() -> void:
	reset()
	player.position.y = 750
	check(not a.try_attack(b), "Explicit out-of-range target rejected")
	reset()
	player.facing = Vector2.DOWN
	check(not a.try_attack(b), "Attack cannot acquire a target behind its cone")
	check(a.try_attack(), "Empty swing still has an action commitment")
	a._physics_process(0.5)
	world.get_node("CombatResolver").flush()
	check(b.health().current() == 160, "Swing cannot hit an enemy outside its current shape")
	reset()
	b.team = 1
	check(not a.try_attack(b), "Friendly target rejected")
	b.team = 2
	b.enabled = false
	check(not a.try_attack(b), "Disabled combat is not targetable")
	b.enabled = true
	check(not a.valid_target(a) and world.current_zone.get_node("Seoyun").get_node_or_null("Combat") == null, "Self and ordinary NPCs remain outside combat")
	var foreign: InGame = load("res://scenes/game/ingame.tscn").instantiate()
	root.add_child(foreign)
	var other: CombatComponent = foreign.current_zone.get_node("TrainingDummy/Combat")
	other.actor().global_position = robot.global_position
	check(not a.try_attack(other), "Different world scopes cannot exchange hits")
	foreign.queue_free()
	await frames()
	reset()
	var wall: SchoolProp = load("res://scenes/world_prop.tscn").instantiate()
	wall.position = Vector2(1420, 600)
	wall.footprint = Vector2(50, 8)
	world.current_zone.add_child(wall)
	await frames()
	check(not a.try_attack(b), "Wall occlusion checked before commitment")
	wall.queue_free()
	await frames()
	check(a.try_attack(b), "Clear path permits windup")
	robot.position = Vector2(1500, 700)
	a._physics_process(0.2)
	world.get_node("CombatResolver").flush()
	check(b.health().current() == 160, "Moving target cannot be hit with stale range/facing")
	reset()
	a.try_attack(b)
	wall = load("res://scenes/world_prop.tscn").instantiate()
	wall.position = Vector2(1420, 600)
	wall.footprint = Vector2(50, 8)
	world.current_zone.add_child(wall)
	await frames()
	a._physics_process(0.2)
	world.get_node("CombatResolver").flush()
	check(b.health().current() == 160, "New wall also blocks a committed attack")
	wall.queue_free()
	await frames()
	reset()
	var recursive: Array[bool] = []
	var callback := func(_direction: Vector2) -> void: recursive.append(a.try_attack(b))
	a.attack_started.connect(callback)
	strike(a, b)
	a.attack_started.disconnect(callback)
	check(recursive == [false] and b.health().current() == 148, "Start notifications cannot recursively commit attacks")
	reset()
	var result_callback := func(_outcome: HitResolver.Outcome) -> void: recursive.append(b.try_attack(a))
	b.resolved.connect(result_callback)
	strike(a, b)
	b.resolved.disconnect(result_callback)
	check(recursive == [false, false], "Contact resolution rejects reentrant counterattacks")
	reset()
	a.try_attack(b)
	var token := player.acquire_control_lock()
	a._physics_process(1)
	world.get_node("CombatResolver").flush()
	check(a.phase == CombatComponent.Phase.READY and b.health().current() == 160 and not a.set_guard(true), "External locks cancel queued strikes and reject guard")
	player.release_control_lock(token)
	reset()
	a.try_attack(b)
	paused = true
	a._physics_process(0.5)
	world.get_node("CombatResolver").flush()
	check(a.phase == CombatComponent.Phase.WINDUP and not a.try_attack(b), "Pause freezes staged combat even through direct API")
	paused = false
	a._physics_process(0.2)
	world.get_node("CombatResolver").flush()
	check(b.health().current() == 148, "Pause resumes the original attack once")
	reset()
	a.try_attack(b)
	a.attack.damage = 999
	a._physics_process(0.2)
	world.get_node("CombatResolver").flush()
	check(b.health().current() == 148, "Committed attack owns its definition despite later resource edits")
	a.attack.damage = 12


func test_posture_and_reset() -> void:
	reset()
	b.posture().add(50)
	b._physics_process(2)
	world.get_node("CombatResolver").flush()
	check(is_equal_approx(b.posture().current, 34), "Posture recovers after the delay with full-health rate")
	b.posture().reset()
	b.health().take_damage(DamageEvent.new(&"test", 80))
	b.posture().add(50)
	b._physics_process(2)
	world.get_node("CombatResolver").flush()
	check(is_equal_approx(b.posture().current, 40), "Lower vitality slows posture recovery")
	reset()
	for invalid in [-1.0, NAN, INF]:
		check(not b.posture().add(invalid), "Invalid posture pressure rejected")
	b.posture().add(100)
	check(b.is_staggered() and a.try_attack(b) and b.health().current() == 0, "Attack on exposed training target performs a decisive finish")
	check(not a.try_attack(b), "Defeated target cannot be finished again")
	reset()
	b.posture().add(100)
	b._physics_process(0.81)
	world.get_node("CombatResolver").flush()
	check(not b.is_staggered() and b.posture().current == 35 and b.health().current() == 160, "Missed finish opportunity recovers without an infinite stagger")
	reset()
	a.try_attack(b)
	a._physics_process(0.33)
	world.get_node("CombatResolver").flush()
	check(a.request_attack(), "Attack buffer accepts one next action near recovery end")
	a._physics_process(0.08)
	world.get_node("CombatResolver").flush()
	check(a.phase == CombatComponent.Phase.WINDUP, "Buffered attack starts on recovery completion")
	reset()
	a.try_attack(b)
	a._physics_process(0.33)
	world.get_node("CombatResolver").flush()
	a.request_guard(true)
	a._physics_process(0.08)
	world.get_node("CombatResolver").flush()
	check(a.guard().holding, "Late guard input is buffered into defense")
	reset()
	a.try_attack(b)
	a._physics_process(0.33)
	world.get_node("CombatResolver").flush()
	a.request_guard(true)
	a.request_guard(false)
	a._physics_process(0.08)
	world.get_node("CombatResolver").flush()
	check(not a.guard().holding, "Released buffered guard cannot latch on later")
	reset()
	a.set_guard(true)
	player.position.x -= 30
	player.facing = Vector2.LEFT
	a.maintain_guard_facing()
	check(a.guard().direction.y < 0 and player.facing == Vector2.UP, "Moving backward/sideways keeps guard directed at the selected opponent")
	reset()
	robot.controller.set_physics_process(true)
	strike(a, b)
	check((robot.controller as TrainingController).is_training() and not world.load_zone("building", "Entrance"), "Active training prevents map-reset exploitation")
	world.respawn()
	check(not (robot.controller as TrainingController).is_training() and a.posture().current == 0, "Checkpoint withdrawal ends training and resets transient combat")
	robot.controller.set_physics_process(false)
	b.health().take_damage(DamageEvent.new(&"test", 999))
	var saved := robot.state
	check(world.load_zone("building", "Entrance") and world.load_zone("courtyard", "FromBuilding"), "Zone changes resume after encounter ends")
	check(world.current_zone.get_node("TrainingDummy").state == saved and saved.current_health == 0, "Zone replacement still preserves health knockout in saved state")

func send_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames(1)

func test_live_guard_and_patterns() -> void:
	world = load("res://scenes/game/ingame.tscn").instantiate()
	root.add_child(world)
	await frames()
	player = world.get_player()
	robot = world.current_zone.get_node("TrainingDummy")
	a = player.get_node("Combat")
	b = robot.get_node("Combat")
	player.position = Vector2(1420, 625)
	player.facing = Vector2.UP
	await frames()
	var patterns: Array[int] = []
	b.attack_started.connect(func(_direction: Vector2) -> void: patterns.append(b.current_attack_kind()))
	await send_key(KEY_K, true)
	check(a.guard().holding, "Physical K press starts guard")
	await send_key(KEY_J, true)
	await send_key(KEY_J, false)
	await create_timer(0.48).timeout
	check(a.guard().holding and not a.guard().can_deflect() and b.posture().current > 0, "Held guard resumes as ordinary guard after an uncanceled attack")
	await create_timer(4.8).timeout
	check(patterns.size() >= 4 and patterns.slice(0, 4) == [0, 1, 2, 3], "Live trainer executes normal, blue, red and purple in order")
	check(a.health().current() < 100, "Holding guard alone cannot defeat the unblockable pattern")
	paused = true
	var posture_before := a.posture().current
	var phase_before := b.phase_left
	await send_key(KEY_K, false)
	await create_timer(0.1).timeout
	check(a.posture().current == posture_before and b.phase_left == phase_before, "Menu pause freezes posture and enemy attack phases")
	paused = false
	await frames()
	check(not a.guard().holding, "Guard release during pause does not stick after resume")
	world.queue_free()
	await frames()

func run() -> void:
	create_timer(35).timeout.connect(func() -> void: quit(1))
	await prepare()
	test_rules()
	await test_defense()
	await test_target_safety()
	test_posture_and_reset()
	world.queue_free()
	await frames()
	await test_live_guard_and_patterns()
	print("DUEL TESTS: %d checks, %d failure(s)" % [checks, failures])
	quit(1 if failures else 0)
