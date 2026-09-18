extends "res://tests/duel_test.gd"

func colored(kind: AttackDefinition.Kind) -> AttackDefinition:
	var move := b.attack.duplicate() as AttackDefinition
	move.kind = kind
	return move

func contact(kind: AttackDefinition.Kind) -> void:
	b.try_attack(a, colored(kind))
	b._physics_process(0.381)
	await process_frame

func test_colors() -> void:
	reset()
	a.set_guard(true, false)
	await contact(AttackDefinition.Kind.BLUE)
	check(a.health().current() == 100 and a.posture().current == 54, "Blue ordinary guard applies exactly triple posture")
	reset()
	a.set_guard(true)
	await contact(AttackDefinition.Kind.BLUE)
	check(a.posture().current == 0 and b.posture().current == 12, "Blue timed deflect avoids triple posture")
	for kind in [AttackDefinition.Kind.RED, AttackDefinition.Kind.PURPLE]:
		reset()
		a.set_guard(true)
		await contact(kind)
		check(a.health().current() == 90, "Red/purple bypass fresh guard: %s" % kind)
	reset()
	check(a.request_dodge(), "Dodge starts without stamina")
	a.dodge().step(player, 0.04)
	await contact(AttackDefinition.Kind.RED)
	check(a.health().current() == 100 and b.posture().current == 24, "Forward dash at contact parries red and pressures enemy")
	check(not a.dodge().is_busy() and a.can_attack() and b.phase == CombatComponent.Phase.RECOVERY, "Dash parry immediately returns offensive initiative")
	for wrong in [true, false]:
		reset()
		player.facing = Vector2.DOWN if wrong else Vector2.UP
		a.request_dodge()
		if wrong:
			a.dodge().step(player, 0.01)
		await contact(AttackDefinition.Kind.RED)
		check(a.health().current() == 90, "Wrong direction or stationary dash cannot parry")
	reset()
	a.request_dodge()
	a.dodge().step(player, 0.04)
	await contact(AttackDefinition.Kind.NORMAL)
	check(a.health().current() == 100, "Normal attack can be evaded in dodge window")
	reset()
	a.request_dodge()
	a.dodge().step(player, 0.04)
	await contact(AttackDefinition.Kind.PURPLE)
	check(a.health().current() == 90, "Purple ignores normal dodge invulnerability")
	reset()
	a.request_dodge()
	check(not a.request_dodge() and not a.request_purple() and not a.set_guard(true), "Dodge commitment prevents action spam")
	a.dodge().step(player, 0.18)
	check(a.dodge().is_busy(), "Dodge recovery remains after travel")
	a.dodge().step(player, 0.21)
	check(a.can_attack(), "Dodge recovery returns attack permission")
	reset()
	a.try_attack(b)
	check(a.request_dodge() and a.phase == CombatComponent.Phase.READY, "Early attack can cancel into dodge")
	reset()
	a.try_attack(b)
	a._physics_process(0.08)
	check(not a.request_dodge(), "Committed late attack cannot cancel into dodge")

func test_clashes() -> void:
	for reverse in [false, true]:
		reset()
		check(a.request_purple() and b.try_attack(a, colored(AttackDefinition.Kind.PURPLE)), "Both purple attacks start")
		if reverse:
			b._physics_process(0.381)
			a._physics_process(0.221)
		else:
			a._physics_process(0.221)
			b._physics_process(0.381)
		await process_frame
		check(a.health().current() == 100 and b.health().current() == 160, "Purple clash cancels both damage, either update order")
		check(a.phase == CombatComponent.Phase.RECOVERY and is_equal_approx(a.phase_left, 0.08), "Clash grants short player recovery")
		a._physics_process(0.09)
		b._physics_process(0.09)
		check(a.can_attack() and not b.can_attack(), "Player acts first after clash")
		a._physics_process(1)
		b._physics_process(1)
		await process_frame
		check(a.health().current() == 100 and b.health().current() == 160, "Consumed clash cannot apply delayed damage")
	reset()
	a.request_purple()
	await contact(AttackDefinition.Kind.PURPLE)
	check(a.health().current() == 90, "Purple still winding up cannot clash")
	reset()
	a.try_attack(b)
	a._physics_process(0.121)
	await contact(AttackDefinition.Kind.PURPLE)
	check(a.health().current() == 90, "Normal strike cannot clash with purple")
	reset()
	player.facing = Vector2.DOWN
	a.request_purple()
	a._physics_process(0.221)
	await contact(AttackDefinition.Kind.PURPLE)
	check(a.health().current() == 90, "Purple pointed away cannot clash")
	reset()
	b.try_attack(a, colored(AttackDefinition.Kind.PURPLE))
	b._physics_process(0.381)
	b.reset_encounter()
	await process_frame
	check(a.health().current() == 100, "Reset invalidates queued colored hit")
	reset()
	b.try_attack(a, colored(AttackDefinition.Kind.RED))
	b._physics_process(0.381)
	var lock := robot.acquire_control_lock()
	await process_frame
	check(a.health().current() == 100, "Control lock invalidates queued hit")
	robot.release_control_lock(lock)

func test_aim_and_inputs() -> void:
	reset()
	var aim: AimComponent = player.get_node("Aim")
	var event := InputEventMouseMotion.new()
	event.position = player.get_canvas_transform() * (player.global_position + Vector2(100, -20))
	root.push_input(event, true)
	check(aim.pointer_active and aim.direction.distance_to(Vector2(100, -20).normalized()) < 0.001, "Mouse viewport coordinates map through camera transform")
	check(a.try_attack() and a.attack_direction.distance_to(aim.direction) < 0.001, "Attack preserves cursor direction without target snap")
	a._physics_process(0.121)
	world.get_node("CombatResolver").flush()
	check(b.health().current() == 160, "Attack misses enemy outside cursor cone")
	a.reset_encounter()
	aim.track_pointer(player.get_canvas_transform() * robot.global_position)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = aim.pointer_position
	root.push_input(click, true)
	check(a.phase == CombatComponent.Phase.WINDUP, "Left mouse input reaches attack through controller and world")
	a.reset_encounter()
	click.button_index = MOUSE_BUTTON_RIGHT
	root.push_input(click, true)
	check(a.guard().holding and a.guard().direction.dot(Vector2.UP) > 0.99, "Right mouse input guards toward cursor")
	aim.track_pointer(player.get_canvas_transform() * (player.global_position + Vector2.RIGHT * 100))
	a.maintain_guard_facing()
	check(a.guard().direction.dot(Vector2.RIGHT) > 0.99, "Held guard follows cursor instead of enemy auto lock")
	click.pressed = false
	root.push_input(click, true)
	a.reset_encounter()
	for key in [KEY_Q, KEY_SHIFT]:
		var press := InputEventKey.new()
		press.physical_keycode = key
		press.pressed = true
		root.push_input(press, true)
		check(a.current_attack_kind() == AttackDefinition.Kind.PURPLE if key == KEY_Q else a.dodge().moving, "Q/Shift input reaches optional combat action")
		press.pressed = false
		root.push_input(press, true)
		a.reset_encounter()
	aim.pointer_active = false
	reset()
	# A solid obstacle immediately ahead must stop a dash before crossing it.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(100, 10)
	shape.shape = rect
	wall.add_child(shape)
	world.add_child(wall)
	wall.position = player.position + Vector2(0, -25)
	await frames()
	a.request_dodge()
	a.dodge().step(player, 0.18)
	check(player.position.y > wall.position.y, "Physical dash cannot teleport through a wall")
	wall.queue_free()
	await frames()
	a.reset_encounter()

func test_windows_and_pause() -> void:
	reset()
	a.request_dodge()
	a.dodge().speed = 50 # Keep the late dash inside the enemy cone.
	a.dodge().step(player, 0.14)
	a.dodge().speed = 620
	await contact(AttackDefinition.Kind.RED)
	check(a.health().current() == 90, "Late forward dash cannot parry red")
	reset()
	a.request_dodge()
	a.dodge().step(player, 0.04)
	var before := player.position
	var elapsed := a.dodge().elapsed
	paused = true
	player._physics_process(0.1)
	check(player.position == before and a.dodge().elapsed == elapsed, "Pause freezes dash position and counter clock")
	paused = false
	var token := player.acquire_control_lock()
	check(not a.dodge().is_busy(), "Dialogue-style lock cancels dash")
	player.release_control_lock(token)
	for purple in [true, false]:
		reset()
		a.try_attack(b)
		a._physics_process(0.31)
		check(a.request_purple() if purple else a.request_dodge(), "Recovery accepts Q/Shift buffer")
		a._physics_process(0.091)
		check(a.phase == CombatComponent.Phase.WINDUP and a.current_attack_kind() == AttackDefinition.Kind.PURPLE if purple else a.dodge().moving, "Buffered Q/Shift begins at recovery end")
	reset()
	b.try_attack(a, colored(AttackDefinition.Kind.PURPLE))
	b._physics_process(0.381)
	paused = true
	await process_frame
	check(a.health().current() == 100, "Queued purple contact cannot damage while paused")
	paused = false
	await physics_frame
	b._physics_process(0.001)
	await process_frame
	check(a.health().current() == 90, "Unconsumed active contact resumes after pause")

func run() -> void:
	await prepare()
	# Fast manual ticks do not wait for the audio mixer; visual smoke test covers cues.
	player.get_node("CombatFeedback").sound_enabled = false
	robot.get_node("CombatFeedback").sound_enabled = false
	player.set_physics_process(false)
	await test_colors()
	await test_clashes()
	await test_aim_and_inputs()
	await test_windows_and_pause()
	world.queue_free()
	await frames()
	print("Colored combat: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
