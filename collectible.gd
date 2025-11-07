class_name Collectible
extends Area3D

enum Type {
	COIN,
	DIAMOND
}

@export var type: Type = Type.COIN

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		match type:
			Type.COIN:
				body.points += 1
			Type.DIAMOND:
				body.points += 50
			_:
				pass
	queue_free()
