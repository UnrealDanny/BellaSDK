extends CanvasLayer

@onready var noclip_message_container: PanelContainer = $MarginContainer3/NoclipMessageContainer
@onready var noclip_label_message: Label = $MarginContainer3/NoclipMessageContainer/NoclipLabelMessage

@onready var debug_panel: Panel = $DebugPanel

@onready var fullbright_button: Button = $DebugPanel/VBoxContainer/FullbrightButton
@onready var wireframe_button: Button = $DebugPanel/VBoxContainer/WireframeButton

var is_fullbright: bool = false
var is_wireframe: bool = false

func _ready() -> void:
	# CRITICAL: This tells Godot to keep running this specific script 
	# even when the rest of the game universe is paused!
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect the UI to the radio tower
	Events.noclip_toggled.connect(_on_noclip_toggled)
	Events.noclip_speed_changed.connect(_on_noclip_speed_changed)

	debug_panel.hide()
	fullbright_button.pressed.connect(_on_fullbright_button_pressed)

# We use _unhandled_input so we don't accidentally trigger it while typing in a text box
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_menu"):
		# 1. Flip the visibility
		var is_open = not debug_panel.visible
		debug_panel.visible = is_open

		# 2. PAUSE THE GAME!
		get_tree().paused = is_open

		# 3. Handle the Mouse Capture
		if is_open:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
		Events.debug_menu_toggled.emit(is_open)


func _on_noclip_toggled(is_flying: bool) -> void:
	if is_flying == true:
		noclip_message_container.show()
	else:
		noclip_message_container.hide()

func _on_noclip_speed_changed(speed: float) -> void:
	noclip_label_message.text = "Noclip ON: %.1fx speed" % speed
	
func _on_fullbright_button_pressed() -> void:
	is_fullbright = !is_fullbright
	
	if is_fullbright:
		fullbright_button.text = "Fullbright ON"
	else:
		fullbright_button.text = "Fullbright OFF"
		
	Events.fullbright_toggled.emit(is_fullbright)
	
func _on_wireframe_button_pressed() -> void:
	is_wireframe = !is_wireframe
	
	if is_wireframe:
		wireframe_button.text = "Wireframe ON"
	else:
		wireframe_button.text = "Wireframe OFF"
		
	Events.wireframe_toggled.emit(is_wireframe)
