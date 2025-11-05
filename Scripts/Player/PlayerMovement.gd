class_name Player
extends CharacterBody3D

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

@export var lock_z_plane := true
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

func _ready():
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

func _physics_process(delta):
	if lock_z_plane:
		velocity.z = 0.0

	var horizontal_input := Input.get_axis("move_left", "move_right")
	var dash_multiplier := 1
	#2.0 if Input.is_action_pressed("dash") else 1.0
	var jump_pressed := Input.is_action_just_pressed("jump")
	var try_jump := jump_pressed or input_buffer.time_left > 0.0

	
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
				coyote_jump_available = false
				input_buffer.stop()
		elif jump_pressed:
			input_buffer.start()


	# amorti / friction
	var floor_damping := 1.0 if is_on_floor() else 0.0
	if horizontal_input != 0.0 && not is_dashing:
		var target := horizontal_input * SPEED * dash_multiplier
		velocity.x = move_toward(velocity.x, target, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta * floor_damping)

	# annule la composante qui pousse dans le mur pour éviter le "rebond"
	if is_on_wall_only():
		var wn := get_wall_normal()
		if abs(wn.x) > 0.1 and sign(velocity.x) == -sign(wn.x):
			velocity.x = 0.0

	move_and_slide()

	if lock_z_plane:
		global_position.z = z_plane_value

func _gravity_2d(input_dir: float) -> float:
	if is_dashing: return 0
	if Input.is_action_pressed("fast_fall"):
		return FAST_FALL_GRAVITY
	if is_on_wall_only() and velocity.y < 0.0 and input_dir != 0.0:
		return WALL_GRAVITY
	return GRAVITY if velocity.y > 0.0 else FALL_GRAVITY
	
func _dash():
	hasDashed = true
	coyote_jump_available = false
	hasJumped = false
	is_dashing = true
	can_dash = false
	
	var dir2D: Vector2 = Input.get_vector("move_left","move_right","move_approach","move_away")
	var dir3D: Vector3 = Vector3.ZERO
	dir3D.x = dir2D.x
	dir3D.y = dir2D.y
	dash_dir = dir3D
	
func _dash_stop():
	velocity *= 0.8
	velocity.y *= 0.7
	is_dashing = false

func _on_coyote_timeout():
	coyote_jump_available = false

func _get_dash_dir():
	Input.get_vector("move_left", "move_right","move_approach","move_away")
