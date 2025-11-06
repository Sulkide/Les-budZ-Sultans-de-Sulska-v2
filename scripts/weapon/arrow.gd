class_name Arrow
extends Area3D

@export var mass: float = 0.25
@export var _gravity: Vector3 = Vector3.DOWN

var _launched = false
var _velocity: Vector3


func _process(delta: float) -> void:
	if _launched:
		_velocity += _gravity * mass
		position += _velocity * delta
		rotation.angle_to(_velocity)


func launch(pos: Vector3, initial_velocity: Vector3):
	global_position = pos
	_launched = true
	_velocity = initial_velocity
