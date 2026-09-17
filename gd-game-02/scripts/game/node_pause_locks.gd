class_name NodePauseLocks
extends RefCounted

# All systems suspending the same zone share this owner. Each releases only its token.
var _next_token: int = 0
var _tokens: Dictionary[int, int] = {}
var _targets: Dictionary = {}

func acquire(target: Node) -> int:
	if not is_instance_valid(target):
		return 0
	_next_token += 1
	var id := target.get_instance_id()
	if not _targets.has(id):
		_targets[id] = {"node": weakref(target), "mode": target.process_mode, "count": 0}
	_targets[id].count += 1
	_tokens[_next_token] = id
	target.process_mode = Node.PROCESS_MODE_DISABLED
	return _next_token

func release(token: int) -> void:
	if not _tokens.has(token):
		return
	var id := _tokens[token]
	_tokens.erase(token)
	_targets[id].count -= 1
	if _targets[id].count > 0:
		return
	var target: Node = _targets[id].node.get_ref()
	if is_instance_valid(target):
		target.process_mode = _targets[id].mode
	_targets.erase(id)
