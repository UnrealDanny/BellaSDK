extends PickableObject
class_name HeavyPickableBox

var is_heavy_held: bool = false
var _is_animating: bool = false
var heavy_target: Marker3D = null

var global_grab_offset: Vector3 = Vector3.ZERO

@export var drag_speed: float = 10.0 
@export var drop_distance: float = 3.5 
@export var stand_distance: float = 1.3 ## How far from the center of the box the player should stand

@export_category("Box Dimensions")
@export var box_half_height: float = 1.5 ## Distance from center to bottom
@export var box_half_width: float = 1.5  ## Distance from center to the side edges

@export_category("Player Clearance Check")
@export var player_radius: float = 0.4 ## The radius of your player's collision shape
@export var player_height: float = 1.8 ## The height of your player's collision shape
@export_flags_3d_physics var environment_collision_mask: int = 1 ## Set this to the layer your walls/static bodies are on

func pick_up(target: Marker3D, player: Node3D) -> void:
	if is_locked or _is_animating: return
	
	# 1. Math FIRST: Find which of the 4 flat faces the player is closest to
	var to_player: Vector3 = global_position.direction_to(player.global_position)
	to_player.y = 0
	to_player = to_player.normalized()

	var box_fwd: Vector3 = -global_transform.basis.z.normalized()
	var box_right: Vector3 = global_transform.basis.x.normalized()

	var dot_fwd: float = to_player.dot(box_fwd)
	var dot_right: float = to_player.dot(box_right)

	var snap_normal: Vector3
	if abs(dot_fwd) > abs(dot_right):
		snap_normal = box_fwd if dot_fwd > 0 else -box_fwd
	else:
		snap_normal = box_right if dot_right > 0 else -box_right

	# 2. Calculate exactly where the player should stand and look
	var target_stand_pos: Vector3 = global_position + (snap_normal * stand_distance)
	target_stand_pos.y = player.global_position.y # Maintain original floor height
	
	# 3. Space Clearance Check
	var space_state := get_world_3d().direct_space_state
	var clearance_shape := CapsuleShape3D.new()
	clearance_shape.radius = player_radius
	clearance_shape.height = player_height
	
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = clearance_shape
	var shape_origin := target_stand_pos + Vector3(0.0, (player_height / 2.0) + 0.1, 0.0)
	query.transform = Transform3D(Basis(), shape_origin)
	query.collision_mask = environment_collision_mask
	query.exclude = [self.get_rid(), player.get_rid()]
	
	var hits := space_state.intersect_shape(query)
	if not hits.is_empty():
		return # Blocked by wall, abort grab
		
	_is_animating = true
	holder = player
	if label: label.hide()

	if interact_comp:
		interact_comp.is_currently_focused = false
		interact_comp.unfocused.emit()
		interact_comp.process_mode = Node.PROCESS_MODE_DISABLED 
		
	if "is_stunned" in holder:
		holder.is_stunned = true

	# OVERRIDE PARENT: Keep gravity ON so it doesn't float!
	freeze = false 
	gravity_scale = 1.0  
	add_collision_exception_with(holder)

	# 4. Tween the player into position smoothly
	var look_dir: Vector3 = -snap_normal
	var target_basis: Basis = Basis.looking_at(look_dir, Vector3.UP)

	var tween: Tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property(holder, "global_position", target_stand_pos, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(holder, "quaternion", target_basis.get_rotation_quaternion(), 0.4).set_trans(Tween.TRANS_SINE)
	
	if "eyes" in holder:
		tween.tween_property(holder.eyes, "rotation:x", 0.0, 0.4).set_trans(Tween.TRANS_SINE)

	tween.chain().tween_callback(_on_snap_complete.bind(target))

func _on_snap_complete(target: Marker3D) -> void:
	_is_animating = false
	is_heavy_held = true
	heavy_target = target
	
	_grab_time = Time.get_ticks_msec()
	
	global_grab_offset = global_position - holder.global_position
	
	# LOCK IT DOWN: Box is a sled, it never rolls.
	axis_lock_angular_x = true
	axis_lock_angular_z = true

	if "is_stunned" in holder:
		holder.is_stunned = false
	if "can_sprint" in holder:
		holder.can_sprint = false
	if "is_heavy_lifting" in holder:
		holder.is_heavy_lifting = true

func drop() -> void:
	if Time.get_ticks_msec() - _grab_time < 100 or _is_animating:
		return
		
	is_heavy_held = false
	freeze = false 
	gravity_scale = 1.0 

	# Keep it locked when dropped so it slides flat
	axis_lock_angular_x = true
	axis_lock_angular_z = true

	if holder:
		if "can_sprint" in holder:
			holder.can_sprint = true
		if "is_heavy_lifting" in holder:
			holder.is_heavy_lifting = false
			
		if "held_object" in holder:
			holder.held_object = null
		if "weapon_holder" in holder and holder.weapon_holder:
			holder.weapon_holder.show()
			
		var previous_holder := holder
		_attempt_enable_collision(previous_holder)

	if is_locked:
		holder = null
		if interact_comp: interact_comp.is_currently_focused = false
		return

	holder = null
	if interact_comp:
		interact_comp.process_mode = Node.PROCESS_MODE_INHERIT
		interact_comp.is_currently_focused = false

func throw(_impulse_vector: Vector3) -> void:
	drop()

func _physics_process(_delta: float) -> void:
	if is_heavy_held and holder:
		if _is_animating: return 

		# ---------------------------------------------------------
		# 1. AUTO-DETACH LOGIC (Stairs & Abyss)
		# ---------------------------------------------------------
		var box_bottom_y: float = global_position.y - box_half_height
		
		# Stop player from pulling it UP steep stairs
		var is_too_high: bool = holder.global_position.y > box_bottom_y + 0.3
		
		# If velocity is highly negative, it's plummeting off a ledge
		var is_falling: bool = linear_velocity.y < -2.5

		if is_too_high or is_falling:
			var lurch_dir := (global_position - holder.global_position).normalized()
			lurch_dir.y = 0.0
			
			drop()
			
			# Give it a small central nudge when falling so it naturally clears the ledge
			if is_falling:
				apply_central_impulse(lurch_dir * mass * 1.5)
			return

		# ---------------------------------------------------------
		# 2. POSITION VARIABLES
		# ---------------------------------------------------------
		var target_pos := holder.global_position + global_grab_offset
		if "direction" in holder and holder.direction.length() > 0.1:
			target_pos += holder.direction * 0.35
			
		var current_pos := global_position
		
		# Snag check
		if current_pos.distance_to(target_pos) > drop_distance:
			drop()
			return

		# ---------------------------------------------------------
		# 3. STRICT X/Z PULLING (No lifting)
		# ---------------------------------------------------------
		var distance_vector := Vector3(target_pos.x - current_pos.x, 0.0, target_pos.z - current_pos.z)
		var pull_strength: float = drag_speed * mass * 15.0
		
		apply_central_force(distance_vector * pull_strength)
		
		# Heavy X/Z Friction to keep it from behaving like a pendulum
		var friction: float = 12.0 * mass
		apply_central_force(Vector3(-linear_velocity.x, 0.0, -linear_velocity.z) * friction)
		
		# ZERO out angular velocity to stop Godot's physics engine from 
		# jittering the box when it scrapes against stair edges
		angular_velocity = Vector3.ZERO
