class_name Player
extends CharacterBody3D

@export_category("parametre flip")
@export var is3D: bool
@export var timeToFlip: float = 1

@export_category("Mouvement")
@export var SPEED: float = 35.0
@export var ACCELERATION: float = 120.0
@export var FRICTION: float = 140.0

@export var GRAVITY: float = 200.0
@export var FALL_GRAVITY: float = 300.0
@export var FAST_FALL_GRAVITY: float = 500.0
@export var WALL_GRAVITY: float = 25.0

@export var JUMP_VELOCITY: float = -70.0
@export var WALL_JUMP_VELOCITY: float = -70.0
@export var WALL_JUMP_PUSHBACK: float = 30.0

@export var DASH_DURATION: float
@export var DASH_SPEED: float

@export var INPUT_BUFFER_PATIENCE: float = 0.1
@export var COYOTE_TIME: float = 0.08


@export var ray : RayCast3D
@export var rayLength : float

@export var characterVisuals : Node3D

var model : Node3D
var animator : AnimationTree
var state_machine : AnimationNodeStateMachinePlayback

@onready var flip_cam: CameraFlip = get_node_or_null("Camera3D") # adapte le chemin si besoin


@onready var collision: PlayerCollision2D = $CollisionShape2D
@onready var collision2dRaycasts: PlayerCollision2DRaycasts = $PlayerCollision2DRaycasts




var z_plane_value := 0.0

var input_buffer : Timer
var coyote_timer : Timer
var dash_timer : Timer
var coyote_jump_available := true
var is_dashing := false
var can_dash := false
var dash_dir :Vector3
var hasJumped := false
var hasDashed := false
var wallOnLeft := false
var wallOnRight := false
var lastWall : Vector3

@onready var bow: Bow = $WeaponBow


func _ready():
	animator = $"Node3D/Character/CharacterContainer/IK Targets/AnimationTree"
	model = $"Node3D"
	state_machine = animator.get("parameters/playback")
	print(animator)
	
	animator.set("parameters/conditions/idle", true)
	animator.set("parameters/conditions/jump", false)
	animator.set("parameters/conditions/damaged", false)
	animator.set("parameters/conditions/isWalking", false)
	animator.set("parameters/conditions/shoot", false)
	animator.set("parameters/conditions/dash", false)
	animator.set("parameters/conditions/falling", false)
	
	
	health = max_heatlh
	_set_base_collision()
	
	z_plane_value = global_position.z

	input_buffer = Timer.new()
	input_buffer.wait_time = INPUT_BUFFER_PATIENCE
	input_buffer.one_shot = true
	add_child(input_buffer)
	
	dash_timer = Timer.new()
	dash_timer.wait_time = DASH_DURATION
	dash_timer.one_shot = true
	add_child(dash_timer)

	coyote_timer = Timer.new()
	coyote_timer.wait_time = COYOTE_TIME
	coyote_timer.one_shot = true
	add_child(coyote_timer)
	coyote_timer.timeout.connect(_on_coyote_timeout)
	if flip_cam:
		flip_cam.target_plane_z = z_plane_value    # aligne le plan d'appariement
		_toggle_dimension()


func _process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector("target_left", "target_right", "target_up", "target_down")
	var shoot := Input.is_action_just_pressed("shoot")
	if is3D: 
		if shoot:
			state_machine.travel("Shoot", true)
		bow.angle_bow_3d(direction, shoot)
	else:
		if shoot:
			state_machine.travel("Shoot", true)
		bow.angle_bow_2d(direction, shoot)

func _physics_process(delta):
	_set_collision()

		
	if velocity.x < 0:
		model.scale.x = -1
	elif velocity.x > 0:
		model.scale.x = 1
	
	if hasJumped:
		if velocity.y < 0:
			animator.set("parameters/conditions/falling", true)
		animator.set("parameters/conditions/jump", true)
		animator.set("parameters/conditions/isWalking", false)
		animator.set("parameters/conditions/idle", false)
	
	var horizontal_input := Input.get_axis("move_left", "move_right")
	var vertical_input := Input.get_axis("move_away", "move_approach")
	var dash_multiplier := 1
	#2.0 if Input.is_action_pressed("dash") else 1.0
	var jump_pressed := Input.is_action_just_pressed("jump")
	var try_jump := jump_pressed or input_buffer.time_left > 0.0

	var switch_dimension_pressed := Input.is_action_just_pressed("switch_dimension")
	if switch_dimension_pressed:
		print_debug("switched dimension")
		if flip_cam:
			_toggle_dimension()
	
	if Input.is_action_just_pressed("dash") && can_dash:
		dash_timer.start()
		_dash()
	
	if Input.is_action_just_released("jump") and velocity.y > 0.0:
		if hasJumped:
			velocity.y *= 0.25
	
	if is_dashing:
		hasJumped = false
		if(dash_timer.is_stopped()): _dash_stop()
		else:
			velocity = dash_dir * DASH_SPEED
		
	
	if is_on_floor() and not is_dashing:
		can_dash = true
	
	if is_on_floor():
		animator.set("parameters/conditions/jump", false)
		animator.set("parameters/conditions/falling", false)
			
		hasJumped = false
		if(not hasDashed):coyote_jump_available = true
		coyote_timer.stop()
	else:
		if coyote_jump_available and coyote_timer.is_stopped() and not hasJumped:
			coyote_timer.start()
		velocity.y -= _gravity_2d(horizontal_input) * delta
		
	if try_jump:
		if is_on_floor() or coyote_jump_available:
			hasJumped = true
			velocity.y = JUMP_VELOCITY
			coyote_jump_available = false
			input_buffer.stop()
			dash_timer.stop()
		elif is_on_wall_only() or (is_on_wall() and not is_on_floor()):
			var n := get_wall_normal()
			if n != Vector3.ZERO:
				if abs(n.x) > 0.1 and sign(velocity.x) == -sign(n.x):
					velocity.x = 0.0
				velocity.y = -WALL_JUMP_VELOCITY
				velocity.x = WALL_JUMP_PUSHBACK * n.x
				velocity.z = WALL_JUMP_PUSHBACK * n.z
				coyote_jump_available = false
				input_buffer.stop()
		elif wallOnLeft and not is3D:
			velocity.y = -WALL_JUMP_VELOCITY
			velocity.x = WALL_JUMP_PUSHBACK
			coyote_jump_available = false
			input_buffer.stop()
		elif wallOnRight and not is3D:
			velocity.y = -WALL_JUMP_VELOCITY
			velocity.x = -WALL_JUMP_PUSHBACK
			coyote_jump_available = false
			input_buffer.stop()
		elif lastWall != Vector3.ZERO:
			velocity = Vector3(lastWall.x * WALL_JUMP_PUSHBACK, -WALL_JUMP_VELOCITY, lastWall.z * WALL_JUMP_PUSHBACK)
			coyote_jump_available = false
			input_buffer.stop()
			lastWall = Vector3.ZERO
		elif jump_pressed:
			input_buffer.start()
	
	ray.target_position = Vector3(velocity.x, 0, velocity.z).normalized() * rayLength
	if(abs(velocity.x) < 0.1):
		ray.target_position.x = 0
	if(abs(velocity.z) < 0.1):
		ray.target_position.z = 0
	if ray.is_colliding():
		lastWall = ray.get_collision_normal()
	else:
		if(ray.target_position != Vector3.ZERO):
			lastWall = Vector3.ZERO

	# amorti / friction
	var floor_damping := 1.0 if is_on_floor() else 0.0
	if is3D:
		if (horizontal_input != 0 or vertical_input != 0) and not is_dashing:
			if is_on_floor():
				animator.set("parameters/conditions/isWalking", true)
				animator.set("parameters/conditions/idle", false)
			var targetz := vertical_input * SPEED
			var targetx := horizontal_input * SPEED
			velocity.x = move_toward(velocity.x, targetx, ACCELERATION * delta)
			velocity.z = move_toward(velocity.z, targetz, ACCELERATION * delta)
		else:
			animator.set("parameters/conditions/isWalking", false)
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta * floor_damping)
			velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta * floor_damping)
	else:
		if horizontal_input != 0.0 && not is_dashing:
			if is_on_floor():
				animator.set("parameters/conditions/isWalking", true)
				animator.set("parameters/conditions/idle", false)
			var target := horizontal_input * SPEED * dash_multiplier
			velocity.x = move_toward(velocity.x, target, ACCELERATION * delta)
		else:
			animator.set("parameters/conditions/isWalking", false)
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta * floor_damping)

	# annule la composante qui pousse dans le mur pour éviter le "rebond"
	if is_on_wall_only():
		var wn := get_wall_normal()
		if abs(wn.x) > 0.1 and sign(velocity.x) == -sign(wn.x):
			velocity.x = 0.0
	
	move_and_slide()
	
	# Die if below death barrier
	if global_position.y < death_barrier:
		_respawn()
	
	if velocity == Vector3.ZERO and not hasJumped and not is_dashing:
		animator.set("parameters/conditions/idle", true)


func _gravity_2d(input_dir: float) -> float:
	if is_dashing: return 0
	if Input.is_action_pressed("fast_fall"):
		return FAST_FALL_GRAVITY
	if is_on_wall_only() and velocity.y < 0.0 and input_dir != 0.0:
		return WALL_GRAVITY
	return GRAVITY if velocity.y > 0.0 else FALL_GRAVITY

func _dash():
	animator.set("parameters/conditions/dash", true)
	hasDashed = true
	coyote_jump_available = false
	hasJumped = false
	is_dashing = true
	can_dash = false
	
	var dir2D: Vector2 = Input.get_vector("move_left","move_right","move_approach","move_away")
	var dir3D: Vector3 = Vector3.ZERO
	if is3D:
		dir3D.x = dir2D.x
		dir3D.z = -dir2D.y
		dash_dir = dir3D
	else:
		dir3D.x = dir2D.x
		dir3D.y = dir2D.y
		dash_dir = dir3D
		
func _dash_stop():
	animator.set("parameters/conditions/dash", false)
	velocity *= 0.8
	velocity.y *= 0.7
	is_dashing = false

func _on_coyote_timeout():
	coyote_jump_available = false

func _get_dash_dir():
	Input.get_vector("move_left", "move_right","move_approach","move_away")


func _on_wall_detect_left_body_entered(body: Node3D) -> void:
	if body.is_in_group("Wall"):
		wallOnLeft = true

func _on_wall_detect_left_body_exited(body: Node3D) -> void:
	if body.is_in_group("Wall"):
		wallOnLeft = false

func _on_wall_detect_right_body_entered(body: Node3D) -> void:
	if body.is_in_group("Wall"):
		wallOnRight = true

func _on_wall_detect_right_body_exited(body: Node3D) -> void:
	if body.is_in_group("Wall"):
		wallOnRight = false


func _toggle_dimension():
	if is3D:
		flip_cam.to_2D()
		_set_base_collision()

		_full_collision = false
	else:
		flip_cam.to_3D()
		_set_base_collision()

	is3D = !is3D




#region 3D/2D Collision transitions

@export var max_level_depth: float = 100

const START_COLLISION_FRONT: float = 1
const START_COLLISION_BACK: float = -1

var _collision_front: float = 1
var _collision_back: float = 1

var _full_collision: bool = false


func _set_base_collision() -> void:
	collision.set_collision_bounds(START_COLLISION_FRONT, START_COLLISION_BACK)
	collision2dRaycasts.setup_raycasts(max_level_depth)


func _set_collision() -> void:
	if _full_collision or is3D:
		return
	
	_collision_front = collision2dRaycasts.get_max_depth(global_position.z, true, max_level_depth)
	_collision_back = -collision2dRaycasts.get_max_depth(global_position.z, false, max_level_depth)
	
	collision.set_collision_bounds(_collision_front, _collision_back)
	
	if _collision_front == max_level_depth and _collision_back == -max_level_depth:
		_full_collision = true


#endregion

#region Health and death

@onready var ui: PlayerUI = $PlayerUI
var _respawn_point: Vector3

@export_category("Health")
@export var max_heatlh: int = 5
@export var death_barrier: float = -20.

var _current_checkpoint: Checkpoint

var health: int:
	set(value):
		health = value
		ui.update_health_ui(health)
		if health <= 0:
			_respawn()

var points: int = 0:
	set(value):
		points = value
		ui.update_points_display(points)


func _respawn() -> void:
	velocity = Vector3.ZERO
	health = max_heatlh
	global_position = _respawn_point


func set_checkpoint(checkpoint: Checkpoint) -> void:
	if _current_checkpoint and _current_checkpoint != checkpoint:
			_current_checkpoint.untouch_checkpoint()
	
	_current_checkpoint = checkpoint
	_respawn_point = _current_checkpoint.global_position


#endregion
