extends RigidBody3D
class_name PickableObject

@export_category("Pickable Nodes")
@export var interact_comp: Interact_Component
@export var mesh: MeshInstance3D
@export var label: Label3D
#@export var outline_material: ShaderMaterial

@export_category("Buoyancy")
@export var probe_container: Node3D 
## How strongly the water pushes up. (3.0 is a great value!)
@export var float_force: float = 3.0
## Friction. (Because we fixed the math, you may need to increase this to 2.0 or 4.0 to stop bouncing!)
@export var water_drag: float = 0.5
@export var water_angular_drag: float = 0.5

var is_held: bool = false
var hold_target: Marker3D = null
var holder: Node3D = null
var _grab_time: int = 0 

# --- WATER TRACKING ---
var is_in_water: bool = false
var submerged: bool = false
var current_water_node: Node3D = null 

@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var is_locked: bool = false:
	set(value):
		is_locked = value
		if is_locked:
			if mesh: mesh.material_overlay = null
			if label: label.hide()

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	if label: label.hide()
	
	if interact_comp:
		if not interact_comp.focused.is_connected(_on_interact_component_focused):
			interact_comp.focused.connect(_on_interact_component_focused)
		if not interact_comp.unfocused.is_connected(_on_interact_component_unfocused):
			interact_comp.unfocused.connect(_on_interact_component_unfocused)

func pick_up(target: Marker3D, player: Node3D) -> void:
	if is_locked: return
	_grab_time = Time.get_ticks_msec()
	is_held = true
	hold_target = target
	holder = player
	if label: label.hide()
	
	PhysicsServer3D.body_set_state(self.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, target.global_transform)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = false 
	gravity_scale = 0.0 
	if mesh: mesh.transparency = 0.25

	if interact_comp:
		interact_comp.is_currently_focused = false
		interact_comp.unfocused.emit()
		# --- NEW: Disable interaction while holding ---
		interact_comp.process_mode = Node.PROCESS_MODE_DISABLED 
		
	add_collision_exception_with(holder)
	
func drop() -> void:
	if Time.get_ticks_msec() - _grab_time < 100: return
	is_held = false
	
	if interact_comp: 
		# --- NEW: Re-enable interaction ---
		interact_comp.process_mode = Node.PROCESS_MODE_INHERIT
	
	if is_locked:
		holder = null
		if interact_comp: interact_comp.is_currently_focused = false
		return
		
	freeze = false 
	gravity_scale = 1.0 
	if mesh: mesh.transparency = 0.0

	if holder:
		if "velocity" in holder:
			linear_velocity = holder.velocity

		# FIX 1: Flatten the camera vector to the XZ plane. 
		# This guarantees the box pushes horizontally outward, even if you look straight down.
		var cam_forward: Vector3 = -holder.cam.global_transform.basis.z
		var push_dir := Vector3(cam_forward.x, 0.0, cam_forward.z).normalized()
		push_dir.y = 0.5 # Give it a slight upward toss
		apply_central_impulse(push_dir * 3.0)

		# FIX 2: Safely check for distance instead of using a blind 0.2s timer.
		var previous_holder := holder
		_attempt_enable_collision(previous_holder)
	
	holder = null
	if interact_comp:
		interact_comp.is_currently_focused = false


# --- NEW FUNCTION ---
func _attempt_enable_collision(player: Node3D) -> void:
	if not is_instance_valid(self) or not is_instance_valid(player): 
		return

	# Check the distance between the box and the player
	var distance := global_position.distance_to(player.global_position)

	# 1.5 meters is usually safe, but you can increase this if your player has a wide collision shape
	if distance > 1.5:
		remove_collision_exception_with(player)
	else:
		# If they are still overlapping, wait 0.1s and recursively check again. 
		# This allows you to walk away from the box without getting teleported!
		get_tree().create_timer(0.1).timeout.connect(_attempt_enable_collision.bind(player))

func throw(impulse_vector: Vector3) -> void:
	drop()
	if not is_locked:
		apply_central_impulse(impulse_vector)

func _on_interact_component_focused() -> void:
	if is_locked: return
	
	# 1. If we are holding it, NO highlight and NO label. Bail out!
	if is_held:
		if mesh: mesh.material_overlay = null
		return
		
	# 2. Only apply highlight if NOT held.
	#if mesh and outline_material: 
		#mesh.material_overlay = outline_material
		
	# 3. Show the label
	if label:
		_update_label_text()
		label.show()

func _update_label_text() -> void:
	if not label: return
	var events := InputMap.action_get_events("interact")
	var key_name := "???"
	if events.size() > 0:
		var raw_text := events[0].as_text()
		key_name = raw_text.replace(" (Physical)", "").replace(" - Physical", "").replace(" (Physics)", "").replace(" - Physics", "").replace("Left Mouse Button", "LMB").replace("Right Mouse Button", "RMB").replace("Middle Mouse Button", "MMB").strip_edges()
	label.text = "[%s]" % [key_name]
		
func _on_interact_component_unfocused() -> void:
	#if mesh: mesh.material_overlay = null
	if label: label.hide()

func _physics_process(_delta: float) -> void:
	# 1. HOLDING LOGIC
	if is_held and hold_target:
		var distance_vector := hold_target.global_position - global_position
		linear_velocity = distance_vector * 20.0
		
		var diff_quat := hold_target.global_basis.get_rotation_quaternion() * global_basis.get_rotation_quaternion().inverse()
		var axis := Vector3(diff_quat.x, diff_quat.y, diff_quat.z)
		var angle := 2.0 * acos(clamp(diff_quat.w, -1.0, 1.0))
		if angle > PI: angle -= TAU
			
		if axis.length_squared() > 0.0001:
			angular_velocity = axis.normalized() * (angle * 20.0)
		else:
			angular_velocity = Vector3.ZERO
		return

	# 2. MULTI-PROBE BUOYANCY
	submerged = false
	
	if is_in_water and is_instance_valid(current_water_node) and probe_container:
		var probe_count: int = probe_container.get_child_count()
		var probe_mass: float = mass / float(probe_count)
		
		for p in probe_container.get_children():
			var wave_height: float = current_water_node.get_wave_height_at_pos(p.global_position)
			var depth: float = wave_height - p.global_position.y 
			
			if depth > 0:
				submerged = true
				
				# --- THE SURFACE & PLUNGE FIX ---
				# Multiply depth by 4.0: Reaches neutral buoyancy at just 0.25 meters deep!
				# Clamp at 4.0: If pulled deep, it fights back 4x harder to overpower the drag of 6.0!
				var depth_multiplier: float = clamp(depth * 4.0, 0.0, 4.0)
				
				var force: Vector3 = Vector3.UP * probe_mass * float_force * gravity * depth_multiplier
				var offset: Vector3 = p.global_position - global_position
				apply_force(force, offset)

	# 3. DRAG
	if submerged and not is_held:
		apply_central_force(-linear_velocity * water_drag * mass)
		apply_torque(-angular_velocity * water_angular_drag * mass)
