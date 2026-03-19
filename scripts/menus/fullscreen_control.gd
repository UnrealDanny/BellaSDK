extends CheckButton

func _on_toggled(toggled_on: bool) -> void:
	var main_window = get_tree().root
	
	if toggled_on:
		# EXCLUSIVE mode forcibly bypasses the standard X11 window manager rules
		main_window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	else:
		main_window.mode = Window.MODE_WINDOWED
