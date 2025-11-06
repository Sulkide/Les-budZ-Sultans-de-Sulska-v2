class_name WeaponBow
extends Node3D

@export var arrow_scene: PackedScene

@onready var bow: Node3D = $Sprite3D


func shoot() -> void:
	var arrow: Arrow = arrow_scene.instantiate()
	get_tree().root.add_child(arrow)
	arrow.launch(bow.global_position, Vector3.UP)


func angle_bow_2d() -> void:
	var direction: Vector2 = Input.get_vector("target_right", "target_left", "target_up", "target_down")
	if direction.length() > 0.1:
		look_at(global_position + Vector3(direction.x, direction.y, 0))
	bow.rotation_degrees.x = 0


func angle_bow_3d() -> void:
	var direction: Vector2 = Input.get_vector("target_right", "target_left", "target_up", "target_down")
	if direction.length() > 0.1:
		look_at(global_position + Vector3(direction.x, 0, -direction.y))
	bow.rotation_degrees.x = 90
