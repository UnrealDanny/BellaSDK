extends PanelContainer 

@onready var metrics_label: RichTextLabel = $MetricsLabel

var player: CharacterBody3D

func _ready() -> void:
	visible = false # Keep it hidden on launch

	# MAGIC BULLET: Automatically find the player without Inspector paths!
	player = get_tree().get_first_node_in_group("player")
		
	metrics_label.add_theme_color_override("font_outline_color", Color.BLACK)
	metrics_label.add_theme_constant_override("outline_size", 4)

func _process(_delta: float) -> void:
	# PERFORMANCE BOOST: Do nothing if the window is closed
	if not visible or not player: 
		return

	var fps = Engine.get_frames_per_second()
	var vel = player.velocity
	var speed = vel.length()

	# --- YOUR ROBUST COLOR LOGIC ---
	var fps_color = "green"
	if fps >= 60:
		fps_color = "green"
	elif fps >= 30:
		fps_color = "yellow"
	else:
		fps_color = "red"
			
	var is_pressing_keys = player.input_dir.length() > 0.1

	var state = "IDLE"
	if player.flying: state = "NOCLIP"
	elif player.swimming: state = "SWIMMING"
	elif player.on_zipline: state = "ZIPLINE"
	elif player.on_ladder: state = "LADDER"
	elif player.crouching: state = "CROUCHING" if is_pressing_keys else "CROUCH IDLE"
	elif player.sprinting: state = "SPRINTING"
	elif player.on_monkey_bars: state = "MONKE"
	elif player.on_rope: state = "ROPE"
	elif player.in_updraft: state = "AIRBORNE UPDRAFT"
	elif player.is_using_zoom: state = "ZOOM"
	elif player.is_on_floor(): state = "WALKING" if is_pressing_keys else "IDLE"
	else: state = "AIRBORNE"

	# --- NEW BOOLEAN CHECKS ---
	# Change these variable names if they differ in your player.gd!
	var flashlight_str = "ON" if player.flashlight.visible else "OFF"
	#var interact_str = "YES" if player.is_interacting else "NO"

	var text = ""
	text += "--- ENGINE ---\n"
	# We wrap the FPS number in BBCode color tags!
	text += "[color=%s]FPS: %d[/color]\n" % [fps_color, fps]
	text += "Memory: %s\n" % String.humanize_size(OS.get_static_memory_usage())
	text += "\n--- PLAYER STATE ---\n"
	text += "STATE: %s\n" % state
	text += "SPEED: %.2f m/s\n" % speed
	text += "VELOCITY: (%.1f, %.1f, %.1f)\n" % [vel.x, vel.y, vel.z]
	text += "POS: %s\n" % var_to_str(player.global_position).replace("Vector3", "")
	text += "GROUNDED: %s\n" % ("YES" if player.is_on_floor() else "NO")
	text += "FLASHLIGHT: %s\n" % flashlight_str
	#text += "INTERACTING: %s\n" % interact_str

	metrics_label.text = text
	
# Called by UI.gd when you click the button
func toggle_window() -> void:
	visible = !visible
