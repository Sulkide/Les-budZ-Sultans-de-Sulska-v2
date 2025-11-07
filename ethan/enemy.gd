extends CharacterBody2D

@export var max_health: int = 100
@export var move_speed: float = 100.0
@export var bump_force: float = 500.0
@export var bump_duration: float = 5
@export var damage_amount: int = 20

var current_health: int
var is_bumped: bool = false
var bump_velocity: Vector2 = Vector2.ZERO
var bump_timer: float = 0.0


func _ready():
	current_health = max_health


func _physics_process(delta: float):
	if is_bumped:
		velocity = bump_velocity
		move_and_slide()
		bump_timer -= delta
		bump_velocity = bump_velocity.lerp(Vector2.ZERO, delta * 5.0)
		if bump_timer <= 0:
			is_bumped = false
	else:
		velocity = Vector2.ZERO
		move_and_slide()

	# TEST
	if Input.is_action_just_pressed("attack"):
		take_damage(10, global_position + Vector2(-50, 0))
		print("Ennemi a subi un dégâts")


func take_damage(amount: int, from_position: Vector2):
	if current_health <= 0:
		return

	current_health -= amount

	if current_health <= 0:
		die()
	else:
		apply_bump(from_position)


func apply_bump(from_position: Vector2):
	is_bumped = true
	bump_timer = bump_duration
	var direction = (global_position - from_position).normalized()
	bump_velocity = direction * bump_force


func die():
	queue_free()
