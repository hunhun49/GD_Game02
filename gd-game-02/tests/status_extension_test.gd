extends "res://tests/status_effect_test.gd"

class LifecycleProbe extends StatusBehavior:
	@export_storage var on_enter: Callable
	@export_storage var on_exit: Callable
	@export_storage var on_tick: Callable
	func enter(context: StatusEffectContext) -> void:
		context.state.calls = 0
		if on_enter.is_valid():
			on_enter.call(context)
	func advance(context: StatusEffectContext, _delta: float) -> void:
		context.state.calls += 1
		if on_tick.is_valid():
			on_tick.call(context)
	func exit(context: StatusEffectContext) -> void:
		if on_exit.is_valid():
			on_exit.call(context)

func make_status(id: StringName, behaviors: Array[StatusBehavior]) -> StatusEffectDefinition:
	var definition := StatusEffectDefinition.new()
	definition.status_id = id
	definition.display_name = String(id)
	definition.behaviors = behaviors
	return definition

func locks(actions: int) -> StatusEffectDefinition:
	var behavior := ActionLockStatusBehavior.new()
	behavior.blocked_actions = actions
	return make_status(&"selective_lock", [behavior])

func modifier(id: StringName, factor: float, group: StringName = &"status_speed") -> StatusEffectDefinition:
	var behavior := StatModifierStatusBehavior.new()
	behavior.factor = factor
	behavior.group = group
	return make_status(id, [behavior])

func test_silence() -> void:
	clean()
	for id in ["silence", "regeneration", "haste", "stacking_poison"]:
		check(status(id).is_valid(), "Example resource is valid: " + id)
	var silence := locks(SchoolCharacter.Action.SKILL)
	a.try_attack(b)
	var generation := a.executor().generation()
	effects.apply_status(silence)
	check(a.phase == CombatComponent.Phase.WINDUP and a.executor().generation() == generation, "Silence preserves an already executing basic attack")
	a.cancel_action()
	check(a.try_attack(b), "Silenced actor may start a basic attack")
	a.cancel_action()
	check(a.set_guard(true) and not a.request_skill(0), "Silence allows guard but rejects skill request")
	a.request_guard(false)
	check(a.request_dodge(), "Silence permits new dash")
	effects.clear()
	effects.apply_status(silence)
	check(a.dodge().is_busy(), "Applying silence does not cancel existing dash")
	clean()
	a.set_guard(true)
	effects.apply_status(silence)
	check(a.guard().holding, "Applying silence does not cancel existing guard")
	clean()
	a.request_skill(0)
	check(a.executor().execution_action == SchoolCharacter.Action.SKILL, "Attack executor records skill origin")
	effects.apply_status(silence)
	check(a.phase == CombatComponent.Phase.READY, "Silence interrupts an executing skill")
	clean()
	var timed := a.skills().definition(a.skills().skill_id(0))
	timed.skill_id = &"silence_cooldown"
	timed.cooldown_seconds = 5
	a.skills().learn(timed)
	a.skills().equip(2, timed.skill_id)
	a.request_skill(2)
	effects.apply_status(silence)
	check(a.skills().remaining(timed.skill_id) == 5, "Interrupting a skill does not refund its committed cooldown")
	clean()
	var interrupt := func(_direction: Vector2) -> void: effects.apply_status(silence)
	a.attack_started.connect(interrupt, CONNECT_ONE_SHOT)
	check(a.request_skill(0) and a.phase == CombatComponent.Phase.READY, "Skill identity is recorded before attack-start callbacks")
	clean()
	a._enter_recovery(0.08)
	check(a.request_skill(0), "Skill can be buffered during counter recovery")
	effects.apply_status(silence)
	check(a.phase == CombatComponent.Phase.RECOVERY, "Silence cannot erase counter-imposed recovery")
	effects.clear()
	a._physics_process(0.09)
	check(a.phase == CombatComponent.Phase.READY, "Interrupted buffered skill does not fire after silence clears")
	clean()
	a._enter_recovery(0.08)
	a.request_attack()
	effects.apply_status(silence)
	a._physics_process(0.09)
	check(a.phase == CombatComponent.Phase.WINDUP, "Silence preserves buffered basic attack")
	clean()
	effects.apply_status(locks(SchoolCharacter.Action.DEFEND))
	check(a.try_attack(b) and not a.request_guard(true), "Guard-only prohibition does not prohibit attack")
	clean()
	effects.apply_status(locks(SchoolCharacter.Action.ATTACK))
	check(not a.request_attack() and a.request_skill(0), "Attack-only prohibition leaves skill permission independent")
	clean()

func test_policies() -> void:
	var poison := status("poison")
	var stack := StackStatusPolicy.new()
	stack.max_stacks = 3
	poison.reapply_policy = stack
	effects.apply_status(poison, &"alice")
	effects.tick(0.5)
	for i in range(4):
		effects.apply_status(poison, &"bob")
	check(effects.snapshots().size() == 1 and effects.snapshots()[0].stacks == 3, "Stack policy caps a shared stack group")
	effects.tick(0.5)
	check(a.health().current() == 91 and effects.snapshots()[0].source_id == &"alice", "Stacked damage scales while preserving tick phase and source ownership")
	clean()
	stack.per_source = true
	effects.apply_status(poison, &"alice")
	effects.apply_status(poison, &"bob")
	effects.apply_status(poison, &"alice")
	check(effects.snapshots().size() == 2, "Per-source policy creates independent status instances")
	effects.tick(1)
	check(a.health().current() == 91, "Per-source stacks damage independently")
	check(effects.cleanse(&"poison") == 2 and not effects.has_status(&"poison"), "Tag treatment cleanses all source instances")
	clean()
	stack.per_source = false
	stack.refresh_duration = false
	effects.apply_status(poison)
	effects.tick(0.5)
	effects.apply_status(poison)
	check(effects.snapshots()[0].remaining == 5.5, "Non-refresh stacking preserves expiry")
	clean()
	var replacement := ReplaceStatusPolicy.new()
	replacement.require_higher_priority = true
	poison.reapply_policy = replacement
	poison.priority = 1
	effects.apply_status(poison, &"weak_source")
	effects.tick(0.5)
	check(not effects.apply_status(poison), "Priority replacement rejects equal strength without refreshing")
	var stronger := poison.duplicate(true) as StatusEffectDefinition
	stronger.priority = 2
	stronger.behaviors[0].set("amount", 10)
	check(effects.apply_status(stronger, &"strong_source"), "Higher-priority application replaces existing instance")
	effects.tick(0.5)
	check(a.health().current() == 100, "Replacement starts a fresh tick clock")
	effects.tick(0.5)
	check(a.health().current() == 90 and effects.snapshots()[0].source_id == &"strong_source", "Replacement uses new settings and source")
	check(not effects.apply_status(poison), "Weaker application cannot overwrite stronger status")
	clean()
	var invalid := status("poison")
	invalid.reapply_policy = null
	check(not effects.apply_status(invalid), "Missing reapplication policy is rejected")
	stack.max_stacks = 0
	invalid.reapply_policy = stack
	check(not effects.apply_status(invalid), "Invalid stack cap is rejected")
	invalid = status("poison")
	invalid.behaviors.clear()
	check(not effects.apply_status(invalid), "Empty effect composition is rejected")

func test_composition() -> void:
	clean()
	var healing := PeriodicHealStatusBehavior.new()
	healing.amount = 5
	healing.interval = 0.5
	var slow := StatModifierStatusBehavior.new()
	slow.factor = 0.5
	var regeneration := make_status(&"regeneration", [healing, slow])
	a.health().take_damage(DamageEvent.new(&"test", 20))
	effects.apply_status(regeneration)
	effects.tick(1)
	check(a.health().current() == 90 and player.movement_speed_multiplier() == 0.5, "New heal behavior composes with modifier without manager branches")
	check(effects.remove_status(&"regeneration") and player.movement_speed_multiplier() == 1, "Removing composed status removes its modifier")
	effects.tick(1)
	check(a.health().current() == 90, "Removed heal behavior cannot keep ticking")
	clean()
	var shared := PeriodicDamageStatusBehavior.new()
	shared.amount = 2
	var twice := make_status(&"two_timers", [shared, shared])
	effects.apply_status(twice)
	robot.status_effects().apply_status(twice)
	effects.tick(0.5)
	robot.status_effects().tick(1)
	check(a.health().current() == 100 and b.health().current() == 156, "Shared resources have per-target and per-slot clocks")
	effects.tick(0.5)
	check(a.health().current() == 96, "Repeated behavior resource gets separate runtime state")
	clean()
	effects.apply_status(modifier(&"slow", 0.6))
	effects.apply_status(modifier(&"weak_slow", 0.8))
	effects.apply_status(modifier(&"haste", 1.5))
	effects.apply_status(modifier(&"weak_haste", 1.2))
	check(is_equal_approx(player.movement_speed_multiplier(), 0.9), "Same group combines strongest slow and strongest haste")
	effects.apply_status(modifier(&"terrain", 0.5, &"terrain"))
	check(is_equal_approx(player.movement_speed_multiplier(), 0.45), "Independent modifier groups multiply")
	effects.remove_status(&"haste")
	check(is_equal_approx(player.movement_speed_multiplier(), 0.36), "Removing strongest buff reveals remaining weaker buff")
	var generic := StatModifierStatusBehavior.new()
	generic.stat = &"healing_received"
	generic.factor = 1.5
	effects.apply_status(make_status(&"custom_stat", [generic]))
	check(effects.stat_multiplier(&"healing_received") == 1.5, "New stat keys aggregate without manager changes")
	clean()

func test_lifecycle() -> void:
	var events: Array[String] = []
	var first := LifecycleProbe.new()
	first.on_enter = func(_context: StatusEffectContext) -> void: events.append("enter1")
	first.on_exit = func(_context: StatusEffectContext) -> void: events.append("exit1")
	var second := LifecycleProbe.new()
	second.on_enter = func(_context: StatusEffectContext) -> void: events.append("enter2")
	second.on_exit = func(_context: StatusEffectContext) -> void: events.append("exit2")
	var probe := make_status(&"probe", [first, second])
	effects.apply_status(probe)
	effects.apply_status(probe)
	check(events == ["enter1", "enter2"], "Refresh does not reinstall lifecycle hooks")
	effects.clear()
	effects.clear()
	check(events == ["enter1", "enter2", "exit2", "exit1"], "Removal invokes cleanup once in reverse order")
	events.clear()
	first.on_enter = func(context: StatusEffectContext) -> void:
		events.append("enter1")
		context.owner().clear()
	effects.apply_status(probe)
	check(events == ["enter1", "exit1"] and effects.snapshots().is_empty(), "Removal during enter cleans only entered behaviors and stops remaining hooks")
	events.clear()
	first.on_enter = Callable()
	first.on_tick = func(context: StatusEffectContext) -> void: context.owner().clear()
	second.on_tick = func(_context: StatusEffectContext) -> void: events.append("stale_tick")
	effects.apply_status(probe)
	events.clear()
	effects.tick(1)
	check(events == ["exit2", "exit1"], "Removal during advance prevents later behavior execution")
	first.on_tick = Callable()
	first.on_exit = func(context: StatusEffectContext) -> void: context.owner().apply_status(status("slow"))
	probe.reapply_policy = ReplaceStatusPolicy.new()
	effects.apply_status(probe)
	effects.apply_status(probe)
	check(effects.has_status(&"slow") and effects.has_status(&"probe"), "Replacement cleanup can apply another status without losing it")
	clean()
	var cached_states: Array[Dictionary] = []
	var per_instance := LifecycleProbe.new()
	per_instance.on_tick = func(context: StatusEffectContext) -> void: cached_states.append(context.state.duplicate())
	var tracked := make_status(&"custom_behavior", [per_instance])
	effects.apply_status(tracked)
	robot.status_effects().apply_status(tracked)
	effects.tick(1)
	effects.tick(1)
	robot.status_effects().tick(1)
	check(cached_states[0].calls == 1 and cached_states[1].calls == 2 and cached_states[2].calls == 1, "Custom behavior runtime state is isolated across actors")
	clean()

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
	test_silence()
	test_policies()
	test_composition()
	test_lifecycle()
	world.queue_free()
	await frames()
	print("STATUS EXTENSION TESTS: %d checks, %d failure(s)" % [checks, failures])
	quit(1 if failures else 0)
