class_name PlayerUI
extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar


func init_health_ui(max_health: int) -> void:
	health_bar.max_value = max_health
	health_bar.value = max_health


func update_health_ui(health: int) -> void:
	health_bar.value = health
