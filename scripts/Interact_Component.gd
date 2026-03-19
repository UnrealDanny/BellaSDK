class_name Interact_Component
extends Node

signal interacted()
signal focused()     # NEW
signal unfocused()   # NEW

var characters_hovering = {}
var is_currently_focused = false # Tracks the state to prevent signal spam

func interact_with():
	interacted.emit()
func hover_cursor(character : CharacterBody3D):
	characters_hovering[character] = Engine.get_process_frames()
	
func get_character_hovered_by_cur_camera() -> CharacterBody3D:
	for character in characters_hovering.keys():
		var cur_camera = get_viewport().get_camera_3d() if get_viewport() else null
		if cur_camera in character.find_children("*", "Camera3D"):
			return character
	return null
	
func _process(_delta):
	# 1. Find stale hovers safely
	var characters_to_remove = []
	for character in characters_hovering.keys():
		if Engine.get_process_frames() - characters_hovering[character] > 1:
			characters_to_remove.append(character)
			
	# 2. Erase them
	for character in characters_to_remove:
		characters_hovering.erase(character)
		
	# 3. Handle the Outline Shader Signals
	var should_be_focused = characters_hovering.size() > 0
	
	# If someone is looking, and we aren't glowing yet, start glowing!
	if should_be_focused and not is_currently_focused:
		is_currently_focused = true
		focused.emit()
		
	# If no one is looking, but we are still glowing, stop glowing!
	elif not should_be_focused and is_currently_focused:
		is_currently_focused = false
		unfocused.emit()
