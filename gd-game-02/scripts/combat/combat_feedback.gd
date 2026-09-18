class_name CombatFeedback
extends Node2D

var _hit_remaining: float = 0.0
var _result_remaining: float = 0.0
var _result: HitResolver.Outcome = HitResolver.Outcome.HIT
@export var sound_enabled: bool = true
@export var compact_labels: bool = false
var _audio: AudioStreamPlayer
var _tones: Array[AudioStreamWAV] = []
var _health: HealthComponent
var _combat: CombatComponent

func _ready() -> void:
	z_index = 5 # World props must not obscure combat cues.
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -15
	_audio.max_polyphony = 3
	add_child(_audio)
	for frequency in [150.0, 380.0, 1050.0, 520.0, 1250.0, 780.0]:
		_tones.append(_tone(frequency))
	_health = get_parent().get_node("Health")
	_health.damaged.connect(_on_damaged)
	_combat = get_parent().get_node_or_null("Combat") as CombatComponent
	if _combat != null:
		_combat.resolved.connect(_on_resolved)
		_combat.encounter_reset.connect(func() -> void:
			_hit_remaining = 0
			_result_remaining = 0
			_audio.stop()
		)

func _on_damaged(_event: DamageEvent, _applied: float) -> void:
	_hit_remaining = 0.2

func _on_resolved(outcome: HitResolver.Outcome) -> void:
	if sound_enabled:
		_audio.stream = _tones[int(outcome)]
		_audio.play()
	_result = outcome
	_result_remaining = 0.25

func _process(delta: float) -> void:
	_hit_remaining = maxf(0, _hit_remaining - delta)
	_result_remaining = maxf(0, _result_remaining - delta)
	queue_redraw()

func _draw() -> void:
	if _health == null or _health.maximum() <= 0:
		return
	draw_rect(Rect2(-24, -76, 48, 5), Color("273744"))
	draw_rect(Rect2(-24, -76, 48 * _health.current() / _health.maximum(), 5), Color("68d8cf"))
	if _combat != null:
		var posture := _combat.posture()
		if posture != null:
			draw_rect(Rect2(-24, -68, 48, 4), Color("273744"))
			draw_rect(Rect2(-24, -68, 48 * posture.current / posture.maximum, 4), Color("f8d279"))
			if posture.is_broken():
				_label("좌클릭 제압" if _combat.finishable else "균형 붕괴", Color("f8d279"))
		var guard := _combat.guard()
		if guard != null and guard.holding:
			var angle := guard.direction.angle()
			draw_arc(Vector2.ZERO, 30, angle - 1.1, angle + 1.1, 20, Color("68d8cf"), 3)
		if _combat.phase in [CombatComponent.Phase.WINDUP, CombatComponent.Phase.ACTIVE]:
			var angle := _combat.attack_direction.angle()
			var kind := _combat.current_attack_kind()
			var color: Color = [Color("f8d279"), Color("63bdff"), Color("ff6d79"), Color("c38aff")][kind]
			var radius := _combat.telegraph_reach()
			var half_arc := _combat.telegraph_arc() * 0.5
			var fan := PackedVector2Array([Vector2.ZERO])
			for i in range(21):
				fan.append(Vector2.from_angle(angle - half_arc + half_arc * 2 * i / 20.0) * radius)
			draw_colored_polygon(fan, Color(color, 0.18))
			draw_line(Vector2.ZERO, _combat.attack_direction * radius, color, 2)
			draw_arc(Vector2.ZERO, radius, angle - half_arc, angle + half_arc, 20, color, 5 if _combat.phase == CombatComponent.Phase.ACTIVE else 1)
			if kind != AttackDefinition.Kind.NORMAL:
				var captions := ["", "□ 가드 ×3 · 튕김", "↑ Shift 돌진", "◇ Q 상쇄"]
				_label("◇ 보라색 공격" if kind == AttackDefinition.Kind.PURPLE and _combat.team == 1 else captions[kind], color)
		if _combat.uses_pointer():
			var aim := _combat.aim_direction()
			var tip := aim * 42
			draw_line(aim * 30, tip, Color("f4f7ff"), 2)
			draw_line(tip, tip - aim.rotated(0.6) * 8, Color("f4f7ff"), 2)
			draw_line(tip, tip - aim.rotated(-0.6) * 8, Color("f4f7ff"), 2)
		if _combat.dodge() != null and _combat.dodge().moving:
			draw_line(Vector2.ZERO, -_combat.dodge().direction * 45, Color("a7e5ff"), 5)
	if _hit_remaining > 0:
		draw_circle(Vector2(0, -26), 22, Color(1.0, 0.4, 0.4, 0.3))
	if _result_remaining > 0 and _result != HitResolver.Outcome.HIT:
		var perfect := _result in [HitResolver.Outcome.DEFLECT, HitResolver.Outcome.DASH_PARRY, HitResolver.Outcome.CLASH]
		var color := Color("c38aff") if _result == HitResolver.Outcome.CLASH else (Color("f8d279") if perfect else Color("68d8cf"))
		draw_arc(Vector2(0, -25), 34, 0, TAU, 24, color, 4 if perfect else 1)
		if _combat == null or (not _combat.is_staggered() and not (_combat.phase in [CombatComponent.Phase.WINDUP, CombatComponent.Phase.ACTIVE] and _combat.is_dangerous_attack())):
			_label(["피격", "가드", "튕김!", "회피", "돌진 패링!", "상쇄!"][_result], color)
	if _health.current() <= 0:
		draw_line(Vector2(-10, -45), Vector2(10, -25), Color("cf8c91"), 4)
		draw_line(Vector2(10, -45), Vector2(-10, -25), Color("cf8c91"), 4)

# Small original procedural cues: low hit, muted guard, bright deflect.
func _tone(frequency: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var rate := 16000
	data.resize(2400)
	for i in range(data.size()):
		var t := float(i) / rate
		var envelope := exp(-t * 32.0) * minf(1, t * 1500.0)
		var wave := (sin(TAU * frequency * t) + 0.35 * sin(TAU * frequency * 2.7 * t)) * envelope
		data[i] = int(clampf(128.0 + wave * 75.0, 0, 255))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

func _label(text: String, color: Color) -> void:
	var at := Vector2(28, -32)
	if compact_labels:
		text = {"□ 가드 ×3 · 튕김": "□", "↑ Shift 돌진": "↑", "◇ Q 상쇄": "◇", "상쇄!": "상쇄", "튕김!": "튕김", "돌진 패링!": "패링", "좌클릭 제압": "제압"}.get(text, text)
		at = Vector2(-ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * 0.5, -85)
	draw_string_outline(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color("182c39"))
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
