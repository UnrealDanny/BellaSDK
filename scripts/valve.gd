@tool
extends Node3D

@export_category("Connections")
@export var targets: Array[Node3D]
@export var valve_mesh: Node3D

@export_category("Valve Settings")
@export var turn_duration: float = 3.0

## If true, spins Clockwise. If false, spins Counter-Clockwise.
@export var turn_clockwise: bool = true

## If true, the valve acts as a toggle (Open -> Close -> Open). 
@export var is_back_and_forth: bool = true

## If true, letting go of the interact key causes the valve to spring back.
@export var reverts_on_release: bool = false

## NEW: If true, the valve permanently locks once it reaches 100%.
@export var lock_when_finished: bool = false

@export var visual_rotations: float = 2.0

var progress: float = 0.0
var is_focused: bool = false
var current_target_progress: float = 1.0
var is_locked: bool = false

# --- EDITOR DEBUG LINE ---
var debug_line: MeshInstance3D

func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	var interact_comp = get_node_or_null("StaticBody3D/Interact_Component") 
	
	if interact_comp:
		if not interact_comp.focused.is_connected(_on_interact_component_focused):
			interact_comp.focused.connect(_on_interact_component_focused)
			
		if not interact_comp.unfocused.is_connected(_on_interact_component_unfocused):
			interact_comp.unfocused.connect(_on_interact_component_unfocused)
	else:
		push_warning("Valve: Component missing! Make sure it is inside the StaticBody3D.")

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_draw_connection_line()
		return

	# If the valve is permanently locked, stop doing math completely!
	if is_locked:
		return

	# 1. Check if player is holding the button
	var is_interacting = is_focused and Input.is_action_pressed("interact")

	# 2. Handle Progress Logic
	if is_interacting:
		progress = move_toward(progress, current_target_progress, delta / turn_duration)
		
		# NEW: The Locking Mechanism
		if lock_when_finished and progress >= 1.0:
			is_locked = true
			progress = 1.0 # Guarantee it stays perfectly maxed out
			print("Valve hit 100% and is now PERMANENTLY LOCKED!")
			
	else:
		# Revert only if we aren't locked
		if reverts_on_release:
			var revert_target = 0.0 if current_target_progress == 1.0 else 1.0
			progress = move_toward(progress, revert_target, delta / turn_duration)
			
	# 3. Handle Back-and-Forth flip
	if is_back_and_forth and not is_interacting:
		if progress >= 1.0:
			current_target_progress = 0.0
		elif progress <= 0.0:
			current_target_progress = 1.0

	# 4. Apply Visual Rotation to the Valve Mesh
	if valve_mesh:
		# In 3D math, negative Z rotation is Clockwise. Positive is Counter-Clockwise.
		var dir_multiplier = -1.0 if turn_clockwise else 1.0

		# Change '.z' to '.x' or '.y' if your wheel model is facing a different direction!
		valve_mesh.rotation_degrees.z = lerp(0.0, 360.0 * visual_rotations * dir_multiplier, progress)

	# 5. SYNC WITH TARGETS
	for target in targets:
		if target and target.has_method("set_progress"):
			target.set_progress(progress)

# --- INTERACT SIGNALS ---
func _on_interact_component_focused() -> void:
	# Don't show the prompt if it's already locked!
	if is_locked: return 

	is_focused = true
	print("Valve is focused! Press E to turn.")

func _on_interact_component_unfocused() -> void:
	is_focused = false

# --- EDITOR DEBUG LINE ---
func _draw_connection_line() -> void:
	if not targets or targets.is_empty():
		if debug_line: debug_line.queue_free()
		return

	if not debug_line:
		debug_line = MeshInstance3D.new()
		add_child(debug_line)
		var immediate_mesh = ImmediateMesh.new()
		debug_line.mesh = immediate_mesh
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color.RED
		debug_line.material_override = mat

	var mesh = debug_line.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	for target in targets:
		if target:
			mesh.surface_add_vertex(Vector3.ZERO) 
			mesh.surface_add_vertex(to_local(target.global_position)) 
	
	mesh.surface_end()
