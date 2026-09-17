class_name DialogueView
extends CanvasLayer

signal advance_requested
signal cancel_requested

@onready var _root: Control = $Root
@onready var _speaker: Label = %Speaker
@onready var _body: Label = %Body
@onready var _hint: Label = %Hint
@onready var _scroll: ScrollContainer = %Scroll

func _ready() -> void:
	close()

func present(line: DialogueLine, index: int, total: int) -> void:
	_speaker.text = line.speaker
	_body.text = line.text
	_hint.text = "%d / %d    ·    E / Space / Enter / 패드 A 다음    ·    Esc 닫기" % [index + 1, total]
	_scroll.scroll_vertical = 0
	_root.show()

func close() -> void:
	_root.hide()
	_speaker.text = ""
	_body.text = ""

func is_open() -> bool:
	return _root.visible

func displayed_speaker() -> String:
	return _speaker.text

func displayed_text() -> String:
	return _body.text

func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		cancel_requested.emit()
	elif event.is_action_pressed("advance") or event.is_action_pressed("interact"):
		# Consume BEFORE emitting: closing the view must not leak E into the world.
		get_viewport().set_input_as_handled()
		advance_requested.emit()
