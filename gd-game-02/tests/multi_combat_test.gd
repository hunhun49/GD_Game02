extends "res://tests/duel_test.gd"

var enemies: Array[CombatComponent] = []
var arena: CombatResolver

func reset_arena() -> void:
	arena.clear()
	player.position = Vector2(800, 650)
	player.facing = Vector2.UP
	player.get_node("Aim").pointer_active = true
	player.get_node("Aim").direction = Vector2.UP
	var positions := [Vector2(800, 580), Vector2(760, 595), Vector2(840, 595)]
	for i in range(enemies.size()):
		(enemies[i].actor().controller as TrainingController).reset_training()
		enemies[i].actor().position = positions[i]
		enemies[i].actor().facing = Vector2.DOWN
		enemies[i].team = 2
		enemies[i].enabled = true
		enemies[i].defense_profile = null
		enemies[i].actor().get_node("Hurtbox").enabled = true
	for combat in [a] + enemies:
		combat.reset_encounter()
		if combat.health().current() == 0:
			combat.health().revive(combat.health().maximum())
		else:
			combat.health().heal(combat.health().maximum())

func all_hp(value: float) -> bool:
	for combat in enemies:
		if combat.health().current() != value:
			return false
	return true

func strike_all() -> void:
	check(a.try_attack(b), "Multi-target swing commits toward center enemy")
	a._physics_process(0.121)
	arena.flush()

func enemy_attack(combat: CombatComponent, kind: AttackDefinition.Kind) -> void:
	var move := combat.attack.duplicate() as AttackDefinition
	move.kind = kind
	check(combat.try_attack(a, move), "Enemy attack starts")
	combat._physics_process(0.381)

func test_contacts() -> void:
	reset_arena()
	check(not a.executor().hitbox().active, "Idle hitbox is inactive")
	a.try_attack(b)
	check(not a.executor().hitbox().active and all_hp(160), "Windup cannot damage overlapping hurtboxes")
	a._physics_process(0.121)
	check(a.executor().hitbox().active and all_hp(160), "Active phase queues contacts until batch resolution")
	arena.flush()
	check(all_hp(148), "One swing damages all three overlapping enemies")
	a._physics_process(0.02)
	arena.flush()
	check(all_hp(148), "Repeated overlap cannot damage any target twice")
	a._physics_process(0.2)
	arena.flush()
	check(not a.executor().hitbox().active, "Recovery disables hitbox")
	a._physics_process(0.1)
	strike_all()
	check(all_hp(136), "Next attack has a fresh per-target hit ledger")
	reset_arena()
	var extra: Hurtbox = load("res://scenes/combat/hurtbox.tscn").instantiate()
	extra.name = "HeadHurtbox"
	extra.position = Vector2(0, -6)
	robot.add_child(extra)
	strike_all()
	check(b.health().current() == 148, "Multiple hurtboxes on one character still produce one hit")
	extra.queue_free()
	reset_arena()
	for combat in enemies:
		combat.actor().position.y -= 300
	check(a.try_attack(), "Empty swing starts without a locked target")
	robot.position = Vector2(800, 580)
	a._physics_process(0.121)
	arena.flush()
	check(b.health().current() == 148, "Enemy entering during windup can be hit at contact time")
	enemies[1].actor().position = Vector2(760, 595)
	a._physics_process(0.01)
	arena.flush()
	check(enemies[1].health().current() == 148 and b.health().current() == 148, "New target entering active window is hit without repeating previous hit")
	robot.position.y -= 300
	a._physics_process(0.001)
	arena.flush()
	robot.position = Vector2(800, 580)
	a._physics_process(0.001)
	arena.flush()
	check(b.health().current() == 148, "Leaving and reentering the same swing cannot repeat damage")
	reset_arena()
	enemies[1].team = 1
	enemies[2].actor().get_node("Hurtbox").enabled = false
	strike_all()
	check(b.health().current() == 148 and enemies[1].health().current() == 160 and enemies[2].health().current() == 160, "Team filter and disabled hurtboxes are respected")
	reset_arena()
	robot.position.y = 559 # center 91px away, but radius 10 intersects reach 85
	check(a.in_attack_range(b), "Collision uses hurtbox extent rather than center distance")
	robot.position.y = 552
	check(not a.in_attack_range(b), "Separated shapes outside reach do not hit")
	reset_arena()
	b.set_guard(true, false)
	enemies[2].defense_profile = DefenseProfile.new()
	enemies[2].defense_profile.resistances[DamageType.Type.BLUNT] = 1
	strike_all()
	check(b.health().current() == 160 and b.posture().current == 8 and enemies[1].health().current() == 148 and enemies[2].health().current() == 160 and enemies[2].posture().current == 8, "Each overlap has its own guard and resistance outcome")
	reset_arena()
	a.try_attack(b)
	a._physics_process(0.121)
	a.cancel_action()
	arena.flush()
	check(all_hp(160), "Canceled queued cleave damages nobody")

func test_simultaneous() -> void:
	for reverse in [false, true]:
		reset_arena()
		a.health().take_damage(DamageEvent.new(&"setup", 90))
		b.health().take_damage(DamageEvent.new(&"setup", 155))
		a.try_attack(b)
		b.try_attack(a)
		if reverse:
			b._physics_process(0.381)
			a._physics_process(0.121)
		else:
			a._physics_process(0.121)
			b._physics_process(0.381)
		arena.flush()
		check(a.health().current() == 0 and b.health().current() == 0, "Same-frame lethal trade is independent of enqueue order")
		check(enemies[1].health().current() == 148 and enemies[2].health().current() == 148, "Accepted cleave survives source death in same batch")
	reset_arena()
	a.posture().add(90)
	a.set_guard(true, false)
	for combat in enemies:
		enemy_attack(combat, AttackDefinition.Kind.NORMAL)
	arena.flush()
	check(a.health().current() == 100 and a.is_staggered(), "Same-frame guard snapshot blocks all hits before stagger affects later frames")
	reset_arena()
	a.set_guard(true)
	for combat in enemies:
		enemy_attack(combat, AttackDefinition.Kind.BLUE)
	arena.flush()
	check(a.health().current() == 100 and a.posture().current == 0, "Timed guard deflects all covered simultaneous blue hits")
	for combat in enemies:
		check(combat.posture().current == 12, "Each deflected attacker receives its own posture pressure")
	for reverse in [false, true]:
		reset_arena()
		a.request_purple()
		var order := enemies.duplicate()
		if reverse:
			order.reverse()
			a._physics_process(0.221)
		for combat in order:
			enemy_attack(combat, AttackDefinition.Kind.PURPLE)
		if not reverse:
			a._physics_process(0.221)
		arena.flush()
		check(all_hp(160) and a.health().current() == 100, "One purple swing clashes with all mutually overlapping purple attacks")
		check(a.phase == CombatComponent.Phase.RECOVERY and is_equal_approx(a.phase_left, 0.08), "Multi-clash short player recovery is applied once")
		for combat in enemies:
			check(combat.phase == CombatComponent.Phase.RECOVERY, "Each clashing enemy attack is canceled")
		a._physics_process(1)
		for combat in enemies:
			combat._physics_process(1)
		arena.flush()
		check(all_hp(160) and a.health().current() == 100, "Multi-clash leaves no delayed damage")
	reset_arena()
	a.request_purple()
	a._physics_process(0.221)
	enemy_attack(b, AttackDefinition.Kind.PURPLE)
	enemy_attack(enemies[1], AttackDefinition.Kind.NORMAL)
	arena.flush()
	check(a.health().current() == 90 and all_hp(160), "Clash cancels outgoing swing but grants no immunity to unrelated normal attack")
	reset_arena()
	for i in range(3):
		enemies[i].actor().position = Vector2(780 + i * 20, 580)
	a.request_dodge()
	a.dodge().step(player, 0.04)
	for combat in enemies:
		enemy_attack(combat, AttackDefinition.Kind.RED)
	arena.flush()
	check(a.health().current() == 100 and not a.dodge().is_busy(), "One dash counters all eligible red contacts in the same frame")
	for combat in enemies:
		check(combat.posture().current == 24, "Each dash-parried attacker receives pressure")

func test_geometry_and_lifetime() -> void:
	reset_arena()
	var hitbox := a.executor().hitbox()
	hitbox.use_attack_sector = false
	hitbox.orient_to_attack = false
	hitbox.global_rotation = -PI / 2
	var blade := CollisionShape2D.new()
	blade.position = Vector2(45, 0)
	var shape := CircleShape2D.new()
	shape.radius = 10
	blade.shape = shape
	hitbox.add_child(blade)
	robot.position = Vector2(800, 605)
	check(a.try_attack(b), "Authored weapon collider supports explicit commitment")
	a._physics_process(0.121)
	arena.flush()
	check(b.health().current() == 148 and enemies[1].health().current() == 160, "Authored weapon collider controls actual damage footprint")
	a.reset_encounter()
	blade.disabled = true
	check(not a.in_attack_range(b), "Disabled authored weapon collider cannot acquire a hit")
	blade.queue_free()
	hitbox.use_attack_sector = true
	hitbox.orient_to_attack = true
	reset_arena()
	var wall := StaticBody2D.new()
	wall.position = Vector2(800, 620)
	wall.collision_layer = 1
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(160, 6)
	collision.shape = rectangle
	wall.add_child(collision)
	world.add_child(wall)
	await frames()
	a.try_attack()
	a._physics_process(0.121)
	arena.flush()
	check(all_hp(160), "Wall blocks every overlapping hurtbox behind it")
	wall.queue_free()
	await frames()
	reset_arena()
	a.try_attack(b)
	a._physics_process(0.121)
	world.respawn()
	arena.flush()
	check(all_hp(160), "World reset invalidates a queued batch")
	reset_arena()
	a.try_attack(b)
	a._physics_process(0.121)
	var token := enemies[1].actor().acquire_control_lock()
	arena.flush()
	check(b.health().current() == 148 and enemies[1].health().current() == 160 and enemies[2].health().current() == 148, "Locked target excluded without losing other targets")
	enemies[1].actor().release_control_lock(token)
	reset_arena()
	a.try_attack(b)
	a._physics_process(0.121)
	paused = true
	arena.flush()
	check(all_hp(160), "Paused resolver retains batch without applying damage")
	paused = false
	arena.flush()
	check(all_hp(148), "Resume applies retained batch once")
	reset_arena()
	for combat in enemies:
		combat.health().take_damage(DamageEvent.new(&"test", 20))
	var reset_action := TrainingResetInteraction.new()
	reset_action.reset_all_training = true
	check(reset_action.execute(InteractionContext.new(player, SessionState.new())) and all_hp(160), "Arena reset heals all training targets")

func test_group_disengage_and_input() -> void:
	reset_arena()
	var move_lock := player.acquire_action_lock(SchoolCharacter.Action.MOVE)
	var interaction_lock := robot.acquire_action_lock(SchoolCharacter.Action.INTERACT)
	strike_all()
	check(all_hp(148), "Movement/interaction-only locks do not suppress valid combat results")
	player.release_action_lock(move_lock)
	robot.release_action_lock(interaction_lock)
	reset_arena()
	var tokens: Array[int] = []
	var interrupt := func(_event: DamageEvent, _amount: float) -> void: tokens.append(enemies[1].actor().acquire_control_lock())
	b.health().damaged.connect(interrupt)
	strike_all()
	b.health().damaged.disconnect(interrupt)
	check(b.health().current() == 148 and enemies[1].health().current() == 160 and enemies[2].health().current() == 148, "External lock during result callbacks interrupts only the affected remaining target")
	for token in tokens:
		enemies[1].actor().release_control_lock(token)
	reset_arena()
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = player.get_canvas_transform() * robot.global_position
	root.push_input(mouse, true)
	a._physics_process(0.121)
	arena.flush()
	check(all_hp(148), "Real mouse input reaches all three hurtboxes through the world controller")
	mouse.pressed = false
	root.push_input(mouse, true)
	a.cancel_action()
	a.posture().add(30)
	a.set_guard(true, false)
	robot.position.y -= 300
	robot.controller._physics_process(0.01)
	check(a.posture().current == 30 and a.guard().holding, "One disengaging enemy cannot reset player while others remain in combat")
	for combat in enemies.slice(1):
		combat.actor().position.y -= 300
		combat.actor().controller._physics_process(0.01)
	check(a.posture().current == 0 and not a.guard().holding, "Last disengaging enemy ends player encounter state")
	reset_arena()
	enemy_attack(b, AttackDefinition.Kind.NORMAL)
	robot.queue_free()
	arena.flush()
	check(a.health().current() == 100, "Deleting an attacker before resolution discards its queued contacts")

func run() -> void:
	create_timer(35).timeout.connect(func() -> void: quit(1))
	world = load("res://scenes/game/ingame.tscn").instantiate()
	world.initial_zone = "combat_arena"
	root.add_child(world)
	await frames()
	player = world.get_player()
	robot = world.current_zone.get_node("TrainingDummy")
	a = player.get_node("Combat")
	b = robot.get_node("Combat")
	arena = world.get_node("CombatResolver")
	enemies = [b, world.current_zone.get_node("TrainingLeft/Combat"), world.current_zone.get_node("TrainingRight/Combat")]
	for combat in [a] + enemies:
		combat.set_physics_process(false)
		combat.actor().set_physics_process(false)
		combat.actor().controller.set_physics_process(false)
		combat.actor().get_node("CombatFeedback").sound_enabled = false
	test_contacts()
	test_simultaneous()
	await test_geometry_and_lifetime()
	test_group_disengage_and_input()
	world.queue_free()
	await frames()
	print("MULTI COMBAT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
