@tool
extends StaticBody3D

@export var block_size: Vector3 = Vector3.ONE:
	set(value):
		block_size = value
		if is_node_ready():
			_update_size()

func _ready() -> void:
	_update_size()

func _update_size() -> void:
	$CollisionShape3D.shape.size = block_size
	$MeshInstance3D.mesh.size = block_size
