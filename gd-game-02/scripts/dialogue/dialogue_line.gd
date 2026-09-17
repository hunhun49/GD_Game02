class_name DialogueLine
extends RefCounted

var speaker: String
var text: String

func _init(p_speaker: String = "", p_text: String = "") -> void:
	speaker = p_speaker
	text = p_text

func copy() -> DialogueLine:
	return DialogueLine.new(speaker, text)
