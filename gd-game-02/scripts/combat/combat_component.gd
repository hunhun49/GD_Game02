class_name CombatComponent
extends Node

signal attack_started(direction: Vector2)
signal hit_landed(target_id: StringName, target_name: String, amount: float)

@export var attack: AttackDefinition
@export_flags("Player", "Training", "Hostile") var team: int = 1
@export_flags("Player", "Training", "Hostile") var target_teams: int = 2
@export var enabled: bool = true

var _scope: Node
var _cooldown: float = 0.0
var _attacking: bool = false

func _ready() -> void:
	add_to_group("combatants")

func set_scope(scope: Node) -> void:
	_scope = scope

func get_scope() -> Node:
	return _scope

func actor() -> SchoolCharacter:
	return get_parent() as SchoolCharacter

func health() -> HealthComponent:
	return get_parent().get_node_or_null("Health") as HealthComponent

func cooldown_remaining() -> float:
	return _cooldown

func _physics_process(delta: float) -> void:
	if actor().can_act(SchoolCharacter.Action.ATTACK):
		_cooldown = maxf(0.0, _cooldown - delta)

func can_attack() -> bool:
	if attack != null and attack.stamina_cost > 0:
		var stamina := get_parent().get_node_or_null("Stamina") as StaminaComponent
		if stamina == null or not stamina.can_spend(attack.stamina_cost):
			return false
	return enabled and not _attacking and _cooldown <= 0 and attack != null and attack.is_valid() and is_instance_valid(_scope) and is_inside_tree() and _scope.is_ancestor_of(self) and actor().can_act(SchoolCharacter.Action.ATTACK)

func valid_target(target: CombatComponent) -> bool:
	if not is_instance_valid(target) or target == self or not target.enabled or not target.is_inside_tree() or target.is_queued_for_deletion() or target._scope != _scope:
		return false
	if not is_instance_valid(_scope) or not _scope.is_ancestor_of(target) or not (target.team & target_teams):
		return false
	var victim := target.actor()
	var victim_health := target.health()
	if victim == null or victim_health == null or not victim_health.can_take_damage() or not victim.is_visible_in_tree() or actor().get_world_2d() != victim.get_world_2d():
		return false
	return true

func in_attack_range(target: CombatComponent) -> bool:
	if attack == null or not attack.is_valid() or not valid_target(target):
		return false
	var source := actor()
	var victim := target.actor()
	var offset := victim.global_position - source.global_position
	if offset.length() > attack.reach:
		return false
	if not offset.is_zero_approx() and offset.normalized().dot(source.facing) < cos(deg_to_rad(attack.arc_degrees * 0.5)):
		return false
	var ray := PhysicsRayQueryParameters2D.create(source.global_position, victim.global_position, 1)
	ray.exclude = [source.get_rid(), victim.get_rid()]
	return source.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func find_target(id: StringName = &"") -> CombatComponent:
	if not is_inside_tree() or not is_instance_valid(_scope):
		return null
	var selected: CombatComponent
	var distance := INF
	for node in get_tree().get_nodes_in_group("combatants"):
		var target := node as CombatComponent
		if not valid_target(target) or (not id.is_empty() and target.actor().character_id != id):
			continue
		if id.is_empty() and not in_attack_range(target):
			continue
		var candidate_distance := actor().global_position.distance_squared_to(target.actor().global_position)
		if candidate_distance < distance:
			distance = candidate_distance
			selected = target
	return selected

func try_attack(target: CombatComponent = null) -> bool:
	if not can_attack():
		return false
	if target != null and not in_attack_range(target):
		return false
	if target == null:
		target = find_target()
	# Commit the action before publishing signals; a miss still has a cooldown.
	_attacking = true
	if attack.stamina_cost > 0:
		var stamina := get_parent().get_node("Stamina") as StaminaComponent
		if not stamina.spend(attack.stamina_cost):
			_attacking = false
			return false
	_cooldown = attack.cooldown_seconds
	attack_started.emit(actor().facing)
	if is_instance_valid(target) and actor().can_act(SchoolCharacter.Action.ATTACK) and in_attack_range(target):
		var target_id := target.actor().character_id
		var target_name := target.actor().definition.display_name
		var amount := target.health().take_damage(DamageEvent.new(actor().character_id, attack.damage))
		if amount > 0:
			hit_landed.emit(target_id, target_name, amount)
	_attacking = false
	return true
