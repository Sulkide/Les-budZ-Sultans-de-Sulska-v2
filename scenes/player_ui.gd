class_name PlayerUI
extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var points_display: Label = $PointsDisplay


func init_health_ui(max_health: int) -> void:
	health_bar.max_value = max_health
	health_bar.value = max_health


func update_health_ui(health: int) -> void:
	health_bar.value = health


func update_points_display(points: int) -> void:
	points_display.text = "Points : " + str(points)
