class_name CharacterDefinition
extends Resource

# Authoring data: never mutate this shared resource during play.
@export var display_name: String = "학생"
@export var outfit_color: Color = Color("cf8c91")
@export_range(0.0, 1000.0) var run_speed: float = 220.0
@export_range(1.0, 10000.0) var acceleration: float = 1800.0
@export_range(1.0, 10000.0) var braking: float = 2400.0
@export_range(1.0, 100000.0) var max_health: float = 100.0

@export var needs_profile: NeedsProfile

@export var stamina_profile: StaminaProfile
