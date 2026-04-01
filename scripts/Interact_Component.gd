@tool
class_name Interact_Component
extends Node

signal interacted(character: CharacterBody3D)
signal focused()
signal unfocused()

var characters_hovering := {}
var is_currently_focused := false
var last_hit_position := Vector3.ZERO # NEW: Store the exact hit point

func interact_with(character: CharacterBody3D) -> void:
	interacted.emit(character)

# NEW: Accept a hit_position argument
func hover_cursor(character : CharacterBody3D, hit_position : Vector3) -> void:
	characters_hovering[character] = Engine.get_process_frames()
	# Store the point we received from the player
	last_hit_position = hit_position
	
func get_character_hovered_by_cur_camera() -> CharacterBody3D:
	# ... (keep your existing camera check code) ...
	return null

func _process(_delta: float) -> void:
	# 1. Find stale hovers safely
	var characters_to_remove := []
	for character: CharacterBody3D in characters_hovering.keys():
		if Engine.get_process_frames() - characters_hovering[character] > 1:
			characters_to_remove.append(character)
			
	# 2. Erase them
	for character: CharacterBody3D in characters_to_remove:
		characters_hovering.erase(character)
		
	# 3. Handle the Outline Shader Signals
	var should_be_focused := characters_hovering.size() > 0
	
	# If someone is looking, and we aren't glowing yet, start glowing!
	if should_be_focused and not is_currently_focused:
		is_currently_focused = true
		focused.emit()
		
	# If no one is looking, but we are still glowing, stop glowing!
	elif not should_be_focused and is_currently_focused:
		is_currently_focused = false
		unfocused.emit()
