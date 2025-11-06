class_name PlayerCollision2D
extends CollisionShape3D

@export var points_per_face: int = 14


func set_collision_bounds(front: float, back: float) -> void:
	if shape is ConvexPolygonShape3D:
		for i in range(points_per_face):
			shape.points[i].z = front
			shape.points[i + points_per_face].z = back
