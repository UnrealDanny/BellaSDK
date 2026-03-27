@tool
extends StaticBody3D

@export_category("Connections")
@export var targets: Array[Node3D]

@export_category("Installation Settings")
@export var requires_installation: bool = false
@export var pickable_valve_scene: PackedScene 

@export var can_be_detached: bool = false:
	set(value):
		can_be_detached = value
		# Force Lock OFF if we make it detachable
		if can_be_detached: lock_when_finished = false

@export_category("Valve Settings")
@export var turn_duration: float = 3.0
@export var visual_rotations: float = 2.0
@export var turn_clockwise: bool = true

@export var lock_when_finished: bool = false:
	set(value):
		lock_when_finished = value
		# Force Detach OFF if we make it lockable
		if lock_when_finished: can_be_detached = false

@export var is_back_and_forth: bool = true:
	set(value):
		is_back_and_forth = value
		if is_back_and_forth: reverts_on_release = false

@export var reverts_on_release: bool = false:
	set(value):
		reverts_on_release = value
		if reverts_on_release: is_back_and_forth = false

@export var spin_axis: Vector3 = Vector3(0, 1, 0)
@export var label: Label3D

@export var outline_material: ShaderMaterial


var progress: float = 0.0
var is_focused: bool = false
var current_target_progress: float = 1.0
var is_locked: bool = false
var was_interacting: bool = false
var is_installed: bool = true

# --- NEW: DOUBLE TAP VARS ---
var last_interact_time: float = 0.0
const DOUBLE_TAP_DELAY: float = 0.3 # Seconds allowed between taps

var wheel: Node3D
var debug_line: MeshInstance3D
var initial_rotation: Vector3 
var highlight_comp: HighlightComponent

var install_cooldown: float = 0.0

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

	if requires_installation:
		is_installed = false
		if wheel: wheel.hide()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_draw_connection_line()
		return

	if install_cooldown > 0.0:
		install_cooldown -= delta

	if not is_installed:
		var player = get_tree().get_first_node_in_group("player")
		
		# THE FIX: Increased distance to 1.5. 0.5 was too small!
		if player and player.held_object is PickableValve and install_cooldown <= 0.0:
			var dist = global_position.distance_to(player.held_object.global_position)
			if dist < 1.5: 
				_install_valve(player)
		return

	# ... (keep your interaction/double-tap logic here) ...
	var is_interacting = is_focused and Input.is_action_pressed("interact")
	var just_pressed = is_focused and Input.is_action_just_pressed("interact")

	if can_be_detached and just_pressed:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_interact_time <= DOUBLE_TAP_DELAY:
			_detach_valve()
			last_interact_time = 0.0 
			return 
		else:
			last_interact_time = current_time

	# Because 'can_be_detached' forces 'lock_when_finished' to false, 
	# this will never block the double-tap!
	if is_locked: return
	
	if highlight_comp: highlight_comp.suppress(is_interacting)

	if is_interacting and not was_interacting:
		if is_back_and_forth and progress > 0.0 and progress < 1.0:
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
			
	was_interacting = is_interacting

# --- INSTALL AND DETACH FUNCTIONS ---
func _install_valve(player: Node3D) -> void:
	player.held_object.queue_free()
	player.held_object = null
	
	is_installed = true
	is_locked = false 
	progress = 0.0
	current_target_progress = 1.0
	
	if wheel: wheel.show()
	
	var weapon_holder = player.get_node_or_null("%WeaponHolder")
	if weapon_holder: weapon_holder.show()
	print("Valve Auto-Installed!")

func _detach_valve() -> void:
	if not pickable_valve_scene:
		push_warning("Cannot detach: No Pickable Valve Scene assigned!")
		return

	var player = get_tree().get_first_node_in_group("player")
	if not player: return

	var spawned_valve = pickable_valve_scene.instantiate()
	
	# --- FIX 1: THE OUTLINE ---
	# We must set this BEFORE adding it to the tree so _ready() can see it
	if outline_material:
		spawned_valve.outline_material = outline_material

	# --- FIX 2: THE SCALE GHOST ---
	# 1. Add to scene ONLY ONCE
	get_tree().current_scene.add_child(spawned_valve)
	
	# 2. Hard-reset the entire transform to stop it from inheriting socket scale
	spawned_valve.global_transform = Transform3D.IDENTITY
	spawned_valve.scale = Vector3.ONE

	# 3. Position it at the player's chest
	spawned_valve.global_position = player.global_position + Vector3(0, 1.2, 0)

	# 4. Hand it to the player
	player.held_object = spawned_valve
	spawned_valve.pick_up(player.hold_position, player)

	# --- RESET SOCKET STATE ---
	var weapon_holder = player.get_node_or_null("%WeaponHolder")
	if weapon_holder: weapon_holder.hide()

	is_installed = false
	is_locked = false
	progress = 0.0
	current_target_progress = 1.0
	install_cooldown = 1.0 

	for target in targets:
		if target and target.has_method("set_progress"):
			target.set_progress(0.0)

	if wheel: wheel.hide()

# --- INTERACT SIGNALS & DEBUG LINE ---
func _on_interact_component_focused() -> void:
	if is_locked: return 
	is_focused = true
	if label:
		_update_valve_label()
		label.show()

func _on_interact_component_unfocused() -> void:
	is_focused = false
	if label: label.hide()

func _draw_connection_line() -> void:
	if not targets or targets.is_empty():
		if debug_line: 
			debug_line.queue_free()
			debug_line = null 
		return

	if not debug_line:
		debug_line = MeshInstance3D.new()
		add_child(debug_line)
		debug_line.top_level = true 
		debug_line.global_transform = Transform3D.IDENTITY
		
		var immediate_mesh = ImmediateMesh.new()
		debug_line.mesh = immediate_mesh
		
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color.RED
		mat.no_depth_test = true 
		debug_line.material_override = mat

	var mesh = debug_line.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	for target in targets:
		if target:
			mesh.surface_add_vertex(global_position) 
			mesh.surface_add_vertex(target.global_position) 
	
	mesh.surface_end()

# --- THE DYNAMIC LABEL LOGIC ---
func _update_valve_label() -> void:
	if not label: return
	
	# 1. Get the current key name
	var events = InputMap.action_get_events("interact")
	var key_name = "???"
	
	if events.size() > 0:
		var raw_text = events[0].as_text()
		key_name = raw_text.replace(" (Physical)", "") \
						   .replace(" - Physical", "") \
						   .replace(" (Physics)", "") \
						   .replace(" - Physics", "") \
						   .replace("Left Mouse Button", "LMB") \
						   .replace("Right Mouse Button", "RMB") \
						   .replace("Middle Mouse Button", "MMB") \
						   .strip_edges()

	# 2. Build the string
	var text = "Hold [%s]" % key_name
	
	# Add the second line only if it's actually detachable
	if can_be_detached:
		text += "\nDouble tap [%s] to detach" % key_name
		
	label.text = text
