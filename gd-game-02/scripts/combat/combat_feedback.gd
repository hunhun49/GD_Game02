class_name CombatFeedback
extends Node2D

var _attack_remaining: float = 0.0
var _hit_remaining: float = 0.0
var _direction: Vector2 = Vector2.DOWN
var _health: HealthComponent

func _ready() -> void:
	_health = get_parent().get_node("Health")
	_health.changed.connect(func(_current: float, _maximum: float) -> void: queue_redraw())
	_health.damaged.connect(_on_damaged)
	var combat := get_parent().get_node_or_null("Combat") as CombatComponent
	if combat != null:
		combat.attack_started.connect(_on_attack)

func _on_attack(direction: Vector2) -> void:
	_direction = direction
	_attack_remaining = 0.15
	queue_redraw()

func _on_damaged(_event: DamageEvent, _applied: float) -> void:
	_hit_remaining = 0.2
	queue_redraw()

func _process(delta: float) -> void:
	_attack_remaining = maxf(0.0, _attack_remaining - delta)
	_hit_remaining = maxf(0.0, _hit_remaining - delta)
	queue_redraw()

func _draw() -> void:
	if _health == null or _health.maximum() <= 0:
		return
	draw_rect(Rect2(-20, -68, 40, 5), Color("273744"))
	draw_rect(Rect2(-20, -68, 40 * _health.current() / _health.maximum(), 5), Color("68d8cf") if _health.current() > 0 else Color("cf8c91"))
	if _attack_remaining > 0:
		var angle := _direction.angle()
		draw_arc(Vector2(0, -18), 34, angle - 0.7, angle + 0.7, 16, Color("f8d279"), 4)
	if _hit_remaining > 0:
		draw_circle(Vector2(0, -26), 22, Color(1.0, 0.4, 0.4, 0.3))
	if _health.current() <= 0:
		draw_line(Vector2(-10, -45), Vector2(10, -25), Color("cf8c91"), 4)
		draw_line(Vector2(10, -45), Vector2(-10, -25), Color("cf8c91"), 4)
