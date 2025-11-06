
extends AnimatableBody3D

@export_category("size platforme")
@export var block_size: Vector3 = Vector3.ONE:
	set(value):
		block_size = value
		if is_node_ready():
			_update_size()

@export_category("Step")
@export var a := Vector3()
@export var b := Vector3()

@export_category("movement parametre")
@export var time: float = 2.0
@export var pause: float = 0.7
@export var ease_type: Tween.TransitionType = Tween.TRANS_SINE


	
func _update_size() -> void:
	$CollisionShape3D.shape.size = block_size
	$MeshInstance3D.mesh.size = block_size
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_size()
	if a == Vector3.ZERO:
		a = position
	move()


func move():
	var move_tween = create_tween()
	move_tween.tween_property(self, "position", b, time).set_trans(ease_type).set_delay(pause)
	move_tween.tween_property(self, "position", a, time).set_trans(ease_type).set_delay(pause)
	await get_tree().create_timer(2 * time + 2 * pause).timeout
	move()
