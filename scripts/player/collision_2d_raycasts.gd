class_name PlayerCollision2DRaycasts
extends Node3D

@export var front_raycasts_container: Node3D
@export var back_raycasts_container: Node3D


func setup_raycasts(depth: float) -> void:
	for raycast: RayCast3D in front_raycasts_container.get_children():
		raycast.target_position = Vector3.BACK * depth
	for raycast: RayCast3D in back_raycasts_container.get_children():
		raycast.target_position = Vector3.FORWARD * depth


func get_max_depth(z_position: float, front: bool, depth: float) -> float:
	var max_depth: float = z_position + depth * (1 if front else -1)
	var container: Node3D = front_raycasts_container if front else back_raycasts_container
	
	for raycast: RayCast3D in container.get_children():
		if raycast.is_colliding():
			if front:
				max_depth = minf(max_depth, raycast.get_collision_point().z)
			else:
				max_depth = maxf(max_depth, raycast.get_collision_point().z)
	
	return abs(max_depth - z_position)
