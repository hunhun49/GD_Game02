class_name AttackComponent
extends Node

@export var hitbox_path: NodePath = NodePath("../../AttackHitbox")
@export var default_attack: AttackDefinition
var phase: CombatComponent.Phase = CombatComponent.Phase.READY
var phase_left: float = 0.0
var direction: Vector2 = Vector2.DOWN
var elapsed: float = 0.0
var move: AttackDefinition
var _target: WeakRef
var _canceled: bool = true
var _hit_ids: Dictionary[StringName, bool] = {}
var _pending_contact: bool = false
var _execution: bool = false
var _serial: int = 0
var execution_action: SchoolCharacter.Action = SchoolCharacter.Action.ATTACK

func hitbox() -> AttackHitbox:
	return get_node(hitbox_path) as AttackHitbox

func combat() -> CombatComponent:
	return get_parent() as CombatComponent

func begin(settings: AttackDefinition, target: CombatComponent, aim: Vector2, execution: bool = false, action: SchoolCharacter.Action = SchoolCharacter.Action.ATTACK) -> void:
	_serial += 1
	_execution = execution
	execution_action = action
	_pending_contact = false
	_hit_ids.clear()
	move = settings.duplicate(true) as AttackDefinition
	_target = weakref(target) if target != null else null
	_canceled = false
	hitbox().configure(move, aim)
	hitbox().active = false
	elapsed = 0
	direction = aim
	phase = CombatComponent.Phase.WINDUP
	phase_left = move.windup_seconds

func target() -> CombatComponent:
	return _target.get_ref() as CombatComponent if _target != null else null

func cancel() -> void:
	_serial += 1
	_pending_contact = false
	hitbox().active = false
	phase = CombatComponent.Phase.READY
	phase_left = 0
	_target = null
	_canceled = true

func enter_recovery(seconds: float) -> void:
	_serial += 1
	_canceled = true
	_pending_contact = false
	hitbox().active = false
	phase = CombatComponent.Phase.RECOVERY
	phase_left = seconds

func is_executing() -> bool:
	return phase != CombatComponent.Phase.READY and not _canceled

func can_cancel() -> bool:
	return phase == CombatComponent.Phase.WINDUP and elapsed <= move.guard_cancel_seconds

func recovery_duration() -> float:
	return maxf(move.recovery_seconds, move.cooldown_seconds - move.windup_seconds - move.active_seconds)

func remaining() -> float:
	match phase:
		CombatComponent.Phase.WINDUP:
			return phase_left + move.active_seconds + recovery_duration()
		CombatComponent.Phase.ACTIVE:
			return phase_left + recovery_duration()
		CombatComponent.Phase.RECOVERY:
			return phase_left
	return 0

# The owning Combat advances time, so pause/locks and test clocks stay unified.
func tick(delta: float) -> void:
	if phase == CombatComponent.Phase.READY or not is_finite(delta) or delta <= 0:
		return
	elapsed += delta
	phase_left -= delta
	if phase == CombatComponent.Phase.ACTIVE:
		_contact()
	while phase_left <= 0 and phase != CombatComponent.Phase.READY:
		match phase:
			CombatComponent.Phase.WINDUP:
				phase = CombatComponent.Phase.ACTIVE
				phase_left += move.active_seconds
				_contact()
			CombatComponent.Phase.ACTIVE:
				phase = CombatComponent.Phase.RECOVERY
				phase_left += recovery_duration()
			CombatComponent.Phase.RECOVERY:
				phase = CombatComponent.Phase.READY
		hitbox().active = phase == CombatComponent.Phase.ACTIVE
		combat().phase_changed.emit()

func in_range(victim: CombatComponent, definition: AttackDefinition = null, aim: Vector2 = Vector2.ZERO) -> bool:
	var settings := definition if definition != null else default_attack
	if settings == null or not settings.is_valid() or not combat().valid_target(victim):
		return false
	return hitbox().touches(combat(), victim, settings, combat().aim_direction() if aim.is_zero_approx() else aim)

func find_target(id: StringName = &"", definition: AttackDefinition = null) -> CombatComponent:
	if not is_inside_tree() or not is_instance_valid(combat().get_scope()):
		return null
	var selected: CombatComponent
	var distance := INF
	for node in get_tree().get_nodes_in_group("combatants"):
		var candidate := node as CombatComponent
		if not combat().valid_target(candidate) or (not id.is_empty() and candidate.actor().character_id != id):
			continue
		if id.is_empty() and not in_range(candidate, definition):
			continue
		var squared := combat().actor().global_position.distance_squared_to(candidate.actor().global_position)
		if squared < distance:
			distance = squared
			selected = candidate
	return selected

func request(victim: CombatComponent = null) -> DamageRequest:
	if victim == null:
		victim = target()
	if victim == null or move == null:
		return null
	var payload := DamageRequest.from_attack(combat().actor().character_id, victim.actor().character_id, move, get_instance_id(), _serial)
	payload.execution = _execution
	if _execution:
		payload.amount = victim.health().current()
	return payload

func window_open() -> bool:
	return not _canceled and (phase == CombatComponent.Phase.ACTIVE or _pending_contact)

func accepts(victim: CombatComponent, payload: DamageRequest) -> bool:
	return payload != null and (_execution or window_open()) and payload.matches(request(victim)) and not _canceled and not _hit_ids.has(victim.actor().character_id) and (not _execution or target() == victim) and payload.emitter_id == get_instance_id() and payload.sequence == _serial and in_range(victim, move, direction)

func generation() -> int:
	return _serial

func consume(victim_id: StringName) -> void:
	_hit_ids[victim_id] = true

func clashes_with(other: AttackComponent) -> bool:
	return other != null and window_open() and other.window_open() and move.effective_kind() == AttackDefinition.Kind.PURPLE and other.move.effective_kind() == AttackDefinition.Kind.PURPLE and not _hit_ids.has(other.combat().actor().character_id) and not other._hit_ids.has(combat().actor().character_id) and other.in_range(combat(), other.move, other.direction)

func candidates() -> Array[CombatComponent]:
	if not window_open():
		return []
	return hitbox().targets(combat(), move, direction)

func finish_sample(serial: int) -> void:
	if serial == _serial:
		_pending_contact = false

# Every attack category is collected after all actors update. Targets are found
# at contact time, rather than locked at windup; only finishers remain targeted.
func _contact() -> void:
	_pending_contact = true
	hitbox().active = true
	if combat().resolver() != null:
		combat().resolver().enqueue(self)
