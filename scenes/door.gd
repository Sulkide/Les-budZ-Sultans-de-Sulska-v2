extends Area3D

@export var next_level: PackedScene


func _go_to_next_level() -> void:
	if next_level:
		get_tree().change_scene_to_packed(next_level)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		if next_level:
			call_deferred("_go_to_next_level")
