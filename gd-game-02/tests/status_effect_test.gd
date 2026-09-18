extends "res://tests/duel_test.gd"

var effects: StatusEffectComponent

func status(id: String) -> StatusEffectDefinition:
	return load("res://data/status/%s.tres" % id).duplicate(true) as StatusEffectDefinition

func clean() -> void:
	effects.clear()
	robot.status_effects().clear()
	reset()
	a.skills().tick(100)

func test_definitions() -> void:
	for id in ["poison", "burn", "bleed", "stun", "root", "fear", "slow", "heat", "cold"]:
		check(status(id).is_valid(), "Valid status resource: " + id)
	var invalid := status("poison")
	invalid.duration_seconds = NAN
	check(not effects.apply_status(invalid), "Nonfinite duration rejected")
	for field in ["interval", "amount"]:
		invalid = status("poison")
		invalid.behaviors[0].set(field, NAN)
		check(not effects.apply_status(invalid), "Nonfinite periodic property rejected: " + field)
	for id in ["slow", "heat"]:
		invalid = status(id)
		invalid.behaviors[0].set("factor", NAN)
		check(not effects.apply_status(invalid), "Nonfinite modifier rejected: " + id)
	invalid = status("stun")
	invalid.behaviors[0].set("blocked_actions", SchoolCharacter.Action.COMBAT_TICK)
	check(not effects.apply_status(invalid), "Status cannot freeze its own expiry clock")
	invalid.behaviors[0].set("blocked_actions", SchoolCharacter.Action.RECOVER)
	check(not effects.apply_status(invalid), "Status cannot block revival")
	effects.immune_tags = [&"poison"]
	check(not effects.apply_status(status("poison")) and effects.apply_status(status("burn")), "Tag immunity rejects only matching ailments")
	effects.immune_tags.clear()
	clean()

func test_restrictions() -> void:
	check(a.try_attack(b), "Attack begins before stun")
	a._physics_process(0.121)
	effects.apply_status(status("stun"))
	world.get_node("CombatResolver").flush()
	check(a.phase == CombatComponent.Phase.READY and b.health().current() == b.health().maximum(), "Stun cancels queued attack contact")
	for action in [SchoolCharacter.Action.MOVE, SchoolCharacter.Action.INTERACT, SchoolCharacter.Action.ATTACK, SchoolCharacter.Action.DEFEND, SchoolCharacter.Action.DODGE, SchoolCharacter.Action.SKILL]:
		check(not player.can_act(action), "Stun blocks action %d" % action)
	check(player.can_act(SchoolCharacter.Action.COMBAT_TICK) and world.can_pause(), "Stun still allows status time, incoming combat, and menu pause")
	check(not a.request_attack() and not a.request_guard(true) and not a.request_dodge() and not a.request_skill(0), "Public combat requests cannot bypass stun")
	check(b.try_attack(a), "Stunned target remains attackable")
	b._physics_process(0.381)
	world.get_node("CombatResolver").flush()
	check(a.health().current() < 100, "Stun does not confer invulnerability")
	effects.tick(3)
	check(not effects.has_status(&"stun") and player.can_act(SchoolCharacter.Action.MOVE), "Stun expires while movement is locked")
	clean()
	a.set_guard(true)
	effects.apply_status(status("fear"))
	check(not a.guard().holding and player.can_act(SchoolCharacter.Action.MOVE), "Fear cancels guard while preserving manual movement")
	check(not a.request_attack() and not a.request_guard(true) and not a.request_dodge() and not a.request_skill(0), "Fear blocks attacks, guard, dash and skills")
	check(player.can_act(SchoolCharacter.Action.INTERACT), "Fear preserves noncombat interaction")
	clean()
	a.request_dodge()
	check(a.dodge().is_busy(), "Dash begins before root")
	effects.apply_status(status("root"))
	check(not a.dodge().is_busy() and not player.can_act(SchoolCharacter.Action.MOVE) and not a.request_dodge(), "Root stops ongoing dash and blocks new movement")
	check(a.set_guard(true) and a.try_attack(b), "Root permits stationary guard and attacks")
	a.cancel_action()
	check(a.request_skill(0), "Root permits stationary skills")
	clean()
	effects.apply_status(status("root"))
	effects.apply_status(status("stun"))
	effects.cleanse(&"stun")
	check(not player.can_act(SchoolCharacter.Action.MOVE) and player.can_act(SchoolCharacter.Action.ATTACK), "Removing stun leaves independent root restriction")
	var token := player.acquire_control_lock()
	effects.clear()
	check(not player.can_act(SchoolCharacter.Action.MOVE) and not world.can_pause(), "Cleansing releases only status-owned locks")
	player.release_control_lock(token)
	check(player.can_act(SchoolCharacter.Action.MOVE) and world.can_pause(), "External lock owner restores its own permissions")

func test_speeds() -> void:
	clean()
	var slow := status("slow")
	effects.apply_status(slow)
	slow.behaviors[0].set("factor", 0.1)
	check(is_equal_approx(player.movement_speed_multiplier(), 0.6), "Runtime status copies shared resource data")
	var weaker := status("slow")
	weaker.status_id = &"weak_slow"
	weaker.behaviors[0].set("factor", 0.8)
	effects.apply_status(weaker)
	check(is_equal_approx(player.movement_speed_multiplier(), 0.6), "Strongest slow wins instead of multiplying")
	player.position = Vector2(1100, 625)
	player.movement.step(player, Vector2.RIGHT, 1)
	check(is_equal_approx(player.velocity.length(), player.definition.run_speed * 0.6), "Movement uses status speed cap")
	effects.remove_status(&"slow")
	check(is_equal_approx(player.movement_speed_multiplier(), 0.8), "Removing strongest slow restores remaining weaker effect")
	clean()
	effects.apply_status(status("heat"))
	effects.apply_status(status("cold"))
	check(player.movement_speed_multiplier() == 1 and player.action_speed_multiplier() == 0.75, "Heat and cold slow actions without multiplying or slowing walking")
	a.try_attack(b)
	a._physics_process(0.12)
	check(a.phase == CombatComponent.Phase.WINDUP and is_equal_approx(a.phase_left, 0.03), "Action speed scales actual attack timeline")
	a.cancel_action()
	var timed_skill := a.skills().definition(a.skills().skill_id(0))
	timed_skill.skill_id = &"speed_probe"
	timed_skill.cooldown_seconds = 3
	a.skills().learn(timed_skill)
	a.skills().equip(1, timed_skill.skill_id)
	check(a.request_skill(1), "Timed skill starts for cooldown test")
	var id := a.skills().skill_id(1)
	var cooldown := a.skills().remaining(id)
	a._physics_process(0.1)
	check(is_equal_approx(a.skills().remaining(id), cooldown - 0.1), "Skill cooldown uses real time independently of action speed")
	a.cancel_action()
	a._enter_recovery(0.09)
	check(not a.request_attack(), "Slow actions do not buffer earlier than real input window")
	a._physics_process(0.04)
	check(a.request_attack(), "Slow actions buffer inside real input window")
	a._physics_process(0.081)
	check(a.phase == CombatComponent.Phase.WINDUP, "Buffered action survives slowed recovery")
	a.cancel_action()
	a.request_dodge()
	player._physics_process(0.1)
	check(is_equal_approx(a.dodge().elapsed, 0.075), "Dash timeline also observes action speed")
	effects.tick(3)
	check(player.action_speed_multiplier() == 1, "Action slow expiry restores original speed")
	clean()

func test_periodic() -> void:
	var poison := status("poison")
	poison.duration_seconds = 3
	check(effects.apply_status(poison, &"absent_attacker"), "DOT needs only source ID, not living attacker node")
	check(a.health().current() == 100, "No immediate extra damage on application")
	effects.tick(0.5)
	effects.apply_status(poison, &"other_attacker")
	effects.tick(0.5)
	check(a.health().current() == 97, "Refresh keeps tick phase and never duplicates DPS")
	check(effects.snapshots()[0].source_id == &"absent_attacker", "Refresh retains original source attribution")
	effects.tick(10)
	check(a.health().current() == 91 and not effects.has_status(&"poison"), "Large delta catches up exact ticks only until refreshed expiry")
	clean()
	a.defense_profile = DefenseProfile.new()
	a.defense_profile.armor = 999
	a.defense_profile.resistances[DamageType.Type.POISON] = 0.5
	a.set_guard(true)
	effects.apply_status(status("poison"))
	effects.tick(1)
	check(a.health().current() == 98.5 and a.guard().holding, "Periodic damage bypasses flat armor and guard but respects typed resistance")
	var invulnerable := a.health().acquire_invulnerability()
	effects.tick(1)
	check(a.health().current() == 98.5, "Periodic damage respects health invulnerability")
	a.health().release_invulnerability(invulnerable)
	a.defense_profile = null
	clean()
	for id in ["poison", "burn", "bleed"]:
		effects.apply_status(status(id))
	check(effects.cleanse(&"poison") == 1 and effects.has_status(&"burn") and effects.has_status(&"bleed"), "Antidote removes poison only")
	effects.tick(1)
	check(a.health().current() == 94, "Different DOT ailments coexist")
	check(effects.cleanse(&"burn") == 1 and effects.has_status(&"bleed"), "Burn treatment leaves bleeding")
	check(effects.cleanse(&"bleed") == 1 and effects.snapshots().is_empty(), "Hemostasis clears bleeding")
	clean()
	effects.apply_status(status("poison"))
	var lock := player.acquire_control_lock()
	effects.tick(2)
	check(a.health().current() == 100 and effects.snapshots()[0].remaining == 6, "Dialogue lock freezes DOT and duration together")
	player.release_control_lock(lock)
	paused = true
	effects.tick(2)
	check(a.health().current() == 100 and effects.snapshots()[0].remaining == 6, "Menu pause freezes DOT and duration")
	paused = false
	effects.tick(1)
	check(a.health().current() == 97, "DOT resumes without paused time catchup")
	clean()
	var short := status("poison")
	short.duration_seconds = 0.5
	effects.apply_status(short)
	effects.tick(1)
	check(a.health().current() == 100 and effects.snapshots().is_empty(), "Expiry before first interval causes no tick")
	var lethal := status("poison")
	lethal.behaviors[0].set("amount", 100)
	effects.apply_status(lethal)
	effects.apply_status(status("stun"))
	effects.tick(10)
	check(a.health().current() == 0 and effects.snapshots().is_empty() and not player.has_action_locks(), "Death clears all statuses and releases their locks safely during tick")
	check(not effects.apply_status(status("poison")), "Downed actors reject new statuses")
	a.health().revive(100)
	check(player.can_act(SchoolCharacter.Action.MOVE), "Revival does not retain stale status restrictions")
	clean()

func test_callbacks_and_reset() -> void:
	var callback := func(_event: DamageEvent, _amount: float) -> void:
		effects.clear()
		effects.apply_status(status("poison"))
	a.health().damaged.connect(callback, CONNECT_ONE_SHOT)
	effects.apply_status(status("poison"))
	effects.tick(10)
	check(a.health().current() == 97 and effects.snapshots()[0].remaining == 6, "Reapplication from damage signal cannot consume new instance in stale tick loop")
	world.respawn()
	check(effects.snapshots().is_empty(), "Checkpoint reset explicitly clears statuses")
	clean()
	effects.apply_status(status("slow"))
	a.reset_encounter()
	check(effects.has_status(&"slow"), "Ordinary combat disengagement does not cure ailments")
	var treatment := TrainingResetInteraction.new()
	var context := InteractionContext.new(player, SessionState.new())
	robot.status_effects().apply_status(status("poison"))
	check(treatment.execute(context) and effects.snapshots().is_empty() and robot.status_effects().snapshots().is_empty(), "Training reset clears player and selected trainer ailments")

func test_attack_effects() -> void:
	clean()
	var original := a.attack
	var poisoned := a.attack.duplicate(true) as AttackDefinition
	poisoned.on_hit_statuses = [status("poison"), status("stun")]
	a.attack = poisoned
	b.set_guard(true, false)
	strike(a, b)
	check(robot.status_effects().snapshots().is_empty(), "Blocked attacks cannot apply on-hit ailments")
	clean()
	a.try_attack(b)
	# Editing shared authoring data after commitment must not alter the attack.
	poisoned.on_hit_statuses.clear()
	a._physics_process(0.121)
	world.get_node("CombatResolver").flush()
	check(robot.status_effects().has_status(&"poison") and robot.status_effects().has_status(&"stun"), "Landed attack applies its committed status snapshot")
	check(robot.status_effects().snapshots()[0].source_id == player.character_id, "Attack statuses retain attacker ID")
	check(effects.snapshots().is_empty(), "Targets own independent status instances")
	clean()
	poisoned.on_hit_statuses = [status("stun")]
	b.defense_profile = DefenseProfile.new()
	b.defense_profile.resistances[poisoned.damage_type] = 1
	strike(a, b)
	check(robot.status_effects().snapshots().is_empty(), "Fully resisted hit does not apply damage-triggered statuses")
	b.defense_profile = null
	clean()
	a.try_attack(b)
	b.try_attack(a)
	a._physics_process(0.121)
	b._physics_process(0.381)
	world.get_node("CombatResolver").flush()
	check(a.health().current() < 100 and b.health().current() < b.health().maximum() and robot.status_effects().has_status(&"stun"), "On-hit stun preserves accepted simultaneous trade then interrupts future actions")
	a.attack = original
	clean()

func test_lab() -> void:
	var game: Node = load("res://scenes/combat/status_effect_demo.tscn").instantiate()
	root.add_child(game)
	await frames()
	var actor: SchoolCharacter = game.get_node("InGame").get_player()
	var lab: Node = game.get_node("StatusLab")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_1
	key.pressed = true
	lab._unhandled_input(key)
	await frames(1)
	var hud: SchoolHUD = game.get_node("UI/HUD")
	check(actor.status_effects().has_status(&"poison") and "독" in hud.displayed_ailments(), "Standalone lab key applies status and HUD receives presentation data")
	key.physical_keycode = KEY_4
	lab._unhandled_input(key)
	game.get_node("GameCoordinator").request_pause()
	check(paused and game.get_node("UI").is_pause_open(), "Live pause menu opens while stunned")
	game.get_node("GameCoordinator").resume()
	key.physical_keycode = KEY_F3
	lab._unhandled_input(key)
	check(not actor.status_effects().has_status(&"poison") and actor.status_effects().has_status(&"stun"), "Lab antidote cleanses only poison")
	key.physical_keycode = KEY_0
	lab._unhandled_input(key)
	check(actor.status_effects().snapshots().is_empty() and hud.displayed_ailments().is_empty(), "Lab clear restores controls and clears HUD")
	game.queue_free()
	await frames()

func run() -> void:
	create_timer(35).timeout.connect(func() -> void: quit(1))
	await prepare()
	player.get_node("CombatFeedback").sound_enabled = false
	robot.get_node("CombatFeedback").sound_enabled = false
	player.set_physics_process(false)
	robot.set_physics_process(false)
	effects = player.status_effects()
	effects.set_physics_process(false)
	robot.status_effects().set_physics_process(false)
	test_definitions()
	test_restrictions()
	test_speeds()
	test_periodic()
	test_callbacks_and_reset()
	test_attack_effects()
	world.queue_free()
	await frames()
	await test_lab()
	print("STATUS EFFECT TESTS: %d checks, %d failure(s)" % [checks, failures])
	quit(1 if failures else 0)
