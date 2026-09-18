class_name CombatComponent
extends Node

signal attack_started(direction: Vector2)
signal encounter_reset
signal phase_changed
signal contact_received(source: CombatComponent, outcome: HitResolver.Outcome)
signal resolved(outcome: HitResolver.Outcome)
signal hit_landed(target_id: StringName, target_name: String, amount: float)
signal finished_target(target_name: String)
signal damage_resolved(result: DamageResult)

enum Phase { READY, WINDUP, ACTIVE, RECOVERY }
@export_flags("Player", "Training", "Hostile") var team: int = 1
@export_flags("Player", "Training", "Hostile") var target_teams: int = 2
@export var enabled: bool = true
@export var finishable: bool = false
@export var defense_profile: DefenseProfile

# Compatibility facade. AttackComponent is the sole owner of execution state.
var attack: AttackDefinition:
	get: return executor().default_attack if executor() != null else null
	set(value): executor().default_attack = value
var phase: Phase:
	get: return executor().phase if executor() != null else Phase.READY
var phase_left: float:
	get: return executor().phase_left if executor() != null else 0.0
var attack_direction: Vector2:
	get: return executor().direction if executor() != null else Vector2.DOWN
var _scope: Node
var _focus: WeakRef
var _committing: bool = false
var _buffered: int = 0
var _buffer_left: float = 0.0
var _buffered_slot: int = -1
var _buffered_skill: StringName

func executor() -> AttackComponent:
	return get_node_or_null("Attack") as AttackComponent

func resolver() -> CombatResolver:
	return _scope.get_node_or_null("CombatResolver") as CombatResolver if is_instance_valid(_scope) else null

func skills() -> SkillComponent:
	return get_node_or_null("Skills") as SkillComponent

func _ready() -> void:
	if executor() == null:
		push_error("CombatComponent requires an Attack child.")
		enabled = false
		return
	add_to_group("combatants")
	if posture() != null:
		posture().broken.connect(cancel_action)
	if health() != null:
		health().incapacitated.connect(reset_encounter)

func actor() -> SchoolCharacter:
	return get_parent() as SchoolCharacter

func health() -> HealthComponent:
	return get_parent().get_node_or_null("Health") as HealthComponent

func posture() -> PostureComponent:
	return get_parent().get_node_or_null("Posture") as PostureComponent

func aim_direction() -> Vector2:
	var aim := actor().get_node_or_null("Aim") as AimComponent
	return aim.direction if aim != null and aim.pointer_active else actor().facing

func uses_pointer() -> bool:
	var aim := actor().get_node_or_null("Aim") as AimComponent
	return aim != null and aim.pointer_active

func dodge() -> DodgeComponent:
	return actor().get_node_or_null("Dodge") as DodgeComponent

func guard() -> GuardComponent:
	return get_parent().get_node_or_null("Guard") as GuardComponent

func set_scope(scope: Node) -> void:
	if _scope != scope:
		reset_encounter()
	_scope = scope

func get_scope() -> Node:
	return _scope

func is_staggered() -> bool:
	return posture() != null and posture().is_broken()

func blocks_action(action: int) -> bool:
	if action == SchoolCharacter.Action.COMBAT_TICK or action == SchoolCharacter.Action.RECOVER:
		return false
	if _committing or is_staggered() or (dodge() != null and dodge().is_busy()):
		return true
	if action in [SchoolCharacter.Action.DEFEND, SchoolCharacter.Action.DODGE]:
		return phase != Phase.READY and not executor().can_cancel()
	if action in [SchoolCharacter.Action.ATTACK, SchoolCharacter.Action.SKILL]:
		return phase != Phase.READY
	if action == SchoolCharacter.Action.MOVE:
		return phase != Phase.READY
	return phase != Phase.READY or (guard() != null and guard().holding)

func time_running() -> bool:
	return enabled and is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(_scope) and _scope.is_ancestor_of(self) and actor().can_act(SchoolCharacter.Action.COMBAT_TICK)

func cooldown_remaining() -> float:
	return executor().remaining() if executor() != null else 0.0

func can_attack(definition: AttackDefinition = null, action: SchoolCharacter.Action = SchoolCharacter.Action.ATTACK) -> bool:
	var settings := definition if definition != null else attack
	if _committing or not time_running() or action not in [SchoolCharacter.Action.ATTACK, SchoolCharacter.Action.SKILL] or not actor().can_act(action) or settings == null or not settings.is_valid():
		return false
	if settings.stamina_cost > 0:
		var stamina := actor().get_node_or_null("Stamina") as StaminaComponent
		if stamina == null or not stamina.can_spend(settings.stamina_cost):
			return false
	return true

func valid_target(target: CombatComponent) -> bool:
	if not is_instance_valid(target) or target == self or not target.enabled or not target.is_inside_tree() or target.is_queued_for_deletion() or target._scope != _scope:
		return false
	if not is_instance_valid(_scope) or not _scope.is_ancestor_of(target) or not (target.team & target_teams):
		return false
	var victim := target.actor()
	var hp := target.health()
	return victim != null and hp != null and hp.can_take_damage() and victim.is_visible_in_tree() and actor().get_world_2d() == victim.get_world_2d() and victim.can_act(SchoolCharacter.Action.COMBAT_TICK)

func in_attack_range(target: CombatComponent, definition: AttackDefinition = null, direction: Vector2 = Vector2.ZERO) -> bool:
	return executor() != null and executor().in_range(target, definition, direction)

func find_target(id: StringName = &"", definition: AttackDefinition = null) -> CombatComponent:
	return executor().find_target(id, definition) if executor() != null else null

func _weak_target(reference: WeakRef) -> CombatComponent:
	return reference.get_ref() as CombatComponent if reference != null else null

func face_target(target: CombatComponent) -> void:
	if not valid_target(target):
		return
	var direction := target.actor().global_position - actor().global_position
	if not direction.is_zero_approx():
		actor().facing = Vector2(signf(direction.x), 0) if absf(direction.x) > absf(direction.y) else Vector2(0, signf(direction.y))

func maintain_guard_facing() -> void:
	if guard() == null or not guard().holding:
		return
	if uses_pointer():
		guard().direction = aim_direction()
		return
	var target := _weak_target(_focus)
	if valid_target(target) and actor().global_position.distance_to(target.actor().global_position) < 180:
		face_target(target)
		guard().direction = (target.actor().global_position - actor().global_position).normalized()
	else:
		var direction := guard().direction
		actor().facing = Vector2(signf(direction.x), 0) if absf(direction.x) > absf(direction.y) else Vector2(0, signf(direction.y))

func set_guard(pressed: bool, allow_deflect: bool = true) -> bool:
	if guard() == null:
		return false
	if not pressed:
		guard().end()
		return true
	if _committing or not time_running() or not actor().can_act(SchoolCharacter.Action.DEFEND):
		return false
	if phase == Phase.WINDUP:
		cancel_action()
	if not guard().holding:
		var target := find_target()
		_focus = weakref(target) if target != null else null
		var direction := aim_direction()
		if target != null and not uses_pointer():
			direction = (target.actor().global_position - actor().global_position).normalized()
		guard().begin(direction, allow_deflect)
	return true

func try_attack(target: CombatComponent = null, definition: AttackDefinition = null, allow_finish: bool = true, action: SchoolCharacter.Action = SchoolCharacter.Action.ATTACK) -> bool:
	var settings := definition if definition != null else attack
	if not can_attack(settings, action) or (target != null and not in_attack_range(target, settings)):
		return false
	if target == null:
		target = find_target(&"", settings)
	if allow_finish and settings.effective_kind() != AttackDefinition.Kind.PURPLE and target != null and target.finishable and target.is_staggered():
		return _finish(target, settings)
	_committing = true
	var direction := aim_direction()
	if target != null and not uses_pointer():
		direction = (target.actor().global_position - actor().global_position).normalized()
	executor().begin(settings, target, direction, false, action)
	var generation := executor().generation()
	if settings.stamina_cost > 0:
		if not (actor().get_node("Stamina") as StaminaComponent).spend(settings.stamina_cost):
			executor().cancel()
			_committing = false
			return false
		# Spending can publish signals that interrupt the committed action.
		# Keep the cost/cooldown, but never resurrect a canceled attack afterward.
		if executor().generation() != generation or not time_running():
			executor().cancel()
			_committing = false
			return true
	_focus = weakref(target) if target != null else null
	if guard() != null:
		guard().end()
	actor().reset_motion()
	attack_started.emit(attack_direction)
	phase_changed.emit()
	_committing = false
	return true

func _finish(target: CombatComponent, settings: AttackDefinition) -> bool:
	executor().begin(settings, target, aim_direction(), true)
	var request := executor().request()
	var target_name := target.actor().definition.display_name
	var result := target.receive_attack(self, request)
	executor().cancel()
	phase_changed.emit()
	if result != null and result.applied_health > 0:
		finished_target.emit(target_name)
		return true
	return false

func interrupt_actions(actions: int) -> void:
	# Cancel only the matching execution/intent. Counter recovery is not a skill.
	var attack_canceled := executor() != null and executor().is_executing() and (actions & executor().execution_action) != 0
	if attack_canceled:
		executor().cancel()
	if actions & SchoolCharacter.Action.DEFEND and guard() != null:
		guard().end()
	if actions & SchoolCharacter.Action.DODGE and dodge() != null:
		dodge().cancel()
	var buffered_action: int = {1: SchoolCharacter.Action.ATTACK, 2: SchoolCharacter.Action.DEFEND, 3: SchoolCharacter.Action.SKILL, 4: SchoolCharacter.Action.DODGE}.get(_buffered, 0)
	if actions & buffered_action:
		_buffered = 0
		_buffer_left = 0
	if attack_canceled:
		phase_changed.emit()

func cancel_action() -> void:
	if executor() != null:
		executor().cancel()
	if dodge() != null:
		dodge().cancel()
	_buffered = 0
	_buffer_left = 0
	if guard() != null:
		guard().end()
	phase_changed.emit()

func reset_encounter() -> void:
	cancel_action()
	_focus = null
	if posture() != null:
		posture().reset()
	if guard() != null:
		guard().reset()
	encounter_reset.emit()

func is_dangerous_attack() -> bool:
	return phase != Phase.READY and current_attack_kind() in [AttackDefinition.Kind.RED, AttackDefinition.Kind.PURPLE]

func _physics_process(delta: float) -> void:
	if not time_running():
		return
	if posture() != null:
		posture().tick(delta, health().current() / health().maximum())
	if guard() != null:
		guard().tick(delta)
	if skills() != null:
		skills().tick(delta)
	if is_staggered():
		return
	maintain_guard_facing()
	_buffer_left = maxf(0, _buffer_left - delta)
	executor().tick(delta * actor().action_speed_multiplier())
	if phase == Phase.READY and _buffered != 0:
		var intent := _buffered
		_buffered = 0
		if _buffer_left > 0:
			if intent == 1:
				try_attack()
			elif intent == 2:
				set_guard(true)
			elif intent == 3:
				if skills() != null and skills().skill_id(_buffered_slot) == _buffered_skill:
					skills().try_use(_buffered_slot)
			elif intent == 4:
				request_dodge()

func _enter_recovery(seconds: float, notify: bool = true) -> void:
	executor().enter_recovery(seconds)
	_buffered = 0
	if guard() != null:
		guard().end()
	actor().reset_motion()
	if notify:
		phase_changed.emit()

# The receiver samples its defense; the scope resolver commits whole batches.
func plan_attack(source: CombatComponent, request: DamageRequest) -> DamageResult:
	if _committing or not is_instance_valid(source) or source._committing or not source.time_running() or not time_running() or source.executor() == null or not source.executor().accepts(self, request):
		return null
	if request.execution and (not finishable or not is_staggered()):
		return null
	var incoming := source.actor().global_position - actor().global_position
	var defense := guard()
	var dash := dodge()
	var covered := defense != null and defense.covers(incoming) and not is_staggered()
	var outcome := HitResolver.Outcome.HIT if request.execution else HitResolver.resolve_kind(request.kind, covered, covered and defense.can_deflect(), dash != null and dash.evades_normal(), dash != null and dash.can_counter(incoming), source.executor().clashes_with(executor()))
	return DamageResolver.resolve(request, outcome, defense_profile)

# Immediate explicit submissions (notably finishers) still use the same resolver.
func receive_attack(source: CombatComponent, request: DamageRequest) -> DamageResult:
	return resolver().resolve_single(source, self, request) if resolver() != null else null

func begin_resolution() -> void:
	_committing = true

func end_resolution() -> void:
	_committing = false

func apply_damage_result(source: CombatComponent, result: DamageResult) -> void:
	if result.source_posture > 0 and source.posture() != null:
		source.posture().add(result.source_posture)
	if result.outcome == HitResolver.Outcome.HIT:
		result.applied_health = health().take_damage(DamageEvent.from_result(result))
		if health().current() > 0 and posture() != null:
			posture().add(result.target_posture)
		if result.applied_health > 0:
			source.hit_landed.emit(actor().character_id, actor().definition.display_name, result.applied_health)
	elif result.target_posture > 0 and posture() != null:
		posture().add(result.target_posture)

func request_attack() -> bool:
	if try_attack():
		return true
	return _buffer(1)

func request_guard(pressed: bool) -> bool:
	if not pressed and _buffered == 2:
		_buffered = 0
	if set_guard(pressed):
		return true
	return pressed and _buffer(2)

func _buffer(intent: int) -> bool:
	var action: int = {1: SchoolCharacter.Action.ATTACK, 2: SchoolCharacter.Action.DEFEND, 3: SchoolCharacter.Action.SKILL, 4: SchoolCharacter.Action.DODGE}.get(intent, SchoolCharacter.Action.ATTACK)
	if actor().is_action_locked(action):
		return false
	if not _committing and time_running() and not is_staggered() and phase == Phase.RECOVERY and phase_left / actor().action_speed_multiplier() <= 0.1:
		_buffered = intent
		_buffer_left = 0.1 + 0.0001
		return true
	return false

func telegraph_reach() -> float:
	return executor().move.reach if executor() != null and executor().move != null else 0.0

func telegraph_arc() -> float:
	return deg_to_rad(executor().move.arc_degrees) if executor() != null and executor().move != null else 0.0

func request_skill(slot: int) -> bool:
	if skills() == null or skills().skill_id(slot).is_empty():
		return false
	if skills().try_use(slot):
		return true
	if _buffer(3):
		_buffered_slot = slot
		_buffered_skill = skills().skill_id(slot)
		return true
	return false

func request_purple() -> bool:
	return request_skill(0)

func request_dodge() -> bool:
	if _committing or not time_running() or dodge() == null:
		return false
	if not actor().can_act(SchoolCharacter.Action.DODGE):
		return _buffer(4)
	if phase == Phase.WINDUP:
		cancel_action()
	if guard() != null:
		guard().end()
	_buffered = 0
	return dodge().begin(aim_direction())

func current_attack_kind() -> AttackDefinition.Kind:
	return executor().move.effective_kind() if executor() != null and executor().move != null else AttackDefinition.Kind.NORMAL
