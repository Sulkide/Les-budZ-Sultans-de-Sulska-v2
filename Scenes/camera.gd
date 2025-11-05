class_name Cameraflip
extends Camera3D

@onready var anim: AnimationPlayer = $AnimationPlayer

var _2D = false

func toggle_view():
	if _2D:
		anim.play("2D to 3D")
	else:
		anim.play("3D to 2D")
	_2D = not _2D
