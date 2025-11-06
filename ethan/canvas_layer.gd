extends CanvasLayer


var is_paused = false setget set_is_paused


func _unhandled_input(_event):
if Input.is\_action\_just\_pressed("pause") and Global.can\_pause == true:

	self.is\_paused = !is\_paused
