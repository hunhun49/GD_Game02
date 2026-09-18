extends "res://tests/duel_test.gd"

func payload(amount: float = 30.0) -> DamageRequest:
	var move := AttackDefinition.new()
	move.damage = amount
	move.damage_type = DamageType.Type.SLASH
	move.attack_id = &"test_slash"
	return DamageRequest.from_attack(&"player", &"enemy", move, 10, 1)

func test_calculation() -> void:
	var defense := DefenseProfile.new()
	defense.armor = 10
	defense.resistances[DamageType.Type.SLASH] = 0.25
	var input := payload()
	var result := DamageResolver.resolve(input, HitResolver.Outcome.HIT, defense)
	check(result.health_damage == 15 and result.target_posture == 8, "Armor then typed resistance; posture independent")
	input.amount = 999
	check(result.request.amount == 30, "Resolver owns a detached request snapshot")
	input = payload()
	input.damage_type = DamageType.Type.FIRE
	check(DamageResolver.resolve(input, HitResolver.Outcome.HIT, defense).health_damage == 20, "Slash resistance does not reduce fire")
	defense.resistances[DamageType.Type.FIRE] = -0.5
	check(DamageResolver.resolve(input, HitResolver.Outcome.HIT, defense).health_damage == 30, "Negative resistance increases damage")
	defense.resistances[DamageType.Type.FIRE] = 1
	check(DamageResolver.resolve(input, HitResolver.Outcome.HIT, defense).health_damage == 0, "Full resistance allows zero damage")
	input.kind = AttackDefinition.Kind.BLUE
	result = DamageResolver.resolve(input, HitResolver.Outcome.BLOCK, defense)
	check(result.health_damage == 0 and result.target_posture == 54, "Blue guard pressure ignores health armor/resistance")
	result = DamageResolver.resolve(input, HitResolver.Outcome.DEFLECT, defense)
	check(result.health_damage == 0 and result.target_posture == 0 and result.source_posture == 12, "Deflect returns attacker posture only")
	for outcome in [HitResolver.Outcome.DODGE, HitResolver.Outcome.CLASH]:
		result = DamageResolver.resolve(input, outcome, defense)
		check(result.health_damage == 0 and result.target_posture == 0 and result.source_posture == 0, "Dodge/clash leave both damage channels clear")
	input.execution = true
	check(DamageResolver.resolve(input, HitResolver.Outcome.HIT, defense).health_damage == 30, "Execution bypasses armor/resistance explicitly")
	input.execution = false
	defense.armor = 100
	check(DamageResolver.resolve(input, HitResolver.Outcome.HIT, defense).health_damage == 0, "Armor cannot produce healing")
	for invalid in [NAN, INF, -1.0]:
		input.amount = invalid
		check(DamageResolver.resolve(input, HitResolver.Outcome.HIT) == null, "Invalid requested damage rejected")
	input = payload()
	for invalid in [NAN, INF, 1.1, -1.1]:
		defense.resistances[DamageType.Type.SLASH] = invalid
		check(DamageResolver.resolve(input, HitResolver.Outcome.HIT, defense) == null, "Invalid resistance fails closed")
	defense = DefenseProfile.new()
	defense.resistances[999] = 0.5
	check(not defense.is_valid(), "Unknown damage type rejected")
	result = DamageResolver.resolve(payload(), HitResolver.Outcome.HIT)
	var copy := result.copy()
	copy.request.amount = 1
	copy.health_damage = 1
	check(result.request.amount == 30 and result.health_damage == 30, "Published result copies do not share request state")
	var event := DamageEvent.from_result(result).copy()
	check(event.attack_id == &"test_slash" and event.damage_type == DamageType.Type.SLASH and event.emitter_id == 10 and event.sequence == 1, "Health event copies preserve attack metadata")

func test_receiver() -> void:
	reset()
	check(a.executor() != null and a.attack.attack_id == &"player_attack" and a.attack.damage_type == DamageType.Type.BLUNT, "Scene owns execution component and typed attack asset")
	a.try_attack(b)
	var early := a.executor().request()
	check(b.receive_attack(a, early) == null and b.health().current() == 160, "Receiver rejects damage during windup")
	b.defense_profile = DefenseProfile.new()
	b.defense_profile.armor = 4
	b.defense_profile.resistances[DamageType.Type.BLUNT] = 0.5
	a.attack.damage = 90
	a._physics_process(0.121)
	world.get_node("CombatResolver").flush()
	check(b.health().current() == 156 and b.posture().current == 8, "Committed attack snapshots damage; receiver samples current defense")
	check(b.receive_attack(a, early) == null and b.health().current() == 156, "Consumed request cannot apply twice")
	a.attack.damage = 12
	reset()
	b.defense_profile.resistances[DamageType.Type.BLUNT] = 1
	a.try_attack(b)
	a._physics_process(0.121)
	world.get_node("CombatResolver").flush()
	check(b.health().current() == 160 and b.posture().current == 8, "Resistance protects HP while hit posture remains independent")
	reset()
	a.try_attack(b)
	var stale := a.executor().request()
	a.cancel_action()
	a.try_attack(b)
	check(b.receive_attack(a, stale) == null, "New attack cannot reuse old sequence")
	reset()
	b.posture().add(100)
	check(a.try_attack(b) and b.health().current() == 0, "Execution stays lethal against full resistance")
	b.defense_profile = null
	reset()
	# Inspect while still active but outside range, then return to contact range.
	a.try_attack(b)
	robot.position.y -= 100
	a._physics_process(0.121)
	world.get_node("CombatResolver").flush()
	robot.position.y += 100
	var changed := a.executor().request()
	changed.amount = 999
	check(b.receive_attack(a, changed) == null, "Receiver rejects modified attack payload")
	var request := a.executor().request()
	var replayed: Array[bool] = []
	var recurse := func(_event: DamageEvent, _amount: float) -> void: replayed.append(b.receive_attack(a, request) != null)
	b.health().damaged.connect(recurse)
	var result := b.receive_attack(a, request)
	b.health().damaged.disconnect(recurse)
	check(result != null and result.applied_health == 12 and replayed == [false], "Receiver transaction rejects reentrant damage")
	reset()
	b.health().take_damage(DamageEvent.new(&"setup", 155))
	a.try_attack(b)
	var results: Array[DamageResult] = []
	var capture := func(value: DamageResult) -> void: results.append(value)
	b.damage_resolved.connect(capture)
	a._physics_process(0.121)
	world.get_node("CombatResolver").flush()
	b.damage_resolved.disconnect(capture)
	check(results.size() == 1 and results[0].health_damage == 12 and results[0].applied_health == 5, "Result distinguishes calculated damage from applied overkill")

func skill(id: StringName, cooldown: float = 2.0) -> SkillDefinition:
	var value := SkillDefinition.new()
	value.skill_id = id
	value.display_name = "Test skill"
	value.attack = load("res://data/combat/player_attack.tres").duplicate()
	value.cooldown_seconds = cooldown
	return value

func test_skills() -> void:
	reset()
	var skills := a.skills()
	check(skills.skill_id(0) == &"purple_clash", "Q is equipped as a data-defined skill")
	var shared := skill(&"shared_strike")
	check(skills.learn(shared) and skills.equip(1, shared.skill_id), "Skill learned and equipped by stable ID")
	check(not skills.learn(shared) and not skills.equip(8, shared.skill_id) and not skills.equip(2, &"missing"), "Duplicate IDs and invalid slots/loadouts rejected")
	var second := SkillComponent.new()
	second.name = "Skills"
	b.add_child(second)
	second.learn(shared)
	second.equip(0, shared.skill_id)
	shared.attack.damage = 99
	check(skills.definition(shared.skill_id).attack.damage == 12, "Learned skill data is isolated from asset mutation")
	var view := skills.definition(shared.skill_id)
	view.attack.damage = 123
	check(skills.definition(shared.skill_id).attack.damage == 12, "Definition getter does not expose live mutable data")
	check(skills.try_use(1, b) and skills.remaining(shared.skill_id) == 2, "Successful skill reserves its own cooldown")
	check(second.remaining(shared.skill_id) == 0 and second.can_use(0), "Shared skill has independent actor cooldown")
	check(skills.equip(2, shared.skill_id) and not skills.can_use(2), "Equipping the same skill twice cannot bypass cooldown")
	a._physics_process(0.5)
	world.get_node("CombatResolver").flush()
	check(a.can_attack() and is_equal_approx(skills.remaining(shared.skill_id), 1.5), "Attack recovery finishes before skill cooldown")
	check(a.try_attack(b), "Basic attack remains usable during skill cooldown")
	a.cancel_action()
	skills.unequip(1)
	skills.equip(1, shared.skill_id)
	check(is_equal_approx(skills.remaining(shared.skill_id), 1.5), "Cancel and re-equip do not refund cooldown")
	paused = true
	skills.tick(1)
	check(is_equal_approx(skills.remaining(shared.skill_id), 1.5), "Pause freezes skill cooldown")
	paused = false
	var token := player.acquire_control_lock()
	skills.tick(1)
	check(is_equal_approx(skills.remaining(shared.skill_id), 1.5), "Dialogue lock freezes cooldown")
	player.release_control_lock(token)
	a._physics_process(1.5)
	world.get_node("CombatResolver").flush()
	check(skills.remaining(shared.skill_id) == 0 and skills.can_use(1), "Cooldown expires independently of attack animation")
	var expensive := skill(&"expensive")
	expensive.attack.stamina_cost = 20
	skills.learn(expensive)
	skills.equip(3, expensive.skill_id)
	player.get_node("Stamina").spend(100)
	check(not skills.try_use(3) and skills.remaining(expensive.skill_id) == 0, "Failed cost check does not consume skill cooldown")
	player.get_node("Stamina").restore_full()
	robot.position.y -= 200
	check(not skills.try_use(3, b) and skills.remaining(expensive.skill_id) == 0 and player.get_node("Stamina").current() == 100, "Invalid target rolls back cooldown without spending resource")
	robot.position.y += 200
	check(skills.try_use(3, b) and player.get_node("Stamina").current() == 80, "Optional skill cost is spent once at commitment")
	a.cancel_action()
	var interruptible := skill(&"interruptible")
	interruptible.attack.stamina_cost = 5
	skills.learn(interruptible)
	skills.equip(4, interruptible.skill_id)
	var lock_tokens: Array[int] = []
	var interrupt := func(_current: float, _maximum: float) -> void: lock_tokens.append(player.acquire_control_lock())
	player.get_node("Stamina").changed.connect(interrupt)
	check(skills.try_use(4, b) and a.phase == CombatComponent.Phase.READY, "Resource callback interruption cannot resurrect the committed attack")
	player.get_node("Stamina").changed.disconnect(interrupt)
	for lock_token in lock_tokens:
		player.release_control_lock(lock_token)
	check(skills.remaining(interruptible.skill_id) == 2 and player.get_node("Stamina").current() == 75, "Interrupted commitment retains cost and skill cooldown")
	var other := skill(&"other", 0)
	skills.learn(other)
	reset()
	a.try_attack(b)
	a._physics_process(0.31)
	world.get_node("CombatResolver").flush()
	check(a.request_skill(0), "Skill input can be buffered at end of recovery")
	skills.equip(0, other.skill_id)
	a._physics_process(0.091)
	world.get_node("CombatResolver").flush()
	check(a.phase == CombatComponent.Phase.READY, "Changing equipped skill invalidates old buffered intent")
	skills.equip(0, &"purple_clash")
	var duplicate: Array[bool] = []
	var reenter := func(_direction: Vector2) -> void: duplicate.append(skills.try_use(0))
	a.attack_started.connect(reenter)
	check(skills.try_use(0), "Zero cooldown purple skill still starts normally")
	a.attack_started.disconnect(reenter)
	check(duplicate == [false], "Attack-start callback cannot recursively use another skill")
	reset()
	a.remove_child(skills)
	check(not a.request_purple() and a.try_attack(b), "Optional skill removal keeps ordinary attacks operational")
	skills.free()

func run() -> void:
	create_timer(30).timeout.connect(func() -> void: quit(1))
	test_calculation()
	await prepare()
	player.set_physics_process(false)
	player.get_node("CombatFeedback").sound_enabled = false
	robot.get_node("CombatFeedback").sound_enabled = false
	test_receiver()
	test_skills()
	world.queue_free()
	await frames()
	print("ATTACK/SKILL/DAMAGE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
