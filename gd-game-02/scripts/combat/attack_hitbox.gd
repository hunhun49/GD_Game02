class_name AttackHitbox
extends Area2D

# Default: reusable convex sectors derived from attack reach/arc. For a weapon,
# turn this off and author CollisionShape2D children under this node instead.
@export var use_attack_sector: bool = true
@export var orient_to_attack: bool = true
var active: bool = false:
	set(value):
		active = value
		for index in range(_sector_nodes.size()):
			_sector_nodes[index].set_deferred("disabled", not active or index >= _sectors.size())
var _sector_nodes: Array[CollisionShape2D] = []
var _cached_size := Vector2.ZERO
var _sectors: Array[Shape2D] = []

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false

func configure(definition: AttackDefinition, aim: Vector2) -> void:
	if orient_to_attack:
		global_rotation = aim.angle()
	if use_attack_sector:
		sector_shapes(definition)

func sector_shapes(definition: AttackDefinition) -> Array[Shape2D]:
	var size := Vector2(definition.reach, definition.arc_degrees)
	if size == _cached_size:
		return _sectors
	_cached_size = size
	_sectors.clear()
	var count := maxi(1, ceili(definition.arc_degrees / 90.0))
	var arc := deg_to_rad(definition.arc_degrees)
	for section in range(count):
		var points := PackedVector2Array([Vector2.ZERO])
		for step in range(13):
			var angle := -arc * 0.5 + arc * (section + step / 12.0) / count
			points.append(Vector2.from_angle(angle) * definition.reach)
		var shape := ConvexPolygonShape2D.new()
		shape.points = points
		_sectors.append(shape)
		if _sector_nodes.size() <= section:
			var node := CollisionShape2D.new()
			node.name = "Sector%d" % section
			node.disabled = not active
			add_child(node)
			_sector_nodes.append(node)
		_sector_nodes[section].shape = shape
	for section in range(_sector_nodes.size()):
		_sector_nodes[section].set_deferred("disabled", not active or section >= count)
	return _sectors

func overlaps(hurtbox: Hurtbox, definition: AttackDefinition, aim: Vector2) -> bool:
	# Shape2D.collide avoids the previous-frame cache of Area overlap signals.
	var basis := Transform2D(Vector2.from_angle(aim.angle()) * global_scale.x, Vector2.from_angle(aim.angle() + PI / 2) * global_scale.y, global_position)
	if not orient_to_attack:
		basis = global_transform
	for hurt in hurtbox.shapes():
		if use_attack_sector:
			for shape in sector_shapes(definition):
				if shape.collide(basis, hurt.shape, hurt.global_transform):
					return true
		else:
			for child in get_children():
				if child is CollisionShape2D and child not in _sector_nodes and child.shape != null and not child.disabled and child.shape.collide(basis * child.transform, hurt.shape, hurt.global_transform):
					return true
	return false

func targets(source: CombatComponent, definition: AttackDefinition, aim: Vector2) -> Array[CombatComponent]:
	var result: Array[CombatComponent] = []
	var seen: Dictionary[StringName, bool] = {}
	for node in get_tree().get_nodes_in_group("combat_hurtboxes"):
		var hurt := node as Hurtbox
		var victim := hurt.combat()
		if not source.valid_target(victim) or seen.has(victim.actor().character_id):
			continue
		if overlaps(hurt, definition, aim) and clear_path(source, victim, hurt.global_position):
			seen[victim.actor().character_id] = true
			result.append(victim)
	result.sort_custom(func(a: CombatComponent, b: CombatComponent) -> bool: return String(a.actor().character_id) < String(b.actor().character_id))
	return result

func touches(source: CombatComponent, victim: CombatComponent, definition: AttackDefinition, aim: Vector2) -> bool:
	if not source.valid_target(victim):
		return false
	for node in get_tree().get_nodes_in_group("combat_hurtboxes"):
		var hurt := node as Hurtbox
		if hurt.combat() == victim and overlaps(hurt, definition, aim) and clear_path(source, victim, hurt.global_position):
			return true
	return false

func clear_path(source: CombatComponent, victim: CombatComponent, endpoint: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(source.actor().global_position, endpoint, 1)
	var excluded: Array[RID] = [source.actor().get_rid(), victim.actor().get_rid()]
	# Combatant bodies obstruct walking, not a cleave through multiple hurtboxes.
	for node in get_tree().get_nodes_in_group("combatants"):
		var combatant := node as CombatComponent
		if combatant.get_scope() == source.get_scope():
			excluded.append(combatant.actor().get_rid())
	ray.exclude = excluded
	return source.actor().get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
