class_name DialogueDefinition
extends RefCounted

var id: StringName
var lines: Array[DialogueLine] = []
var on_complete: Array[DialogueEffect] = []

# Catalog data, each running session, and signal consumers own separate copies.
func copy() -> DialogueDefinition:
	var result := DialogueDefinition.new()
	result.id = id
	for line in lines:
		result.lines.append(line.copy())
	for effect in on_complete:
		result.on_complete.append(effect.copy())
	return result
