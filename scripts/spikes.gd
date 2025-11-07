extends Area3D

@export var eject_force: float = 50


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		body.health -= 1
		body.velocity.y = eject_force
