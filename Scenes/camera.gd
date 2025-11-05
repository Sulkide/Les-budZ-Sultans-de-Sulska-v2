class_name Cameraflip
extends Camera3D

@export_category("Preset camera Orthographique")
@export var sizeOrtho = 35.0

@export_category("Preset Camera 2D & 3D")
@export var pos_x = 0.0
@export var pos_y = 7.7

@export_category("Preset Camera 2D")
@export var pos2D_Z = 1984.0
@export var rot2D_X = 0.0
@export var fov2D = 1.0

@export_category("Preset Camera 3D")
@export var pos3D_Z = 17.0
@export var rot3D_X = -9.0
@export var fov3D = 75.0
@onready var anim : AnimationPlayer = $AnimationPlayer

func flip2D(time: float):
	anim.speed_scale = 1/time
	anim.play("3D to 2D")

func flip3D(time: float):
	anim.speed_scale = 1/time
	anim.play("2D to 3D")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	position.x = pos_x
	position.y = pos_y
	size = sizeOrtho
	pass # Replace with function body.
