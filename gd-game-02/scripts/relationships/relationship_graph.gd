class_name RelationshipGraph
extends RefCounted

# Directed adjacency map. Never expose mutable edges to callers.
var _edges: Dictionary = {}

static func valid_pair(from_id: StringName, to_id: StringName) -> bool:
	return not String(from_id).strip_edges().is_empty() and not String(to_id).strip_edges().is_empty() and from_id != to_id

func affinity(from_id: StringName, to_id: StringName) -> float:
	if not _edges.has(from_id) or not _edges[from_id].has(to_id):
		return 0.0
	return _edges[from_id][to_id].affinity

func _write(from_id: StringName, to_id: StringName, value: float) -> void:
	if value == 0.0:
		if _edges.has(from_id):
			_edges[from_id].erase(to_id)
			if _edges[from_id].is_empty():
				_edges.erase(from_id)
		return
	if not _edges.has(from_id):
		_edges[from_id] = {}
	_edges[from_id][to_id] = RelationshipState.new(value)

func snapshot() -> Dictionary:
	var edges: Array[Dictionary] = []
	var sources: Array = _edges.keys()
	sources.sort()
	for from_id in sources:
		var targets: Array = _edges[from_id].keys()
		targets.sort()
		for to_id in targets:
			edges.append({"from": String(from_id), "to": String(to_id), "affinity": affinity(from_id, to_id)})
	return {"schema_version": 1, "edges": edges}

func restore(data: Dictionary) -> bool:
	var version: Variant = data.get("schema_version")
	if not _edges.is_empty() or not DataValidation.is_finite_number(version) or version != 1 or not data.get("edges") is Array:
		return false
	var staged := RelationshipGraph.new()
	var seen: Dictionary = {}
	for edge in data.edges:
		if not edge is Dictionary or edge.size() != 3 or not edge.get("from") is String or not edge.get("to") is String:
			return false
		var from_id := StringName(edge.from)
		var to_id := StringName(edge.to)
		var value: Variant = edge.get("affinity")
		if not valid_pair(from_id, to_id) or not DataValidation.is_finite_number(value) or value < RelationshipState.MIN_AFFINITY or value > RelationshipState.MAX_AFFINITY:
			return false
		if not seen.has(from_id):
			seen[from_id] = {}
		if seen[from_id].has(to_id):
			return false
		seen[from_id][to_id] = true
		staged._write(from_id, to_id, value)
	_edges = staged._edges
	return true
