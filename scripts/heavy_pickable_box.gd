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

func pick_up(target: Marker3D, player: Node3D) -> void:
	if is_locked or _is_animating: return
	
	# Unlock axes so the "Snap to Player" animation can rotate it correctly
	axis_lock_angular_x = false
	axis_lock_angular_z = false
		
	_is_animating = true
	holder = player
	if label: label.hide()

	if interact_comp:
		interact_comp.is_currently_focused = false
		interact_comp.unfocused.emit()
		
	# 1. Stun the player so they can't walk/look away during the animation
	if "is_stunned" in holder:
		holder.is_stunned = true

	# 2. Math: Find which of the 4 flat faces the player is closest to
	var to_player: Vector3 = global_position.direction_to(holder.global_position)
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

	# 3. Calculate exactly where the player should stand and look
	var target_stand_pos: Vector3 = global_position + (snap_normal * stand_distance)
	target_stand_pos.y = holder.global_position.y # Maintain original floor height
	
	var look_dir: Vector3 = -snap_normal
	var target_basis: Basis = Basis.looking_at(look_dir, Vector3.UP)

	# 4. Tween the player into position smoothly!
	var tween: Tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property(holder, "global_position", target_stand_pos, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(holder, "quaternion", target_basis.get_rotation_quaternion(), 0.4).set_trans(Tween.TRANS_SINE)
	
	# Center the camera tilt if the player was looking up or down
	if "eyes" in holder:
		tween.tween_property(holder.eyes, "rotation:x", 0.0, 0.4).set_trans(Tween.TRANS_SINE)

	# 5. When the animation finishes, lock it in
	tween.chain().tween_callback(_on_snap_complete.bind(target))

func _on_snap_complete(target: Marker3D) -> void:
	_is_animating = false
	is_heavy_held = true
	heavy_target = target
	
	_grab_time = Time.get_ticks_msec()
	freeze = false 
	gravity_scale = 1.0 
	
	# Now that we are perfectly snapped to the center, lock the offset!
	global_grab_offset = global_position - holder.global_position

	# Unstun the player, trigger the heavy lifting variables
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

	if holder:
		if "can_sprint" in holder:
			holder.can_sprint = true
		if "is_heavy_lifting" in holder:
			holder.is_heavy_lifting = false
			
		# --- THE FIX: Tell the player they are no longer holding anything! ---
		if "held_object" in holder:
			holder.held_object = null
		if "weapon_holder" in holder and holder.weapon_holder:
			holder.weapon_holder.show()
		# ---------------------------------------------------------------------

	if is_locked:
		holder = null
		if interact_comp: interact_comp.is_currently_focused = false
		return

	holder = null
	if interact_comp:
		interact_comp.is_currently_focused = false

func throw(_impulse_vector: Vector3) -> void:
	drop()

func _physics_process(_delta: float) -> void:
	if is_heavy_held and holder:
		# 1. STOP: Don't check stability while we are still snapping/animating!
		if _is_animating: return 

		var target_pos := holder.global_position + global_grab_offset
		
		if "direction" in holder and holder.direction.length() > 0.1:
			target_pos += holder.direction * 0.35
		
		var current_pos := global_position
		
		# Auto-drop if the box gets snagged
		if current_pos.distance_to(target_pos) > drop_distance:
			drop()
			return
			
		# ---------------------------------------------------------
		# THE BALANCE CHECK (With Stability Buffer)
		# ---------------------------------------------------------
		var grounded_points: int = 0
		var space_state := get_world_3d().direct_space_state
		
		if probe_container:
			for probe in probe_container.get_children():
				var p := probe as Node3D
				var ray_start: Vector3 = p.global_position + Vector3.UP * 0.2
				# Slightly longer ray (0.6) to handle small bumps in the floor
				var ray_end: Vector3 = p.global_position + Vector3.DOWN * 0.6
				
				var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
				query.exclude = [self.get_rid(), holder.get_rid()]
				query.collide_with_areas = false
				
				var result := space_state.intersect_ray(query)
				if not result.is_empty():
					var angle := rad_to_deg(Vector3.UP.angle_to(result.normal))
					if angle < 30.0: # Loosened angle slightly for stairs
						grounded_points += 1

		# ---------------------------------------------------------
		# THE BALANCE CHECK (Sled-Slide Mode)
		# ---------------------------------------------------------
		if grounded_points < 2:
			var lurch_dir: Vector3 = Vector3.ZERO
			if is_instance_valid(holder):
				lurch_dir = (holder.global_basis * Vector3.FORWARD).normalized()
			
			drop()
			
			# --- THE "SLED" FIX ---
			# Lock X and Z rotation so it cannot tip or roll.
			# It can still rotate around Y (yaw) if it bumps into a wall.
			axis_lock_angular_x = true
			axis_lock_angular_z = true
			
			var final_push := (lurch_dir if lurch_dir != Vector3.ZERO else Vector3.FORWARD)
			
			# Pure downward and forward force. NO torque impulse!
			apply_central_impulse(final_push * mass * 0.5 + Vector3.DOWN * mass * 2.0)
			return
		# MOVEMENT PHYSICS (Applying the forces)
		# ---------------------------------------------------------
		var distance_vector := Vector3(target_pos.x - current_pos.x, 0.0, target_pos.z - current_pos.z)
		var pull_strength: float = drag_speed * mass * 15.0
		apply_central_force(distance_vector * pull_strength)
		
		# Heavy downward force to keep it from bouncing
		apply_central_force(Vector3.DOWN * mass * 30.0)
		
		# XZ Friction
		var friction: float = 12.0 * mass
		apply_central_force(Vector3(-linear_velocity.x, 0.0, -linear_velocity.z) * friction)
		
		angular_velocity = Vector3.ZERO
