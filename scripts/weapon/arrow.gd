extends RigidBody3D
class_name Arrow

@export_group("Physique")
@export var mass_override: float = 0.2        
@export var gravity_mult: float = 1.0          
@export var linear_damp_override: float = 0.0   
@export var align_to_velocity: bool = true     

@export_group("Gameplay")
@export var life_time: float = 4.0            

var _launched := false

func _ready() -> void:
	mass = mass_override
	gravity_scale = gravity_mult
	linear_damp = linear_damp_override
	contact_monitor = true
	set_physics_process(true)              
	if life_time > 0.0:
		_start_ttl_timer(life_time)

func launch(dir_world: Vector3, speed: float) -> void:
	_launched = true
	linear_velocity = dir_world.normalized() * speed
	_face_velocity()

func _physics_process(_dt: float) -> void:
	if align_to_velocity:
		_face_velocity()

func _face_velocity() -> void:
	if not align_to_velocity:
		return
	var v := linear_velocity
	if v.length_squared() > 0.01:
		var from := global_transform.origin
		var xf := global_transform
		xf = xf.looking_at(from + v.normalized(), Vector3.UP)
		global_transform = xf

func _start_ttl_timer(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if is_inside_tree():
		queue_free()

func _on_body_entered(_body: Node) -> void:
	if _launched:
		_launched = false
		linear_velocity = Vector3.ZERO
		sleeping = true
