class_name CombatResolver
extends Node

# One resolver per active-world scope. No global character registry/state owner.
class Contact extends RefCounted:
	var source: WeakRef
	var target: WeakRef
	var result: DamageResult
	var statuses: Array[StatusEffectDefinition] = []
	func _init(from: CombatComponent, to: CombatComponent, value: DamageResult) -> void:
		source = weakref(from)
		target = weakref(to)
		result = value
		for effect in from.executor().move.on_hit_statuses:
			statuses.append(effect.duplicate(true) as StatusEffectDefinition)

var _pending: Dictionary[int, Dictionary] = {}
var _scheduled: bool = false
var _resolving: bool = false
var _epoch: int = 0

func enqueue(attack: AttackComponent) -> void:
	_pending[attack.get_instance_id()] = {"attack": weakref(attack), "serial": attack.generation()}
	_schedule()

func _schedule() -> void:
	if not _scheduled:
		_scheduled = true
		flush.call_deferred()

func _physics_process(_delta: float) -> void:
	if not _pending.is_empty():
		_schedule()

func clear() -> void:
	_epoch += 1
	_pending.clear()

func _belongs(combat: CombatComponent) -> bool:
	return is_instance_valid(combat) and combat.is_inside_tree() and not combat.is_queued_for_deletion() and not combat.actor().is_queued_for_deletion() and combat.get_scope() == get_parent() and get_parent().is_ancestor_of(combat)

func flush() -> void:
	_scheduled = false
	if _resolving or not can_process() or get_tree().paused:
		return
	var batch := _pending.values()
	_pending.clear()
	var contacts: Array[Contact] = []
	for entry in batch:
		var attack := entry.attack.get_ref() as AttackComponent
		if not is_instance_valid(attack) or attack.generation() != entry.serial or not _belongs(attack.combat()) or not attack.combat().time_running():
			continue
		for target in attack.candidates():
			var result := target.plan_attack(attack.combat(), attack.request(target))
			if result != null:
				contacts.append(Contact.new(attack.combat(), target, result))
	# Finish sampling only after every pair has read the same counter windows.
	for entry in batch:
		var attack := entry.attack.get_ref() as AttackComponent
		if is_instance_valid(attack):
			attack.finish_sample(entry.serial)
	_commit(contacts)

func resolve_single(source: CombatComponent, target: CombatComponent, request: DamageRequest) -> DamageResult:
	if _resolving or not can_process() or get_tree().paused or not _belongs(source) or not _belongs(target):
		return null
	var result := target.plan_attack(source, request)
	if result != null:
		var contacts: Array[Contact] = [Contact.new(source, target, result)]
		_commit(contacts)
	return result

func _commit(contacts: Array[Contact]) -> void:
	if contacts.is_empty():
		return
	_resolving = true
	var epoch := _epoch
	contacts.sort_custom(func(a: Contact, b: Contact) -> bool:
		var x := a.result.request
		var y := b.result.request
		# Compare content text explicitly, independent of interned StringName ordering.
		return String(x.source_id) < String(y.source_id) if x.source_id != y.source_id else String(x.target_id) < String(y.target_id)
	)
	var canceled: Dictionary[int, bool] = {}
	var clashes: Dictionary[int, CombatComponent] = {}
	var recoveries: Dictionary[int, CombatComponent] = {}
	var dash_counters: Dictionary[int, CombatComponent] = {}
	var actors: Dictionary[int, CombatComponent] = {}
	for contact in contacts:
		var source := contact.source.get_ref() as CombatComponent
		var target := contact.target.get_ref() as CombatComponent
		actors[source.get_instance_id()] = source
		actors[target.get_instance_id()] = target
		if contact.result.outcome == HitResolver.Outcome.CLASH:
			for actor in [source, target]:
				canceled[actor.executor().get_instance_id()] = true
				clashes[actor.get_instance_id()] = actor
		elif contact.result.outcome == HitResolver.Outcome.DASH_PARRY:
			canceled[source.executor().get_instance_id()] = true
			recoveries[source.get_instance_id()] = source
			dash_counters[target.get_instance_id()] = target
	# Countered attack instances cannot damage another target in the same batch.
	var accepted: Array[Contact] = []
	for contact in contacts:
		if not canceled.has(contact.result.request.emitter_id) or contact.result.outcome in [HitResolver.Outcome.CLASH, HitResolver.Outcome.DASH_PARRY]:
			accepted.append(contact)
	for actor in actors.values():
		actor.begin_resolution()
	for contact in accepted:
		var source := contact.source.get_ref() as CombatComponent
		source.executor().consume(contact.result.request.target_id)
	# Commit all counter state before publishing any signal.
	for actor in clashes.values():
		actor._enter_recovery(actor.executor().move.clash_recovery_seconds, false)
	for actor in recoveries.values():
		actor._enter_recovery(0.3, false)
	for actor in dash_counters.values():
		actor.dodge().cancel()
	# Damage plans are fixed before mutation. A lethal same-frame trade is valid;
	# death/stagger from another accepted contact does not retract its outgoing hit.
	for contact in accepted:
		var source := contact.source.get_ref() as CombatComponent
		var target := contact.target.get_ref() as CombatComponent
		if epoch != _epoch or not _belongs(source) or not _belongs(target):
			continue
		if source.actor().is_action_locked(SchoolCharacter.Action.COMBAT_TICK) or target.actor().is_action_locked(SchoolCharacter.Action.COMBAT_TICK) or not source.can_process() or not target.can_process() or get_tree().paused:
			continue
		target.apply_damage_result(source, contact.result)
		if contact.result.outcome != HitResolver.Outcome.CLASH:
			target.resolved.emit(contact.result.outcome)
		target.contact_received.emit(source, contact.result.outcome)
		target.damage_resolved.emit(contact.result.copy())
	# Apply ailments after every accepted hit. A stun cannot erase an already
	# accepted simultaneous trade; callbacks/reset must not leak effects into a new encounter.
	for contact in accepted:
		var target := contact.target.get_ref() as CombatComponent
		if epoch != _epoch or not _belongs(target) or get_tree().paused or not target.can_process() or target.actor().is_action_locked(SchoolCharacter.Action.COMBAT_TICK):
			continue
		if contact.result.outcome != HitResolver.Outcome.HIT or contact.result.applied_health <= 0:
			continue
		var effects := target.actor().status_effects()
		if effects != null:
			for settings in contact.statuses:
				if epoch != _epoch or not _belongs(target) or get_tree().paused or not target.can_process() or target.actor().is_action_locked(SchoolCharacter.Action.COMBAT_TICK):
					break
				effects.apply_status(settings, contact.result.request.source_id)
	if epoch == _epoch:
		for actor in clashes.values():
			if _belongs(actor):
				actor.phase_changed.emit()
				actor.resolved.emit(HitResolver.Outcome.CLASH)
		for actor in recoveries.values():
			if _belongs(actor):
				actor.phase_changed.emit()
	for actor in actors.values():
		if is_instance_valid(actor):
			actor.end_resolution()
	_resolving = false
