extends SceneTree

class CountingEffect extends DialogueEffectHandler:
	var calls: int = 0
	func validate(parameters: Dictionary) -> String:
		return "" if parameters.is_empty() else "No parameters allowed."
	func apply(_parameters: Dictionary) -> void:
		calls += 1

var checks: int = 0
var failures: int = 0
var _directory: String
var _repository: DialogueRepository
var _registry: DialogueEffectRegistry
var _state := SessionState.new()
var _counter := CountingEffect.new()
var _notifications: Array[String] = []
var _events: Array[String] = []
var _reentrant_results: Array[int] = []
var _finish_count: int = 0
var _game: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _valid() -> Dictionary:
	return {"schema_version": 1, "dialogues": {
		"test": {"lines": [{"speaker": "도서부원", "text": "첫 대사"}, {"speaker": "도서부원", "text": "마지막 대사"}], "on_complete": [
			{"type": "set_flag", "parameters": {"key": "library_access", "value": true}},
			{"type": "count", "parameters": {}},
			{"type": "notify", "parameters": {"text": "도서관 출입 등록 완료"}}
		]}
	}}

func _write(name: String, data: Variant, raw: bool = false) -> String:
	var path := _directory.path_join(name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(data if raw else JSON.stringify(data))
	file.close()
	return path

func _reject(data: Variant, label: String) -> void:
	var result := _repository.load_files([_write("invalid.json", data)])
	check(not result and not _repository.errors().is_empty(), "Rejects " + label)
	check(_repository.get_dialogue(&"test") != null, "Failed reload preserves catalog: " + label)

func _test_repository() -> void:
	_registry = DialogueEffectRegistry.new()
	check(_registry.register_handler(&"set_flag", SetFlagDialogueEffect.new(_state)), "Register flag handler")
	var notify := NotifyDialogueEffect.new()
	notify.notification_requested.connect(func(message: String) -> void: _notifications.append(message))
	_registry.register_handler(&"notify", notify)
	_registry.register_handler(&"count", _counter)
	check(not _registry.register_handler(&"count", CountingEffect.new()), "Reject duplicate effect registration")
	_registry.seal()
	check(not _registry.register_handler(&"late", CountingEffect.new()), "Registry cannot change after sealing")
	_repository = DialogueRepository.new(_registry)
	var fresh_runner := DialogueRunner.new(_repository)
	check(fresh_runner.start(&"test") == ERR_UNCONFIGURED and not fresh_runner.is_busy(), "An unloaded catalog cannot start or lock a session")
	check(not _repository.load_files([_write("initial_bad.json", {"schema_version": 1, "dialogues": {"test": {"on_complete": []}}})]), "Reject invalid data on the first load")
	check(fresh_runner.start(&"test") == ERR_UNCONFIGURED and not fresh_runner.is_busy(), "Failed first load leaves runner safely idle")
	var source := _write("valid.json", _valid())
	check(_repository.load_files([source]), "Load schema-versioned dialogue with an injected custom effect")
	check(_counter.calls == 0 and not _state.has_flag(&"library_access"), "Validation never applies effects")
	var first := _repository.get_dialogue(&"test")
	first.lines[0].text = "mutated"
	first.on_complete[0].parameters.key = "wrong"
	var second := _repository.get_dialogue(&"test")
	check(second.lines[0].text == "첫 대사" and second.on_complete[0].parameters.key == "library_access", "Retrieved definitions do not mutate the stored catalog")
	check(_repository.get_dialogue(&"missing") == null, "Unknown dialogue returns no definition")
	_reject([], "non-object root")
	_reject({"dialogues": _valid().dialogues}, "missing schema version")
	_reject({"schema_version": 2, "dialogues": _valid().dialogues}, "unsupported schema version")
	_reject({"schema_version": "1", "dialogues": _valid().dialogues}, "string schema version")
	_reject({"schema_version": 1, "dialogues": {}}, "empty catalog")
	_reject({"schema_version": 1, "dialogues": {"": {"lines": []}}}, "empty dialogue ID")
	for lines in [null, [], "invalid", {}, [null], ["text"], [{"speaker": 1, "text": "text"}], [{"speaker": "name", "text": "  "}], [{"speaker": "name", "text": "text", "typo": true}]]:
		var data := _valid()
		data.dialogues.test.lines = lines
		_reject(data, "invalid lines " + str(lines))
	var missing_lines := _valid()
	missing_lines.dialogues.test.erase("lines")
	_reject(missing_lines, "missing lines even when completion rewards exist")
	var unknown_field := _valid()
	unknown_field.dialogues.test.grant_flag = "legacy"
	_reject(unknown_field, "legacy/unknown dialogue field")
	for effect in [null, {"type": "unsupported", "parameters": {}}, {"type": "set_flag", "parameters": {"key": "x", "value": 1}}, {"type": "notify", "parameters": {"text": ""}}, {"type": "count", "parameters": {}, "typo": true}]:
		var data := _valid()
		data.dialogues.test.on_complete = [effect]
		_reject(data, "invalid completion effect " + str(effect))
	var invalid_effect_array := _valid()
	invalid_effect_array.dialogues.test.on_complete = {}
	_reject(invalid_effect_array, "non-array completion effects")
	check(not _repository.load_files([_write("syntax.json", "{broken", true)]), "Reject invalid JSON syntax")
	check(_repository.errors()[0].contains("syntax.json:"), "Syntax diagnostic includes source and line")
	check(not _repository.load_files([_directory.path_join("missing.json")]), "Reject missing file without replacing catalog")
	check(not _repository.load_files([]), "Reject empty source list")
	check(not _repository.load_files([source, source]), "Reject duplicate dialogue IDs across files")
	var extra := _valid()
	extra.dialogues["second"] = extra.dialogues.test
	extra.dialogues.erase("test")
	check(_repository.load_files([source, _write("extra.json", extra)]) and _repository.get_dialogue(&"second") != null, "Merge multiple source files")
	check(_repository.errors().is_empty(), "Successful reload clears old errors")
	check(_counter.calls == 0 and not _state.has_flag(&"library_access"), "All rejected data leaves rewards untouched")

func _test_runner() -> void:
	var runner := DialogueRunner.new(_repository)
	check(not runner.advance() and not runner.cancel(), "Idle advance/cancel are harmless")
	check(runner.start(&"missing") == ERR_DOES_NOT_EXIST and not runner.is_busy(), "Unknown ID cannot create a session")
	runner.started.connect(func(id: StringName) -> void:
		_events.append("start:" + id)
		_reentrant_results.append(runner.start(&"test"))
		check(not runner.cancel() and not runner.advance(), "Reject mutation from a started signal callback")
	)
	runner.line_changed.connect(func(line: DialogueLine, index: int, _total: int) -> void:
		_events.append("line:%d:%s" % [index, line.text])
		line.text = "consumer mutation"
	)
	runner.finished.connect(func(id: StringName, reason: DialogueRunner.EndReason, effects: Array[DialogueEffect]) -> void:
		_finish_count += 1
		_events.append("finish:%s:%d" % [id, reason])
		_reentrant_results.append(runner.start(&"test"))
		check(not runner.advance() and not runner.cancel(), "Reject mutation from a finished signal callback")
		if reason == DialogueRunner.EndReason.COMPLETED:
			_registry.execute(effects)
		else:
			check(effects.is_empty(), "Cancelled session emits no completion effects")
	)
	check(runner.start(&"test") == OK, "Start a valid session without any game scene")
	check(runner.start(&"second") == ERR_BUSY and runner.active_id() == &"test", "Second start cannot overwrite active dialogue")
	check(_events.slice(0, 2) == ["start:test", "line:0:첫 대사"], "Start signal precedes the first line")
	check(runner.advance() and _events.back() == "line:1:마지막 대사", "Advance emits the next line")
	check(runner.cancel() and not runner.is_busy(), "Cancel clears the session")
	check(_counter.calls == 0 and not _state.has_flag(&"library_access"), "Cancel never grants completion effects")
	check(not runner.cancel() and _finish_count == 1, "Repeated cancel does not emit completion twice")
	runner.start(&"test")
	# Reload a catalog while a session runs: the session owns an isolated snapshot.
	var changed := _valid()
	changed.dialogues.test.lines[1].text = "replacement"
	_repository.load_files([_write("replacement.json", changed)])
	runner.advance()
	check(_events.back() == "line:1:마지막 대사", "Live catalog reload cannot alter an active session")
	runner.advance()
	check(not runner.is_busy() and _counter.calls == 1 and _state.has_flag(&"library_access"), "Completing the last line executes effects once")
	check(_notifications == ["도서관 출입 등록 완료"], "Completion message comes from data, not a building-specific string")
	check(not runner.advance() and not runner.cancel() and _counter.calls == 1, "Repeated input after completion cannot duplicate rewards")
	check(_reentrant_results.all(func(value: int) -> bool: return value == ERR_BUSY), "Reentrant starts are rejected during every signal dispatch")
	runner.start(&"test")
	runner.advance()
	check(_events.back() == "line:1:replacement", "Next session sees the new catalog")
	runner.cancel()
	var bad_batch: Array[DialogueEffect] = [DialogueEffect.new(&"count"), DialogueEffect.new(&"unsupported")]
	check(not _registry.execute(bad_batch) and _counter.calls == 1, "Effect batch validates completely before applying any item")
	# Disconnect closures capturing runner to avoid a RefCounted reference cycle in tests.
	for signal_name in [&"started", &"line_changed", &"finished"]:
		for connection in runner.get_signal_connection_list(signal_name):
			runner.disconnect(signal_name, connection.callable)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)
	await frames(1)

func _test_game_integration() -> void:
	_game = load("res://scenes/main.tscn").instantiate()
	root.add_child(_game)
	await frames(2)
	var player: SchoolPlayer = _game.ingame.get_player()
	var controller: DialogueController = _game.dialogue
	var view: DialogueView = _game.ui.get_dialogue_view()
	var zone: Node = _game.ingame.current_zone
	check(controller.start(&"missing") == ERR_DOES_NOT_EXIST and not player.is_control_locked() and not view.is_open(), "Unknown ID does not lock gameplay or display an empty panel")
	zone.process_mode = Node.PROCESS_MODE_INHERIT
	var external_input := player.acquire_control_lock()
	var external_pause: int = _game.pause_locks.acquire(zone)
	controller.start(&"notice")
	check(view.is_open() and zone.process_mode == Node.PROCESS_MODE_DISABLED, "Starting dialogue opens its independent view and suspends the zone")
	check(controller.start(&"minjae") == ERR_BUSY and view.displayed_speaker() == "학교 게시판", "Busy controller keeps the current view and session")
	await key(KEY_ESCAPE)
	check(not controller.is_busy() and not view.is_open() and not paused, "Escape closes the dialogue without leaking into pause")
	check(player.is_control_locked() and zone.process_mode == Node.PROCESS_MODE_DISABLED, "Dialogue releases only its locks, preserving external locks")
	player.release_control_lock(external_input)
	_game.pause_locks.release(external_pause)
	check(not player.is_control_locked() and zone.process_mode == Node.PROCESS_MODE_INHERIT, "Final lock release restores the exact previous process mode")
	# Locks acquired AFTER dialogue starts must also survive its cancellation.
	controller.start(&"notice")
	external_input = player.acquire_control_lock()
	external_pause = _game.pause_locks.acquire(zone)
	controller.cancel()
	check(player.is_control_locked() and zone.process_mode == Node.PROCESS_MODE_DISABLED, "Later cutscene locks also survive dialogue cancellation")
	player.release_control_lock(external_input)
	_game.pause_locks.release(external_pause)
	player.release_control_lock(external_input)
	_game.pause_locks.release(external_pause)
	check(not player.is_control_locked() and zone.process_mode == Node.PROCESS_MODE_INHERIT, "Repeated lock release is harmless")
	controller.start(&"seoyun")
	check(_game.ingame.load_zone("building", "Entrance"), "Zone transition can cancel an active session")
	await frames(2)
	check(not controller.is_busy() and not view.is_open() and not _game.session_state.has_flag(&"building_access"), "Scene transition cancels without granting rewards")
	check(not player.is_control_locked() and _game.ingame.current_zone.process_mode == Node.PROCESS_MODE_PAUSABLE, "New zone never inherits the old dialogue lock")
	# A single E confirming a one-line dialogue must not reopen the world target.
	player.position = Vector2(410, 415)
	player.facing = Vector2.UP
	await frames(2)
	await key(KEY_E)
	check(controller.is_busy() and view.displayed_speaker() == "교실 시간표", "World E starts dialogue without advancing its first line")
	await key(KEY_E)
	check(not controller.is_busy() and not view.is_open(), "Closing E is consumed and cannot immediately reopen the target")
	paused = true
	check(controller.start(&"notice") == ERR_BUSY and not player.is_control_locked(), "Paused gameplay rejects new dialogue")
	paused = false
	controller.start(&"notice")
	var old_mode: int = Node.PROCESS_MODE_PAUSABLE
	_game.remove_child(controller)
	check(not player.is_control_locked() and not view.is_open() and _game.ingame.current_zone.process_mode == old_mode, "Removing the controller releases view and gameplay locks")
	controller.free()
	_game.queue_free()
	await frames(2)
	# Weak references allow cleanup even if a suspended target has already been freed.
	var locks := NodePauseLocks.new()
	var target := Node.new()
	root.add_child(target)
	var token := locks.acquire(target)
	target.free()
	locks.release(token)
	check(true, "Freed pause targets can be released safely")

func run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("Dialogue tests timed out.")
		quit(1)
	)
	_directory = OS.get_environment("TMPDIR").path_join("gd_dialogue_tests_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_directory)
	_test_repository()
	_test_runner()
	await _test_game_integration()
	for file in DirAccess.get_files_at(_directory):
		DirAccess.remove_absolute(_directory.path_join(file))
	DirAccess.remove_absolute(_directory)
	print("DIALOGUE TESTS: %d checks, %d failure(s)" % [checks, failures])
	quit(1 if failures else 0)
