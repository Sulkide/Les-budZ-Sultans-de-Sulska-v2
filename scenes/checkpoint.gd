class_name Checkpoint
extends Area3D


@export var untouched_color: Color = Color.WHITE
@export var touched_color: Color = Color.YELLOW

@onready var sprite: Sprite3D = $Sprite3D


func touch_checkpoint(player: Player):
	sprite.modulate = touched_color
	player.set_checkpoint(self)


func untouch_checkpoint() -> void:
	sprite.modulate = untouched_color


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		touch_checkpoint(body)
