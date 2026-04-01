extends CanvasLayer

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var options: Panel = $Options
@onready var controls_panel: Panel = $ControlsPanel

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

func _ready() -> void:
	# 1. Load from file first!
	load_controls() 
	
	# 2. Then set up the UI
	main_buttons.visible = true
	options.visible = false
	controls_panel.visible = false
	create_control_list()

func create_control_list() -> void:
	var container := $ControlsPanel/VBoxContainer
	var template := $ControlsPanel/VBoxContainer/RemapButtonTemplate
	
	for action: String in my_actions:
		# 1. Duplicate the template button
		var new_button := template.duplicate()
		new_button.show()
		container.add_child(new_button)
		
		# 2. Store the action name inside the button itself using metadata
		new_button.set_meta("action", action)
		
		# 3. Label the button (e.g., "Jump: Space")
		update_button_text(new_button, action)
		
		# 4. Connect the signal to one shared function
		new_button.toggled.connect(_on_any_remap_button_toggled.bind(new_button))

func _on_any_remap_button_toggled(toggled_on: bool, button: Button) -> void:
	if toggled_on:
		is_remapping = true
		remapping_button = button
		action_to_remap = button.get_meta("action")
		button.text = "Press any key..."
	else:
		is_remapping = false
		pending_swap_event = null # Clear any pending swaps!
		update_button_text(button, button.get_meta("action"))

func update_button_text(button: Button, action: String) -> void:
	var events := InputMap.action_get_events(action)
	var key_name := "Unassigned"
	
	if events.size() > 0:
		var raw_text := events[0].as_text()
		
		# Chain together .replace() to hunt down and destroy any weird formatting Godot tries to use
		key_name = raw_text.replace(" (Physical)", "") \
						   .replace(" - Physical", "") \
						   .replace(" (Physics)", "") \
						   .replace(" - Physics", "") \
						   .strip_edges()
						
	button.text = action.capitalize() + ": " + key_name

func _on_start_game_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/testbed.tscn")
	
func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_options_pressed() -> void:
	main_buttons.visible = false
	options.visible = true
	controls_panel.visible = false

func _on_back_pressed() -> void:
	main_buttons.visible = true
	options.visible = false
	controls_panel.visible = false

func _on_contols_pressed() -> void:
	options.visible = false
	controls_panel.visible = true

func _on_back_controls_pressed() -> void:
	options.visible = true
	controls_panel.visible = false
		
func _input(event: InputEvent) -> void:
	if is_remapping:
		if event is InputEventKey or event is InputEventMouseButton:
			if event.is_pressed():
				
				# 1. Did they press the exact same key again to confirm a swap?
				if pending_swap_event != null and event.as_text() == pending_swap_event.as_text():
					execute_swap(event)
					return
				
				# 2. Check for conflicts
				var conflicting_action := get_action_with_event(event)
				
				if conflicting_action != "" and conflicting_action != action_to_remap:
					# Save the state so we know what to swap if they press it again
					pending_swap_event = event
					pending_conflict_action = conflicting_action
					
					var key_name := event.as_text().split("(")[0].strip_edges()
					%ConflictLabel.text = action_to_remap.capitalize() + " and " + conflicting_action.capitalize() + " use the same key. \nPress [" + key_name + "] again to switch, or press a different key."
					%ConflictPanel.show()
					
					get_tree().create_timer(4.0).timeout.connect(func() -> void: %ConflictPanel.hide())
					get_viewport().set_input_as_handled()
					return 

				# 3. If no conflict, proceed as normal
				InputMap.action_erase_events(action_to_remap)
				InputMap.action_add_event(action_to_remap, event)
				
				save_controls() 
				
				is_remapping = false
				pending_swap_event = null # Clear memory
				remapping_button.button_pressed = false
				update_button_text(remapping_button, action_to_remap)
				
				%ConflictPanel.hide()
				get_viewport().set_input_as_handled()

func _on_reset_button_pressed() -> void:
	InputMap.load_from_project_settings()
	
	# Delete the save file so it doesn't reload old custom keys next boot
	var dir := DirAccess.open("user://")
	if dir.file_exists("controls.cfg"):
		dir.remove("controls.cfg")
		
	refresh_all_button_labels()

func refresh_all_button_labels() -> void:
	var container := $ControlsPanel/VBoxContainer
	
	# Loop through every child in the container
	for child in container.get_children():
		# Make sure we only talk to the buttons we generated, not the template!
		if child is Button and child.has_meta("action"):
			var action_name: String = child.get_meta("action")
			update_button_text(child, action_name)

const SAVE_PATH = "user://controls.cfg"

func save_controls() -> void:
	var config := ConfigFile.new()
	
	for action: String in my_actions:
		var events := InputMap.action_get_events(action)
		if events.size() > 0:
			# We save the first event assigned to this action
			config.set_value("Controls", action, events[0])
	
	config.save(SAVE_PATH)
	print("Controls saved to: ", OS.get_user_data_dir())

func load_controls() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	
	# If the file doesn't exist yet (first time playing), just stop
	if err != OK: 
		return 

	for action: String in my_actions:
		if config.has_section_key("Controls", action):
			var event := config.get_value("Controls", action) as InputEvent
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, event)
			
func get_action_with_event(new_event: InputEvent) -> String:
	for action: String in my_actions:
		# We check if the existing action already has this exact key/button
		if InputMap.action_has_event(action, new_event):
			return action
	return ""

func execute_swap(new_event: InputEvent) -> void:
	# 1. Grab the old key from the button we are currently remapping
	var old_events := InputMap.action_get_events(action_to_remap)
	var old_event := old_events[0] if old_events.size() > 0 else null
	
	# 2. Clear both actions in Godot's Input Map
	InputMap.action_erase_events(action_to_remap)
	InputMap.action_erase_events(pending_conflict_action)
	
	# 3. Give the new key to our current action
	InputMap.action_add_event(action_to_remap, new_event)
	
	# 4. Give the old key to the action we stole from
	if old_event:
		InputMap.action_add_event(pending_conflict_action, old_event)
		
	save_controls()
	
	# 5. Cleanup UI and State
	is_remapping = false
	pending_swap_event = null
	pending_conflict_action = ""
	remapping_button.button_pressed = false
	
	# Use the refresh function we made for the Reset button, since TWO buttons just changed!
	refresh_all_button_labels() 
	
	# 6. Show a nice success message
	%ConflictLabel.text = "Keys swapped successfully!"
	%ConflictPanel.show()
	get_tree().create_timer(2.0).timeout.connect(func() -> void: %ConflictPanel.hide())
	
	get_viewport().set_input_as_handled()

func _on_resume_pressed() -> void:
	# Since the player is the parent of this menu instance:
	if get_parent().has_method("toggle_pause"):
		get_parent().toggle_pause()
