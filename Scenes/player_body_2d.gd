extends CharacterBody3D

@export var max_level_depth: float = 50

@onready var collision: PlayerCollision2D = $PlayerCollision2D


func _check_collision(front: float, back: float) -> bool:
	collision.set_collision_bounds(front, back)
	return move_and_collide(Vector3.ZERO, true) != null


func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_down"):
		print(_check_collision(50, -50))
