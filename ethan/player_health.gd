extends CharacterBody2D

@export var max_health: int = 100
var current_health: int

@onready var health_bar: ProgressBar = $CanvasLayer/HealthBar
var tween: Tween

const COLOR_HIGH := Color(0.2, 1.0, 0.2) # vert
const COLOR_MED := Color(1.0, 0.8, 0.1)  # jaune
const COLOR_LOW := Color(1.0, 0.2, 0.2)  # rouge

func _ready():
	current_health = max_health
	update_health_bar(true)

func take_damage(amount: int):
	current_health = max(current_health - amount, 0)
	update_health_bar()
	if current_health <= 0:
		die()

func heal(amount: int):
	current_health = min(current_health + amount, max_health)
	update_health_bar()

func update_health_bar(immediate: bool = false):
	if not health_bar:
		return

	var ratio := float(current_health) / float(max_health)
	var target_value := ratio * 100.0
	var target_color := get_color_from_health_ratio(ratio)

	if immediate:
		health_bar.value = target_value
	else:
		if tween and tween.is_running():
			tween.kill()
		tween = create_tween()
		tween.tween_property(health_bar, "value", target_value, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var fill_style := health_bar.get_theme_stylebox("fill")
	if fill_style:
		var new_style := fill_style.duplicate() as StyleBoxFlat
		new_style.bg_color = target_color
		new_style.corner_radius_top_left = 10
		new_style.corner_radius_top_right = 10
		new_style.corner_radius_bottom_left = 10
		new_style.corner_radius_bottom_right = 10
		new_style.content_margin_left = 1
		new_style.content_margin_right = 1
		new_style.content_margin_top = 1
		new_style.content_margin_bottom = 1
		health_bar.add_theme_stylebox_override("fill", new_style)

func get_color_from_health_ratio(ratio: float) -> Color:
	if ratio > 0.5:
		return COLOR_MED.lerp(COLOR_HIGH, (ratio - 0.5) * 2.0)
	else:
		return COLOR_LOW.lerp(COLOR_MED, ratio * 2.0)

func die():
	get_tree().change_scene_to_file("res://game over.tscn")
	print("Le joueur est mort ")
	

@warning_ignore("unused_parameter")
func _process(delta):
	if Input.is_action_just_pressed("ui_accept"):
		take_damage(10)
	if Input.is_action_just_pressed("ui_cancel"):
		heal(10)
