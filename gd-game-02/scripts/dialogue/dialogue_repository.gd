class_name DialogueRepository
extends RefCounted

const SCHEMA_VERSION := 1
var _effects: DialogueEffectRegistry
var _definitions: Dictionary[StringName, DialogueDefinition] = {}
var _errors: PackedStringArray = []
var _loaded: bool = false

func _init(effects: DialogueEffectRegistry) -> void:
	_effects = effects

func is_loaded() -> bool:
	return _loaded

func errors() -> PackedStringArray:
	return _errors.duplicate()

func get_dialogue(id: StringName) -> DialogueDefinition:
	var definition: DialogueDefinition = _definitions.get(id)
	return definition.copy() if definition != null else null

func load_files(paths: PackedStringArray) -> bool:
	_errors.clear()
	if not _effects.is_sealed():
		_errors.append("Effect registry must be sealed before loading dialogue content.")
		return false
	if paths.is_empty():
		_errors.append("At least one dialogue source is required.")
		return false
	var staged: Dictionary[StringName, DialogueDefinition] = {}
	for path in paths:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_errors.append("%s: cannot open file (error %d)." % [path, FileAccess.get_open_error()])
			continue
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) != OK:
			_errors.append("%s:%d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
			continue
		_parse_document(parser.data, path, staged)
	if not _errors.is_empty():
		return false
	# Transactional replacement: a failed reload retains the last known good catalog.
	_definitions = staged
	_loaded = true
	return true

func _parse_document(raw: Variant, source: String, staged: Dictionary[StringName, DialogueDefinition]) -> void:
	if raw is not Dictionary:
		_errors.append(source + ": root must be an object.")
		return
	_unknown_keys(raw, ["schema_version", "dialogues"], source)
	var version: Variant = raw.get("schema_version")
	if (version is not float and version is not int) or version != SCHEMA_VERSION:
		_errors.append(source + ": unsupported or missing schema_version (expected 1).")
	var entries: Variant = raw.get("dialogues")
	if entries is not Dictionary or entries.is_empty():
		_errors.append(source + ": dialogues must be a non-empty object.")
		return
	for id in entries:
		var path := "%s.dialogues.%s" % [source, id]
		if str(id).strip_edges().is_empty():
			_errors.append(path + ": dialogue ID must not be empty.")
			continue
		if staged.has(StringName(id)):
			_errors.append(path + ": duplicate dialogue ID across sources.")
			continue
		var definition := _parse_dialogue(entries[id], StringName(id), path)
		if definition != null:
			staged[definition.id] = definition

func _parse_dialogue(raw: Variant, id: StringName, path: String) -> DialogueDefinition:
	if raw is not Dictionary:
		_errors.append(path + ": dialogue must be an object.")
		return null
	var error_count := _errors.size()
	_unknown_keys(raw, ["lines", "on_complete"], path)
	var definition := DialogueDefinition.new()
	definition.id = id
	var lines: Variant = raw.get("lines")
	if lines is not Array or lines.is_empty():
		_errors.append(path + ".lines: expected a non-empty array.")
	else:
		for index in range(lines.size()):
			var line: Variant = lines[index]
			var line_path := "%s.lines[%d]" % [path, index]
			if line is not Dictionary:
				_errors.append(line_path + ": expected an object.")
				continue
			_unknown_keys(line, ["speaker", "text"], line_path)
			if not _non_empty_string(line.get("speaker")) or not _non_empty_string(line.get("text")):
				_errors.append(line_path + ": speaker and text must be non-empty strings.")
				continue
			definition.lines.append(DialogueLine.new(line.speaker, line.text))
	var effects: Variant = raw.get("on_complete", [])
	if effects is not Array:
		_errors.append(path + ".on_complete: expected an array.")
	else:
		for index in range(effects.size()):
			var item: Variant = effects[index]
			var effect_path := "%s.on_complete[%d]" % [path, index]
			if item is not Dictionary or not _non_empty_string(item.get("type")) or item.get("parameters") is not Dictionary:
				_errors.append(effect_path + ": expected type and parameters object.")
				continue
			_unknown_keys(item, ["type", "parameters"], effect_path)
			var effect := DialogueEffect.new(StringName(item.type), item.parameters)
			var error := _effects.validate(effect)
			if not error.is_empty():
				_errors.append(effect_path + ": " + error)
			else:
				definition.on_complete.append(effect)
	return definition if error_count == _errors.size() else null

func _non_empty_string(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()

func _unknown_keys(object: Dictionary, allowed: Array, path: String) -> void:
	for key in object:
		if not allowed.has(key):
			_errors.append("%s: unknown field '%s'." % [path, key])
