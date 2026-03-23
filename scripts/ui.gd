extends CanvasLayer

@onready var center_dot: TextureRect = $MarginContainer/CenterDot
@onready var ui_circle_zoom: TextureRect = $MarginContainer/UICircleZoom
@onready var ui_circle_zoom_inner: TextureRect = $MarginContainer/UICircleZoomInner
@onready var vignette: ColorRect = $Vignette
@onready var fisheye_zoom: ColorRect = $FisheyeZoom

@onready var noclip_message_container: PanelContainer = $MarginContainer3/NoclipMessageContainer
@onready var noclip_label_message: Label = $MarginContainer3/NoclipMessageContainer/NoclipLabelMessage
@onready var noclip_button: Button = $DebugPanel/VBoxContainer/NoclipButton

@onready var debug_panel: Panel = $DebugPanel

@onready var fullbright_button: Button = $DebugPanel/VBoxContainer/FullbrightButton
@onready var wireframe_button: Button = $DebugPanel/VBoxContainer/WireframeButton

var is_fullbright: bool = false
var is_wireframe: bool = false

# NEW UI VARS
var zoom_tween: Tween
var is_player_crouching: bool = false
var ui_lerp_speed: float = 15.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect signals
	Events.noclip_toggled.connect(_on_noclip_toggled)
	Events.noclip_speed_changed.connect(_on_noclip_speed_changed)
	Events.player_zoomed.connect(_on_player_zoomed)
	Events.player_crouch_changed.connect(_on_player_crouched)

	debug_panel.hide()
	fullbright_button.pressed.connect(_on_fullbright_button_pressed)

	# Setup Zoom Circles (Uncommented so they actually hide on startup!)

	# We use custom_minimum_size / 2.0 to guarantee the pivot is dead center!
	ui_circle_zoom.pivot_offset = ui_circle_zoom.custom_minimum_size / 2.0
	ui_circle_zoom.scale = Vector2.ZERO
	ui_circle_zoom.modulate.a = 0.0
	ui_circle_zoom.hide()

	ui_circle_zoom_inner.pivot_offset = ui_circle_zoom_inner.custom_minimum_size / 2.0
	ui_circle_zoom_inner.scale = Vector2.ZERO
	ui_circle_zoom_inner.modulate.a = 0.0
	ui_circle_zoom_inner.hide()

func _process(delta: float) -> void:
	# 0.8 is usually the 'sweet spot' for a heavy vignette. 
	# 10.0 might be making the whole screen black or breaking the math!
	var target_vignette_opacity = 0.8 if is_player_crouching else 0.0

	var current_opacity = vignette.material.get_shader_parameter("vignette_opacity")
	if current_opacity == null:
		current_opacity = 0.0
		
	var new_opacity = lerp(current_opacity, target_vignette_opacity, delta * ui_lerp_speed)
	vignette.material.set_shader_parameter("vignette_opacity", new_opacity)



# --- ZOOM ANIMATION LOGIC ---
func _on_player_zoomed(is_zooming: bool) -> void:
	if zoom_tween and zoom_tween.is_valid():
		zoom_tween.kill()
		
	zoom_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if is_zooming:
		# Hide standard crosshair, show zoom circles
		center_dot.hide() 
		ui_circle_zoom.show()
		ui_circle_zoom_inner.show()
		
		ui_circle_zoom.scale = Vector2.ZERO
		ui_circle_zoom.modulate.a = 0.0
		ui_circle_zoom_inner.scale = Vector2.ZERO
		ui_circle_zoom_inner.modulate.a = 0.0

		zoom_tween.tween_property(ui_circle_zoom, "scale", Vector2(1.0, 1.0), 0.5).from(Vector2.ZERO)
		zoom_tween.tween_property(ui_circle_zoom, "modulate:a", 1.0, 0.3).from(0.0)
		zoom_tween.tween_property(ui_circle_zoom, "rotation", deg_to_rad(15), 1.0).from(0.0)

		zoom_tween.tween_property(ui_circle_zoom_inner, "scale", Vector2(1.0, 1.0), 0.5).from(Vector2.ZERO)
		zoom_tween.tween_property(ui_circle_zoom_inner, "modulate:a", 0.1, 0.3).from(0.0)
		zoom_tween.tween_property(ui_circle_zoom_inner, "rotation", deg_to_rad(-45), 1.0).from(0.0)

		zoom_tween.tween_property(fisheye_zoom, "material:shader_parameter/effect_strength", 0.4, 0.2).from(0.0)

	else:
		center_dot.show()

		zoom_tween.tween_property(ui_circle_zoom, "scale", Vector2(0.0, 0.0), 0.5)
		zoom_tween.tween_property(ui_circle_zoom, "modulate:a", 0.0, 0.3)
		zoom_tween.tween_property(ui_circle_zoom, "rotation", deg_to_rad(0), 0.25)

		zoom_tween.tween_property(ui_circle_zoom_inner, "scale", Vector2(0.0, 0.0), 0.5)
		zoom_tween.tween_property(ui_circle_zoom_inner, "modulate:a", 0.0, 0.3)
		zoom_tween.tween_property(ui_circle_zoom_inner, "rotation", deg_to_rad(0), 0.25)

		zoom_tween.tween_property(fisheye_zoom, "material:shader_parameter/effect_strength", 0.0, 0.2)
		
		zoom_tween.finished.connect(func(): 
			ui_circle_zoom.hide()
			ui_circle_zoom_inner.hide()
		)

# --- CROUCH LISTENER ---
func _on_player_crouched(crouching: bool) -> void:
	is_player_crouching = crouching
	print("UI received crouch signal! Crouching: ", crouching)

# --- DEBUG & NOCLIP LOGIC ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_menu"):
		var is_open = not debug_panel.visible
		debug_panel.visible = is_open
		get_tree().paused = is_open

		if is_open:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
		Events.debug_menu_toggled.emit(is_open)

func _on_noclip_button_pressed() -> void:
	Events.noclip_ui_button_pressed.emit()

func _on_noclip_toggled(is_flying: bool) -> void:
	if is_flying:
		noclip_message_container.show()
		noclip_button.text = "Noclip ON"
	else:
		noclip_message_container.hide()
		noclip_button.text = "Noclip OFF"

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
