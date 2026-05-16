extends CanvasLayer

@onready var main_buttons: VBoxContainer = $MarginContainer/MainButtons
@onready var options: Panel = $Options
@onready var controls_panel: Panel = $ControlsPanel

# --- NEW: ACCESSIBILITY ---
@onready var accessibility_panel: Panel = $AccessibilityPanel
@onready var brightness_slider: HSlider = %BrightnessSlider
@onready var brightness_input: LineEdit = %BrightnessLine
@onready var contrast_slider: HSlider = %ContrastSlider
@onready var contrast_input: LineEdit = %ContrastLine
@onready var saturation_slider: HSlider = %SaturationSlider
@onready var saturation_input: LineEdit = %SaturationLine

@onready var continue_button: Button = %Continue
@onready var new_game_button: Button = %NewGame
@onready var restart_button: Button = %RestartGame

# --- EXPLICIT UI REFERENCES ---
@onready var sens_slider: HSlider = %MouseSensitivitySlider
@onready var sens_label: Label = %MouseSensitivityLabel
@onready var sens_input: LineEdit = %MouseSensitivityLine

# --- RESOLUTION VARIABLES ---
@onready var resolution_options: OptionButton = %ResolutionOptionButton

#@onready var accessibility_button: Button = $MarginContainer/OptionsButtons/AccessibilityButton # Adjust path if needed
@onready var accessibility_button: Button = $Options/MarginContainer/OptionsButtons/AccessibilityButton
@onready var options_content: VBoxContainer = $Options/VBoxContainer # The container holding Resolution/Sens

const RESOLUTIONS: Dictionary = {
	"1920 x 1080": Vector2i(1920, 1080),
	"1600 x 900": Vector2i(1600, 900),
	"1366 x 768": Vector2i(1366, 768),
	"1280 x 720": Vector2i(1280, 720),
	"1024 x 768": Vector2i(1024, 768),
	"800 x 600": Vector2i(800, 600),
	"640 x 480": Vector2i(640, 480)
}

# --- AUTOMATED REMAPPING ---
var is_remapping: bool = false
var action_to_remap: String = ""
var remapping_button: Button = null

# --- NEW SWAP VARIABLES ---
var pending_swap_event: InputEvent = null
var pending_conflict_action: String = ""

# List every action exactly as it appears in your Project Settings > Input Map
var my_actions := [
	"forward", "backward", "left", "right", 
	"jump", "crouch", "interact", "flashlight", 
	"zoom", "noclip", "console"
]

const SAVE_PATH = "user://settings.cfg"
const DEFAULT_SENSITIVITY: float = 0.05 

# --- NEW: ACCESSIBILITY DEFAULTS ---
const DEFAULT_BRIGHTNESS: float = 1.0
const DEFAULT_CONTRAST: float = 1.0
const DEFAULT_SATURATION: float = 1.0

# --- AUTO-CALIBRATION VARIABLES ---
var max_mouse_speed: float = 0.0
var has_calibrated: bool = false 

const CHAPTER_SCREEN = preload("res://scenes/ChapterScreen.tscn")

func _ready() -> void:
	_populate_resolution_dropdown()
	resolution_options.item_selected.connect(_on_resolution_selected)
	
	# 1. Connect signals FIRST
	sens_slider.value_changed.connect(_on_sensitivity_changed)
	sens_slider.drag_ended.connect(_on_sensitivity_drag_ended) 
	
	if has_node("%MouseSensitivityLine"):
		sens_input.text_submitted.connect(_on_sensitivity_input_submitted)
		sens_input.focus_entered.connect(_on_sensitivity_focus_entered)
		sens_input.focus_exited.connect(_on_sensitivity_focus_exited)
		
	continue_button.pressed.connect(_on_resume_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed) 
	
	# --- NEW: ACCESSIBILITY SIGNAL BINDING ---
	# Binding allows us to reuse the same 5 functions for all 3 sliders
	_connect_adjustment_signals(brightness_slider, brightness_input, "brightness")
	_connect_adjustment_signals(contrast_slider, contrast_input, "contrast")
	_connect_adjustment_signals(saturation_slider, saturation_input, "saturation")

	# 2. Load from file
	load_controls()
	
	# 3. CONTEXT CHECK: Are we at the Title Screen or in the Game?
	if get_parent().has_method("toggle_pause"):
		continue_button.show()
		restart_button.show() 
	else:
		continue_button.hide()
		restart_button.hide() 
		new_game_button.text = ""
	
	# 4. Set up the UI visibility
	main_buttons.visible = true
	options.visible = false
	controls_panel.visible = false
	if accessibility_panel: accessibility_panel.visible = false # --- NEW ---
	create_control_list()
	
	# Connect the new button
	accessibility_button.pressed.connect(_on_accessibility_pressed)
	
	# Make sure the panel is hidden at start
	accessibility_panel.visible = false

# --- NEW: ACCESSIBILITY HELPER ---
func _connect_adjustment_signals(slider: HSlider, input_box: LineEdit, setting_name: String) -> void:
	slider.value_changed.connect(_on_adjustment_changed.bind(input_box))
	slider.drag_ended.connect(_on_adjustment_drag_ended.bind(setting_name, slider))
	input_box.text_submitted.connect(_on_adjustment_input_submitted.bind(setting_name, slider))
	input_box.focus_entered.connect(_on_adjustment_focus_entered.bind(input_box))
	input_box.focus_exited.connect(_on_adjustment_focus_exited.bind(input_box, slider, setting_name))

func create_control_list() -> void:
	var container := $ControlsPanel/VBoxContainer
	var template := $ControlsPanel/VBoxContainer/RemapButtonTemplate
	
	for action: String in my_actions:
		var new_button := template.duplicate()
		new_button.show()
		container.add_child(new_button)
		new_button.set_meta("action", action)
		update_button_text(new_button, action)
		new_button.toggled.connect(_on_any_remap_button_toggled.bind(new_button))

func _on_any_remap_button_toggled(toggled_on: bool, button: Button) -> void:
	if toggled_on:
		is_remapping = true
		remapping_button = button
		action_to_remap = button.get_meta("action")
		button.text = "Press any key..."
	else:
		is_remapping = false
		pending_swap_event = null 
		update_button_text(button, button.get_meta("action"))

func update_button_text(button: Button, action: String) -> void:
	var events := InputMap.action_get_events(action)
	var key_name := "Unassigned"
	
	if events.size() > 0:
		var raw_text := events[0].as_text()
		key_name = raw_text.replace(" (Physical)", "") \
						   .replace(" - Physical", "") \
						   .replace(" (Physics)", "") \
						   .replace(" - Physics", "") \
						   .strip_edges()
						
	button.text = action.capitalize() + ": " + key_name

func _on_new_game_pressed() -> void:
	if not has_calibrated:
		_apply_bucket_calibration()
		
	main_buttons.hide() 
	var chapter_window := CHAPTER_SCREEN.instantiate()
	add_child(chapter_window)

func _on_start_game_pressed() -> void:
	if not has_calibrated:
		_apply_bucket_calibration()
		
	get_tree().paused = false
	
	if get_parent().has_method("toggle_pause"):
		get_tree().reload_current_scene()

func _apply_bucket_calibration() -> void:
	has_calibrated = true
	var auto_sens: float = DEFAULT_SENSITIVITY
	
	if max_mouse_speed > 4000.0:
		auto_sens = 0.5 
	elif max_mouse_speed > 1500.0:
		auto_sens = 0.1
	else:
		auto_sens = 0.05

	sens_slider.value = auto_sens
	_save_setting_to_disk("mouse_sensitivity", auto_sens) # Updated to use generic saver
	
func _on_exit_pressed() -> void:
	get_tree().quit()

# --- UPDATED: PANEL ROUTING ---
func _on_options_pressed() -> void:
	main_buttons.visible = false
	options.visible = true
	# Ensure the sub-panels and main content are reset correctly
	options_content.visible = true 
	controls_panel.visible = false
	accessibility_panel.visible = false

func _on_back_pressed() -> void:
	main_buttons.visible = true
	options.visible = false
	controls_panel.visible = false
	if accessibility_panel: accessibility_panel.visible = false

func _on_contols_pressed() -> void:
	# Hide the main options list
	options_content.visible = false
	# Show the controls panel
	controls_panel.visible = true

func _on_back_controls_pressed() -> void:
	# Show the options list again
	options_content.visible = true
	# Hide the sub-panel
	controls_panel.visible = false

func _on_accessibility_pressed() -> void:
	# Hide the main options list
	options_content.visible = false
	# Show the accessibility panel
	accessibility_panel.visible = true

func _on_back_accessibility_pressed() -> void:
	# Show the options list again
	options_content.visible = true
	# Hide the sub-panel
	accessibility_panel.visible = false
		
func _input(event: InputEvent) -> void:
	if is_remapping:
		if event is InputEventKey or event is InputEventMouseButton:
			if event.is_pressed():
				
				if pending_swap_event != null and event.as_text() == pending_swap_event.as_text():
					execute_swap(event)
					return
				
				var conflicting_action := get_action_with_event(event)
				
				if conflicting_action != "" and conflicting_action != action_to_remap:
					pending_swap_event = event
					pending_conflict_action = conflicting_action
					
					var key_name := event.as_text().split("(")[0].strip_edges()
					%ConflictLabel.text = action_to_remap.capitalize() + " and " + conflicting_action.capitalize() + " use the same key. \nPress [" + key_name + "] again to switch, or press a different key."
					%ConflictPanel.show()
					
					get_tree().create_timer(4.0).timeout.connect(func() -> void: %ConflictPanel.hide())
					get_viewport().set_input_as_handled()
					return 

				InputMap.action_erase_events(action_to_remap)
				InputMap.action_add_event(action_to_remap, event)
				
				save_controls() 
				
				is_remapping = false
				pending_swap_event = null 
				remapping_button.button_pressed = false
				update_button_text(remapping_button, action_to_remap)
				
				%ConflictPanel.hide()
				get_viewport().set_input_as_handled()
	
	if not has_calibrated and event is InputEventMouseMotion:
		var current_speed: float = event.velocity.length()
		if current_speed > max_mouse_speed:
			max_mouse_speed = current_speed
			
func _on_reset_button_pressed() -> void:
	InputMap.load_from_project_settings()
	
	var dir := DirAccess.open("user://")
	if dir.file_exists("settings.cfg"):
		dir.remove("settings.cfg")
		
	sens_slider.value = DEFAULT_SENSITIVITY 
	
	# --- NEW: RESET COLOR ADJUSTMENTS ---
	brightness_slider.value = DEFAULT_BRIGHTNESS
	contrast_slider.value = DEFAULT_CONTRAST
	saturation_slider.value = DEFAULT_SATURATION
	_apply_visual_settings()
	
	has_calibrated = false  
	max_mouse_speed = 0.0   
	
	refresh_all_button_labels()

func refresh_all_button_labels() -> void:
	var container := $ControlsPanel/VBoxContainer
	for child in container.get_children():
		if child is Button and child.has_meta("action"):
			var action_name: String = child.get_meta("action")
			update_button_text(child, action_name)

func save_controls() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH) 
	
	for action: String in my_actions:
		var events := InputMap.action_get_events(action)
		if events.size() > 0:
			config.set_value("Controls", action, events[0])
	
	config.save(SAVE_PATH)
	print("Controls saved to: ", OS.get_user_data_dir())

func load_controls() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	
	if err != OK: 
		sens_slider.value = DEFAULT_SENSITIVITY
		brightness_slider.value = DEFAULT_BRIGHTNESS
		contrast_slider.value = DEFAULT_CONTRAST
		saturation_slider.value = DEFAULT_SATURATION
		_apply_visual_settings()
		return 

	# --- Load Controls ---
	for action: String in my_actions:
		if config.has_section_key("Controls", action):
			var event := config.get_value("Controls", action) as InputEvent
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, event)
			
	# --- Load Sensitivity ---
	if config.has_section_key("Settings", "mouse_sensitivity"):
		var saved_sens: float = config.get_value("Settings", "mouse_sensitivity")
		sens_slider.value = saved_sens 
		has_calibrated = true
		
	# --- NEW: Load Adjustments ---
	brightness_slider.value = config.get_value("Settings", "brightness", DEFAULT_BRIGHTNESS)
	contrast_slider.value = config.get_value("Settings", "contrast", DEFAULT_CONTRAST)
	saturation_slider.value = config.get_value("Settings", "saturation", DEFAULT_SATURATION)
	_apply_visual_settings()

	# --- Load Resolution ---
	if config.has_section_key("Settings", "resolution_x") and config.has_section_key("Settings", "resolution_y"):
		var res_x: int = config.get_value("Settings", "resolution_x")
		var res_y: int = config.get_value("Settings", "resolution_y")
		var saved_res := Vector2i(res_x, res_y)
		
		DisplayServer.window_set_size(saved_res)
		
		@warning_ignore("integer_division")
		var screen_center := DisplayServer.screen_get_position() + DisplayServer.screen_get_size() / 2
		@warning_ignore("integer_division")
		var window_position := screen_center - saved_res / 2
		DisplayServer.window_set_position(window_position)
		
		var res_string := str(res_x) + " x " + str(res_y)
		for i in range(resolution_options.get_item_count()):
			if resolution_options.get_item_text(i) == res_string:
				resolution_options.select(i)
				break
			
func get_action_with_event(new_event: InputEvent) -> String:
	for action: String in my_actions:
		if InputMap.action_has_event(action, new_event):
			return action
	return ""

func execute_swap(new_event: InputEvent) -> void:
	var old_events := InputMap.action_get_events(action_to_remap)
	var old_event := old_events[0] if old_events.size() > 0 else null
	
	InputMap.action_erase_events(action_to_remap)
	InputMap.action_erase_events(pending_conflict_action)
	InputMap.action_add_event(action_to_remap, new_event)
	
	if old_event:
		InputMap.action_add_event(pending_conflict_action, old_event)
		
	save_controls()
	
	is_remapping = false
	pending_swap_event = null
	pending_conflict_action = ""
	remapping_button.button_pressed = false
	
	refresh_all_button_labels() 
	
	%ConflictLabel.text = "Keys swapped successfully!"
	%ConflictPanel.show()
	get_tree().create_timer(2.0).timeout.connect(func() -> void: %ConflictPanel.hide())
	get_viewport().set_input_as_handled()

func _on_resume_pressed() -> void:
	if get_parent().has_method("toggle_pause"):
		get_parent().toggle_pause()


# ==========================================
# UNIVERSAL SETTINGS I/O (Replaces old Sens logic)
# ==========================================

func _save_setting_to_disk(key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH) 
	config.set_value("Settings", key, value)
	config.save(SAVE_PATH)

# ==========================================
# SENSITIVITY SYSTEM
# ==========================================

func _on_sensitivity_changed(value: float) -> void:
	sens_label.text = "Mouse Sensitivity: "
	if not sens_input.has_focus():
		sens_input.text = "%.2f" % value

	var player := get_parent()
	if player and "mouse_sensitivity_base" in player:
		player.mouse_sensitivity_base = value
		player.mouse_sensitivity = value
		player.mouse_sensitivity_zoom = value / 10.0

func _on_sensitivity_drag_ended(value_changed: bool) -> void:
	if value_changed:
		_save_setting_to_disk("mouse_sensitivity", sens_slider.value)

func _on_sensitivity_input_submitted(new_text: String) -> void:
	var new_val: float = clamp(new_text.to_float(), 0.01, 1.0) 
	sens_slider.value = new_val 
	sens_input.release_focus()
	_save_setting_to_disk("mouse_sensitivity", new_val)

func _on_sensitivity_focus_entered() -> void:
	sens_input.text = ""

func _on_sensitivity_focus_exited() -> void:
	var current_text := sens_input.text.strip_edges()
	if current_text == "":
		sens_input.text = "%.2f" % sens_slider.value
	else:
		_on_sensitivity_input_submitted(current_text)

# ==========================================
# NEW: ACCESSIBILITY (BRIGHTNESS/CONTRAST/SATURATION)
# ==========================================

func _on_adjustment_changed(value: float, input_node: LineEdit) -> void:
	if not input_node.has_focus():
		input_node.text = "%.2f" % value
	_apply_visual_settings()

func _on_adjustment_drag_ended(value_changed: bool, setting_name: String, slider_node: HSlider) -> void:
	if value_changed:
		_save_setting_to_disk(setting_name, slider_node.value)

func _on_adjustment_input_submitted(new_text: String, setting_name: String, slider_node: HSlider) -> void:
	# Clamping color adjustments between 0.0 (dark/grey) and 3.0 (blown out) to prevent black screens
	var new_val: float = clamp(new_text.to_float(), 0.0, 3.0) 
	slider_node.value = new_val
	slider_node.release_focus()
	_save_setting_to_disk(setting_name, new_val)

func _on_adjustment_focus_entered(input_node: LineEdit) -> void:
	input_node.text = ""

func _on_adjustment_focus_exited(input_node: LineEdit, slider_node: HSlider, setting_name: String) -> void:
	var current_text := input_node.text.strip_edges()
	if current_text == "":
		input_node.text = "%.2f" % slider_node.value
	else:
		_on_adjustment_input_submitted(current_text, setting_name, slider_node)

func _apply_visual_settings() -> void:
	# This seeks out the active Environment in your game to apply the color changes
	var env_node: WorldEnvironment = get_tree().root.find_child("WorldEnvironment", true, false)
	if env_node and env_node.environment:
		env_node.environment.adjustment_enabled = true
		env_node.environment.adjustment_brightness = brightness_slider.value
		env_node.environment.adjustment_contrast = contrast_slider.value
		env_node.environment.adjustment_saturation = saturation_slider.value


# ==========================================
# RESOLUTION SYSTEM
# ==========================================

func _populate_resolution_dropdown() -> void:
	resolution_options.clear()
	for res_string: String in RESOLUTIONS.keys():
		resolution_options.add_item(res_string)

func _on_resolution_selected(index: int) -> void:
	var key: String = resolution_options.get_item_text(index)
	var new_size: Vector2i = RESOLUTIONS[key]
	
	DisplayServer.window_set_size(new_size)
	
	@warning_ignore("integer_division")
	var screen_center := DisplayServer.screen_get_position() + DisplayServer.screen_get_size() / 2
	@warning_ignore("integer_division")
	var window_position := screen_center - new_size / 2
	DisplayServer.window_set_position(window_position)
	
	_save_setting_to_disk("resolution_x", new_size.x)
	_save_setting_to_disk("resolution_y", new_size.y)
