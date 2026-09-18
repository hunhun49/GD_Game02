class_name InGame
extends Node2D

signal ailments_changed(text: String)

signal posture_changed(current: float, maximum: float)
signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal clock_changed(text: String)
signal needs_changed(hunger: float, thirst: float, fatigue: float)
signal zone_changed(zone: SchoolZone)
signal location_changed(title: String)
signal movement_mode_changed(direction_count: int)
signal interaction_prompt_changed(display_name: String, action: String)
signal status_changed(message: String)
signal dialogue_requested(id: StringName)

const ZONES := {
	"combat_arena": preload("res://scenes/zones/combat_arena.tscn"),
	"courtyard": preload("res://scenes/zones/courtyard.tscn"),
	"building": preload("res://scenes/zones/building.tscn"),
}

# F6 runs the world alone; the composed game initializes it after signal wiring.
@export var auto_start: bool = true
@export var initial_zone: String = "courtyard"
@export var initial_spawn: String = "Entrance"

@onready var _player: SchoolPlayer = $Player
@onready var _detector: InteractionDetector = $Player/InteractionDetector

var current_zone: SchoolZone
var zone_id: String = ""
var checkpoint: Vector2
var transitioning: bool = false
var _session_state := SessionState.new()
var _before_zone_change: Callable
var _transition_token: int = 0
var _interaction_context: InteractionContext
var _displayed_minute: int = -1

func _ready() -> void:
	_detector.focus_changed.connect(_on_focus_changed)
	_player.status_effects().changed.connect(_on_ailments_changed)
	_player.get_node("Needs").changed.connect(_on_needs_changed)
	_player.get_node("Health").changed.connect(func(current: float, maximum: float) -> void: health_changed.emit(current, maximum))
	_player.get_node("Health").incapacitated.connect(_on_player_incapacitated)
	_player.get_node("Stamina").changed.connect(func(current: float, maximum: float) -> void: stamina_changed.emit(current, maximum))
	var combat := _player.get_node_or_null("Combat") as CombatComponent
	if combat != null:
		combat.hit_landed.connect(_on_player_hit)
		combat.resolved.connect(_on_player_defense)
		combat.finished_target.connect(func(target_name: String) -> void: status_changed.emit(target_name + " 제압 성공 · E로 다시 훈련"))
		if combat.posture() != null:
			combat.posture().changed.connect(func(current: float, maximum: float) -> void: posture_changed.emit(current, maximum))
	var input := _player.controller as PlayerController
	input.interact_requested.connect(_request_interaction)
	input.cycle_target_requested.connect(_detector.cycle)
	input.respawn_requested.connect(_request_respawn)
	input.attack_requested.connect(_request_attack)
	input.dodge_requested.connect(_request_dodge)
	input.purple_requested.connect(_request_purple)
	input.guard_requested.connect(_request_guard)
	_player.movement.mode_changed.connect(func(count: int) -> void: movement_mode_changed.emit(count))
	_configure_characters_and_interactions()
	if auto_start:
		start()

func configure(state: SessionState, before_zone_change: Callable) -> void:
	_session_state = state
	_before_zone_change = before_zone_change
	_configure_characters_and_interactions()

func _configure_characters_and_interactions() -> void:
	_session_state.mark_in_use()
	_player.bind_session(_session_state)
	var combat := _player.get_node_or_null("Combat") as CombatComponent
	if combat != null:
		combat.set_scope(self)
	_displayed_minute = -1
	_interaction_context = InteractionContext.new(_player, _session_state)
	_interaction_context.dialogue_requested.connect(func(id: StringName) -> void: dialogue_requested.emit(id))
	_interaction_context.travel_requested.connect(_request_travel)
	_interaction_context.checkpoint_requested.connect(_register_checkpoint)
	_interaction_context.notification_requested.connect(func(message: String) -> void: status_changed.emit(message))
	_detector.configure(_interaction_context)
	if is_instance_valid(current_zone):
		_bind_characters(current_zone)

func clear_transition_guard() -> void:
	_before_zone_change = Callable()

func start() -> bool:
	movement_mode_changed.emit(movement_direction_count())
	_publish_life_state()
	return load_zone(initial_zone, initial_spawn)

func get_player() -> SchoolPlayer:
	return _player

func get_detector() -> InteractionDetector:
	return _detector

func movement_direction_count() -> int:
	return 8 if _player.movement.mode == MovementComponent.MovementMode.EIGHT_DIRECTIONS else 4

func can_pause() -> bool:
	return not transitioning and not _player.has_pause_locks()

func _publish_life_state() -> void:
	var health: HealthComponent = _player.get_node("Health")
	var stamina: StaminaComponent = _player.get_node("Stamina")
	health_changed.emit(health.current(), health.maximum())
	var combat := _player.get_node_or_null("Combat") as CombatComponent
	if combat != null and combat.posture() != null:
		posture_changed.emit(combat.posture().current, combat.posture().maximum)
	stamina_changed.emit(stamina.current(), stamina.maximum())
	var minute := int(floor(_session_state.clock.total_minutes()))
	if minute != _displayed_minute:
		_displayed_minute = minute
		clock_changed.emit(_session_state.clock.display_text())
	var values: Dictionary = _player.get_node("Needs").values()
	if not values.is_empty():
		needs_changed.emit(values.hunger, values.thirst, values.fatigue)

func _on_needs_changed(hunger: float, thirst: float, fatigue: float) -> void:
	needs_changed.emit(hunger, thirst, fatigue)
	_publish_clock()

func _publish_clock() -> void:
	var minute := int(floor(_session_state.clock.total_minutes()))
	if minute != _displayed_minute:
		_displayed_minute = minute
		clock_changed.emit(_session_state.clock.display_text())

func _physics_process(delta: float) -> void:
	if not transitioning and is_instance_valid(current_zone):
		_session_state.clock.advance_real_seconds(delta)
		_publish_clock()
	if is_instance_valid(current_zone) and not _player.is_control_locked() and not Rect2(Vector2.ZERO, current_zone.bounds).grow(32).has_point(_player.position):
		respawn()

func _request_interaction() -> void:
	if not transitioning:
		_detector.interact()

func load_zone(next_zone: String, spawn_name: String) -> bool:
	if _training_active():
		status_changed.emit("훈련 중에는 구역을 이동할 수 없습니다. R로 훈련을 종료하세요.")
		_end_transition()
		return false
	if not ZONES.has(next_zone):
		push_error("Unknown zone: " + next_zone)
		_end_transition()
		return false
	var next: SchoolZone = ZONES[next_zone].instantiate()
	var spawn := next.get_node_or_null("Spawns/" + spawn_name) as Marker2D
	if spawn == null:
		push_error("Unknown spawn: " + spawn_name)
		next.free()
		_end_transition()
		return false
	if not _valid_character_ids(next):
		next.free()
		_end_transition()
		return false
	# Integration may reject a reentrant transition or close a dialogue first.
	# The world knows neither dialogue objects nor UI scenes.
	if _before_zone_change.is_valid() and not _before_zone_change.call():
		next.free()
		_end_transition()
		return false
	_detector.clear()
	if is_instance_valid(current_zone):
		remove_child(current_zone)
		current_zone.queue_free()
	current_zone = next
	zone_id = next_zone
	_bind_characters(current_zone)
	add_child(current_zone)
	move_child(current_zone, 0)
	_detector.set_scope(current_zone)
	checkpoint = spawn.global_position
	_player.facing = Vector2.UP if next_zone in ["building", "combat_arena"] else Vector2.DOWN
	var camera: Camera2D = $Player/Camera2D
	camera.limit_right = int(current_zone.bounds.x)
	camera.limit_bottom = int(current_zone.bounds.y)
	respawn()
	_end_transition()
	zone_changed.emit(current_zone)
	location_changed.emit("해솔고등학교  /  " + current_zone.zone_title)
	if zone_id == "combat_arena":
		status_changed.emit("3명 동시 훈련 · 좌클릭 공격 · 우클릭 가드 · Shift 돌진 · Q 상쇄 · E 전체 초기화")
	elif zone_id == "building":
		status_changed.emit("민재와 대화하고 시간표를 조사해 보세요. 왼쪽 아래 출입문으로 운동장에 돌아갈 수 있습니다.")
	elif _session_state.has_flag(&"building_access"):
		status_changed.emit("본관 출입 가능 · 나무 주변과 운동장을 걸으며 대각선 이동을 시험해 보세요.")
	else:
		status_changed.emit("반장 서윤을 만나 본관 출입 허가를 받아 보세요.")
	if _player.state.current_health <= 0:
		_on_player_incapacitated()
	return true

func _bind_characters(node: Node) -> void:
	if node is SchoolCharacter:
		node.bind_session(_session_state)
		var combat := node.get_node_or_null("Combat") as CombatComponent
		if combat != null:
			combat.set_scope(self)
	for child in node.get_children():
		_bind_characters(child)

func _valid_character_ids(zone: Node) -> bool:
	var ids: Dictionary = {_player.character_id: true}
	var pending: Array[Node] = [zone]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is SchoolCharacter:
			if node.character_id.is_empty() or node.definition == null or ids.has(node.character_id):
				push_error("Missing or duplicate character ID/definition: %s" % node.name)
				return false
			ids[node.character_id] = true
		pending.append_array(node.get_children())
	return true

func _end_transition() -> void:
	_player.release_control_lock(_transition_token)
	_transition_token = 0
	transitioning = false

func _on_focus_changed(target: InteractionComponent) -> void:
	if is_instance_valid(target):
		interaction_prompt_changed.emit(target.target_name(), target.get_prompt(_interaction_context))
	else:
		interaction_prompt_changed.emit("", "")

func _request_travel(destination_zone: String, destination_spawn: String) -> void:
	if transitioning or not _player.can_act(SchoolCharacter.Action.INTERACT):
		return
	transitioning = true
	_transition_token = _player.acquire_control_lock()
	_detector.clear()
	load_zone.call_deferred(destination_zone, destination_spawn)

func _register_checkpoint(at: Vector2) -> void:
	checkpoint = at
	status_changed.emit("체크포인트 등록 완료 · R을 누르면 이곳으로 돌아옵니다.")

func respawn() -> void:
	_reset_combat()
	_player.position = checkpoint
	_player.reset_motion()
	_detector.clear()
	$Player/Camera2D.reset_smoothing()

func _request_dodge() -> void:
	var combat := _player.get_node_or_null("Combat") as CombatComponent
	if not transitioning and combat != null:
		combat.request_dodge()

func _request_purple() -> void:
	var combat := _player.get_node_or_null("Combat") as CombatComponent
	if not transitioning and combat != null:
		combat.request_purple()

func _request_attack() -> void:
	var combat := _player.get_node_or_null("Combat") as CombatComponent
	if not transitioning and combat != null:
		combat.request_attack()

func _on_player_hit(_id: StringName, target_name: String, amount: float) -> void:
	status_changed.emit("%s에게 %.0f 피해 · 우클릭 가드 / 붕괴 시 좌클릭 제압" % [target_name, amount])

func _on_player_incapacitated() -> void:
	_detector.clear()
	status_changed.emit("전투 불능 · R을 누르면 체력을 회복하고 체크포인트로 복귀합니다.")

func _request_respawn() -> void:
	if transitioning:
		return
	if _player.can_act(SchoolCharacter.Action.RECOVER):
		var health: HealthComponent = _player.get_node("Health")
		if not health.revive(health.maximum()):
			return
		_player.get_node("Stamina").restore_full()
		status_changed.emit("체력 회복 완료 · 체크포인트로 복귀했습니다.")
	elif not _player.can_act(SchoolCharacter.Action.MOVE):
		return
	respawn()

func _request_guard(pressed: bool, allow_deflect: bool) -> void:
	var combat := _player.get_node_or_null("Combat") as CombatComponent
	if not transitioning and combat != null:
		if pressed and not allow_deflect:
			if combat.phase == CombatComponent.Phase.READY:
				combat.set_guard(true, false)
		else:
			combat.request_guard(pressed)

func _on_player_defense(outcome: HitResolver.Outcome) -> void:
	if outcome == HitResolver.Outcome.DEFLECT:
		status_changed.emit("튕겨내기 성공 · 상대 체간 증가! 연속기의 다음 공격을 확인하세요.")
	elif outcome == HitResolver.Outcome.BLOCK:
		status_changed.emit("가드 · 내 체간 부담 증가. 맞기 직전에 우클릭을 새로 누르면 튕겨냅니다.")

	elif outcome == HitResolver.Outcome.DASH_PARRY:
		status_changed.emit("돌진 패링! 상대 체간 증가 · 좌클릭으로 공격을 이어가세요.")
	elif outcome == HitResolver.Outcome.CLASH:
		status_changed.emit("보라색 상쇄! 피해 없이 충돌 · 먼저 회복해 공격을 이어갑니다.")
	elif outcome == HitResolver.Outcome.DODGE:
		status_changed.emit("회피 성공 · 커서를 적에게 돌려 공격을 이어가세요.")

func _training_active() -> bool:
	if not is_instance_valid(current_zone):
		return false
	for node in current_zone.find_children("*", "Node", true, false):
		if node is TrainingController and node.is_training():
			return true
	return false

func _reset_combat() -> void:
	$CombatResolver.clear()
	if _player.status_effects() != null:
		_player.status_effects().clear()
	var combat := _player.get_node_or_null("Combat") as CombatComponent
	if combat != null:
		combat.reset_encounter()
	if is_instance_valid(current_zone):
		for node in current_zone.find_children("*", "Node", true, false):
			if node is TrainingController:
				var effects := (node.get_parent() as SchoolCharacter).status_effects()
				if effects != null:
					effects.clear()
				node.reset_training()

func _on_ailments_changed(statuses: Array[Dictionary]) -> void:
	var labels := PackedStringArray()
	for status in statuses:
		var stack_text := " ×%d" % status.stacks if status.get("stacks", 1) > 1 else ""
		labels.append("%s%s %.1fs" % [status.name, stack_text, status.remaining])
	var rows := PackedStringArray()
	for start in range(0, labels.size(), 5):
		rows.append("  ·  ".join(labels.slice(start, start + 5)))
	ailments_changed.emit("\n".join(rows))
