@tool
extends StaticBody3D

@export_category("Connections")
## Click 'Array[Node3D]' to link objects like doors or gates to this valve!
@export var targets: Array[Node3D]

@export_category("Valve Settings")
@export var turn_duration: float = 3.0
@export var visual_rotations: float = 2.0
@export var turn_clockwise: bool = true
@export var lock_when_finished: bool = false
@export var is_back_and_forth: bool = true:
	set(value):
		is_back_and_forth = value
		# If we turn this ON, force the other OFF
		if is_back_and_forth:
			reverts_on_release = false

@export var reverts_on_release: bool = false:
	set(value):
		reverts_on_release = value
		# If we turn this ON, force the other OFF
		if reverts_on_release:
			is_back_and_forth = false

## Set ONE of these to 1.0 to choose the spin direction. (e.g., X=0, Y=1, Z=0)
@export var spin_axis: Vector3 = Vector3(0, 1, 0)

var progress: float = 0.0
var is_focused: bool = false
var current_target_progress: float = 1.0
var is_locked: bool = false

# NEW: We need to remember if we were holding it last frame!
var was_interacting: bool = false

var wheel: Node3D
var debug_line: MeshInstance3D
var initial_rotation: Vector3 
var highlight_comp: HighlightComponent

func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	wheel = get_node_or_null("Wheel")
	if wheel:
		initial_rotation = wheel.rotation_degrees
	else:
		push_warning("Valve: Please group your meshes under a Node3D named 'Wheel'!")
		
	highlight_comp = get_node_or_null("HighlightComponent")
	
	var interact_comp = get_node_or_null("Interact_Component") 
	if interact_comp:
		if not interact_comp.focused.is_connected(_on_interact_component_focused):
			interact_comp.focused.connect(_on_interact_component_focused)
			
		if not interact_comp.unfocused.is_connected(_on_interact_component_unfocused):
			interact_comp.unfocused.connect(_on_interact_component_unfocused)
	else:
		push_warning("Valve: Interact_Component missing!")

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_draw_connection_line()
		return

	if is_locked: return

	var is_interacting = is_focused and Input.is_action_pressed("interact")
	
	if highlight_comp:
		highlight_comp.suppress(is_interacting)

	# --- NEW: THE MID-TURN REVERSAL ---
	# If we just started a NEW interaction, and the valve is stuck in the middle...
	if is_interacting and not was_interacting:
		if is_back_and_forth and progress > 0.0 and progress < 1.0:
			# Flip the target!
			current_target_progress = 0.0 if current_target_progress == 1.0 else 1.0

	# Standard Movement Logic
	if is_interacting:
		progress = move_toward(progress, current_target_progress, delta / turn_duration)
		if lock_when_finished and progress >= 1.0:
			is_locked = true
			progress = 1.0 
	else:
		if reverts_on_release:
			var revert_target = 0.0 if current_target_progress == 1.0 else 1.0
			progress = move_toward(progress, revert_target, delta / turn_duration)
			
	if is_back_and_forth and not is_interacting:
		if progress >= 1.0: current_target_progress = 0.0
		elif progress <= 0.0: current_target_progress = 1.0

	if wheel:
		var dir_multiplier = -1.0 if turn_clockwise else 1.0
		var total_angle = 360.0 * visual_rotations * dir_multiplier * progress
		wheel.rotation_degrees = initial_rotation + (spin_axis * total_angle)

	for target in targets:
		if target and target.has_method("set_progress"):
			target.set_progress(progress)
			
	# Save this frame's interaction state for the next frame
	was_interacting = is_interacting

# --- INTERACT SIGNALS ---
func _on_interact_component_focused() -> void:
	if is_locked: return 
	is_focused = true

func _on_interact_component_unfocused() -> void:
	is_focused = false

# --- EDITOR DEBUG LINE ---
func _draw_connection_line() -> void:
	if not targets or targets.is_empty():
		if debug_line: 
			debug_line.queue_free()
			# Important: clear the reference so it can be recreated later if needed!
			debug_line = null 
		return

	if not debug_line:
		debug_line = MeshInstance3D.new()
		add_child(debug_line)
		debug_line.top_level = true 
		
		# --- THE FIX ---
		# Lock the mesh perfectly to the center of the world so global coordinates work!
		debug_line.global_transform = Transform3D.IDENTITY
		# ---------------
		
		var immediate_mesh = ImmediateMesh.new()
		debug_line.mesh = immediate_mesh
		
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color.RED
		mat.no_depth_test = true # Optional: Makes the line visible through walls!
		debug_line.material_override = mat

	var mesh = debug_line.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	for target in targets:
		if target:
			mesh.surface_add_vertex(global_position) 
			mesh.surface_add_vertex(target.global_position) 
	
	mesh.surface_end()
