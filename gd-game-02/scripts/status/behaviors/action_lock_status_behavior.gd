class_name ActionLockStatusBehavior
extends StatusBehavior

@export_flags("Move:1", "Interact:2", "Attack:4", "Defend:16", "Dodge:64", "Skill:128") var blocked_actions: int = 0

func is_valid() -> bool:
	var allowed := SchoolCharacter.Action.MOVE | SchoolCharacter.Action.INTERACT | SchoolCharacter.Action.ATTACK | SchoolCharacter.Action.DEFEND | SchoolCharacter.Action.DODGE | SchoolCharacter.Action.SKILL
	return blocked_actions > 0 and (blocked_actions & ~allowed) == 0

func contribute(modifiers: StatusModifiers, _stacks: int) -> void:
	modifiers.blocked_actions |= blocked_actions
