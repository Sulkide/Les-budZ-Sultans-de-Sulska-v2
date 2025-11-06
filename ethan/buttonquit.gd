extends Button


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

func _on_button_pressed() -> void:
	get_tree().quit()
