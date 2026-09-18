extends Node

# Only attached to the standalone lab scene; no debug bindings in the main game.
const IDS := ["poison", "burn", "bleed", "stun", "root", "fear", "slow", "heat", "cold"]
const EXAMPLES := {KEY_Z: "silence", KEY_C: "regeneration", KEY_V: "stacking_poison", KEY_B: "haste"}
var _world: InGame
var _label: Label

func _ready() -> void:
	_world = get_parent().get_node("InGame")
	var canvas := CanvasLayer.new()
	canvas.layer = 12
	add_child(canvas)
	_label = Label.new()
	_label.position = Vector2(24, 300)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_outline_color", Color("172b35"))
	_label.add_theme_constant_override("outline_size", 5)
	canvas.add_child(_label)
	_refresh()

func _refresh() -> void:
	_label.text = "상태 이상 실험실 · 숫자 키로 자신에게 부여\n1 독 / 2 화상 / 3 출혈 / 4 스턴 / 5 속박 / 6 공포\n7 슬로우 / 8 더움 / 9 추움 / 0 전체 해제\nF3 해독 / F4 화상 치료 / F5 지혈 (게임 창에 포커스)\nZ 침묵 / C 재생 / V 중첩 독 / B 가속"

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or get_tree().paused:
		return
	var effects := _world.get_player().status_effects()
	var key: int = event.physical_keycode
	if key >= KEY_1 and key <= KEY_9:
		effects.apply_status(load("res://data/status/%s.tres" % IDS[key - KEY_1]), &"status_lab")
	elif EXAMPLES.has(key):
		effects.apply_status(load("res://data/status/%s.tres" % EXAMPLES[key]), &"status_lab")
	elif key == KEY_0:
		effects.clear(&"debug")
	elif key in [KEY_F3, KEY_F4, KEY_F5]:
		effects.cleanse([&"poison", &"burn", &"bleed"][key - KEY_F3])
	else:
		return
	get_viewport().set_input_as_handled()
