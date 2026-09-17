class_name CharacterState
extends RefCounted

enum Activity { ACTIVE, SLEEPING, INCAPACITATED }

var needs: NeedsState
var character_id: StringName
var current_stamina: float = -1.0 # Uninitialized until an optional profile is bound.
var current_health: float = 100.0
var facing: Vector2 = Vector2.DOWN
var activity: Activity = Activity.ACTIVE

func snapshot() -> Dictionary:
	return {
		"character_id": String(character_id),
		"current_health": current_health,
		"current_stamina": current_stamina,
		"facing": [facing.x, facing.y],
		"activity": int(activity),
		"needs": needs.snapshot() if needs != null else null,
	}

# Validate completely before changing live state. Accept JSON-decoded numbers.
func restore(data: Dictionary) -> bool:
	if data.get("character_id") != String(character_id):
		return false
	var health: Variant = data.get("current_health")
	var stamina: Variant = data.get("current_stamina", -1.0)
	if not DataValidation.is_finite_number(stamina) or (stamina < 0 and stamina != -1):
		return false
	var direction: Variant = data.get("facing")
	var mode: Variant = data.get("activity")
	if not DataValidation.is_finite_number(health) or health < 0.0 or not DataValidation.is_finite_number(mode):
		return false
	if mode < 0 or mode > 2 or mode != floorf(float(mode)):
		return false
	if not direction is Array or direction.size() != 2 or not DataValidation.is_finite_number(direction[0]) or not DataValidation.is_finite_number(direction[1]):
		return false
	var restored_facing := Vector2(direction[0], direction[1])
	if restored_facing not in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		return false
	var restored_needs: NeedsState
	if data.get("needs") != null:
		if not data.needs is Dictionary:
			return false
		restored_needs = NeedsState.new()
		if not restored_needs.restore(data.needs):
			return false
	needs = restored_needs
	current_stamina = stamina
	current_health = health
	facing = restored_facing
	activity = int(mode) as Activity
	return true
