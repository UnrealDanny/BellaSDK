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
	# Instead of dictionary management every frame, 
	# we only run the focus/unfocus logic when the state actually changes.
	
	# Check if the last hover update was within the current or previous frame
	var is_hovered := false
	var current_frame := Engine.get_process_frames()
	
	for character: CharacterBody3D in characters_hovering:
		if current_frame - characters_hovering[character] <= 1:
			is_hovered = true
			break
			
	# Handle the Outline Shader Signals only when needed
	if is_hovered != is_currently_focused:
		is_currently_focused = is_hovered
		if is_currently_focused:
			focused.emit()
		else:
			unfocused.emit()
