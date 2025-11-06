class_name Enemy
extends CharacterBody3D

@export_group("Parameters")
@export var move_speed: float
## Distance from enemy position at which ledge is checked. Set to -1 to disable checks.
@export var ledge_check_distance: float
@export var jump_strength: float
## Chance for the enemy to jump each time its jump timer ticks.
@export_range(0, 1) var jump_chance: float
@export var gravity: float = 200

var _direction: Vector3 = Vector3.RIGHT


func _physics_process(delta: float) -> void:
	var move: Vector3 = _direction * move_speed * delta
	
	var collision: KinematicCollision3D = move_and_collide(move)
	
	if collision or (is_on_floor() and _check_for_ledge()):
		_direction *= -1
	
	velocity.y -= gravity * delta
	
	move_and_slide()


## Returns true if a ledge is detected.
func _check_for_ledge() -> bool:
	if ledge_check_distance == -1: # Disable ledge checking if -1
		return false
	
	var space_state = get_world_3d().direct_space_state

	var origin = global_position + _direction * ledge_check_distance
	var end = origin + Vector3.DOWN
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true

	var result = space_state.intersect_ray(query)
	
	return result.is_empty()


func _jump() -> void:
	velocity.y = jump_strength


func _on_try_jump() -> void:
	if randf() <= jump_chance and is_on_floor():
		_jump()


func _die() -> void:
	queue_free()


func _on_stomp_area_body_entered(body: Node3D) -> void:
	if body is Player:
		if body.velocity.y <= 0:
			_die()
