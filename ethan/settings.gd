extends Control


func _on_pressed() -> void:
	get_tree().change_scene_to_file("res://settings.tscn")

func _on_button_pressed() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db($VolumeSlider.value))
