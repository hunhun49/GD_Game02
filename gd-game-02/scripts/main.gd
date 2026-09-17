extends Node

@export var dialogue_sources: PackedStringArray = ["res://data/dialogues.json"]

@onready var ingame: InGame = $InGame
@onready var ui: GameUI = $UI
@onready var dialogue: DialogueController = $DialogueController
@onready var coordinator: GameCoordinator = $GameCoordinator

var session_state := SessionState.new()
var pause_locks := NodePauseLocks.new()

func _ready() -> void:
	coordinator.configure(ingame, ui, dialogue, session_state, pause_locks, dialogue_sources)
