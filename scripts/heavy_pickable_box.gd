extends PickableObject
class_name HeavyPickableBox

var is_heavy_held: bool = false
var _is_animating: bool = false

@export_group("Movement Settings")
@export var drag_speed: float = 12.0 # How fast the box catches up to you
@export var drop_distance: float = 3.5 
@export var snap_duration: float = 0.3

@export_group("Box Dimensions")
@export var box_half_width: float = 1.0 # Adjust to match your mesh size

@export_group("Player Settings")
@export var player_radius: float = 0.5 
@export var player_height: float = 1.8 
@export_flags_3d_physics var environment_collision_mask: int = 1 

func pick_up(_target: Marker3D, player: Node3D) -> void:
	if is_locked or _is_animating: return
	
	# 1. Determine which side the player is on
	var to_player := (player.global_position - global_position)
	to_player.y = 0
	to_player = to_player.normalized()

	# Get box axes
	var b_fwd := -global_transform.basis.z.normalized()
	var b_right := global_transform.basis.x.normalized()

	# Find the closest cardinal face of the box
	var snap_normal: Vector3
	if abs(to_player.dot(b_fwd)) > abs(to_player.dot(b_right)):
		snap_normal = b_fwd if to_player.dot(b_fwd) > 0 else -b_fwd
	else:
		snap_normal = b_right if to_player.dot(b_right) > 0 else -b_right

	# 2. Calculate where the player should stand (outside the box)
	var distance_from_center := box_half_width + player_radius + 0.2
	var target_stand_pos := global_position + (snap_normal * distance_from_center)
	target_stand_pos.y = player.global_position.y 

	# 3. Quick clearance check
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = player_radius
	shape.height = player_height
	query.shape = shape
	query.transform = Transform3D(Basis(), target_stand_pos + Vector3(0, player_height/2, 0))
	query.collision_mask = environment_collision_mask
	query.exclude = [self.get_rid(), player.get_rid()]

	if not space_state.intersect_shape(query).is_empty():
		return # Blocked by a wall

	# 4. Start Snap Animation
	_is_animating = true
	holder = player
	
	if "is_stunned" in holder: holder.is_stunned = true
	if interact_comp: interact_comp.process_mode = Node.PROCESS_MODE_DISABLED

	add_collision_exception_with(holder)
	
	var look_at_box_basis := Basis.looking_at(-snap_normal, Vector3.UP)
	var tween := get_tree().create_tween().set_parallel(true)
	tween.tween_property(holder, "global_position", target_stand_pos, snap_duration)
	tween.tween_property(holder, "quaternion", look_at_box_basis.get_rotation_quaternion(), snap_duration)
	
	tween.chain().tween_callback(_finish_pickup)

func _finish_pickup() -> void:
	_is_animating = false
	is_heavy_held = true
	_grab_time = Time.get_ticks_msec()
	
	if "is_stunned" in holder: holder.is_stunned = false
	if "is_heavy_lifting" in holder: holder.is_heavy_lifting = true

func _physics_process(_delta: float) -> void:
	if is_heavy_held and holder:
		if _is_animating: return

		# 1. Calculate the target position (directly in front of player)
		# We use the player's forward vector to determine where the box should be
		var player_fwd := -holder.global_transform.basis.z.normalized()
		var follow_distance := box_half_width + player_radius + 0.2
		var target_pos := holder.global_position + (player_fwd * follow_distance)
		
		# Keep the box on its own Y level (prevents player from lifting it)
		target_pos.y = global_position.y 

		# 2. Distance Check (Safety Drop)
		var dist := global_position.distance_to(target_pos)
		if dist > drop_distance:
			drop()
			return

		# 3. Movement Physics
		# Wake up the physics body
		sleeping = false
		
		# Calculate the velocity needed to reach the target
		var vec_to_target := (target_pos - global_position)
		var desired_velocity := vec_to_target * drag_speed
		
		# Apply force to reach that velocity (more reliable than just apply_force)
		var velocity_diff := desired_velocity - linear_velocity
		velocity_diff.y = 0 # Don't interfere with gravity
		
		apply_central_force(velocity_diff * mass * 10.0)

func drop() -> void:
	if _is_animating: return
	
	is_heavy_held = false
	if holder:
		if "is_heavy_lifting" in holder: holder.is_heavy_lifting = false
		remove_collision_exception_with(holder)
		
		# Re-enable interaction so we can pick it up again
		if interact_comp:
			interact_comp.process_mode = Node.PROCESS_MODE_INHERIT
			
	holder = null

func throw(_impulse: Vector3) -> void:
	drop() # Heavy boxes are too heavy to throw



#extends PickableObject
#class_name HeavyPickableBox
#
#var is_heavy_held: bool = false
#var _is_animating: bool = false
#var heavy_target: Marker3D = null
#
#var global_grab_offset: Vector3 = Vector3.ZERO
#
#@export var drag_speed: float = 10.0 
#@export var drop_distance: float = 3.5 
#@export var stand_distance: float = 1.3 ## How far from the center of the box the player should stand
#
#@export_category("Box Dimensions")
#@export var box_half_height: float = 1.5 ## Distance from center to bottom
#@export var box_half_width: float = 1.5  ## Distance from center to the side edges
#
#@export_category("Player Clearance Check")
#@export var player_radius: float = 0.4 ## The radius of your player's collision shape
#@export var player_height: float = 1.8 ## The height of your player's collision shape
#@export_flags_3d_physics var environment_collision_mask: int = 1 ## Set this to the layer your walls/static bodies are on
#
#func pick_up(target: Marker3D, player: Node3D) -> void:
	#if is_locked or _is_animating: return
	#
	## 1. Math FIRST: Find which of the 4 flat faces the player is closest to
	#var to_player: Vector3 = global_position.direction_to(player.global_position)
	#to_player.y = 0
	#to_player = to_player.normalized()
#
	#var box_fwd: Vector3 = -global_transform.basis.z.normalized()
	#var box_right: Vector3 = global_transform.basis.x.normalized()
#
	#var dot_fwd: float = to_player.dot(box_fwd)
	#var dot_right: float = to_player.dot(box_right)
#
	#var snap_normal: Vector3
	#if abs(dot_fwd) > abs(dot_right):
		#snap_normal = box_fwd if dot_fwd > 0 else -box_fwd
	#else:
		#snap_normal = box_right if dot_right > 0 else -box_right
#
	## 2. Calculate exactly where the player should stand and look
	#var target_stand_pos: Vector3 = global_position + (snap_normal * stand_distance)
	#target_stand_pos.y = player.global_position.y # Maintain original floor height
	#
	## 3. Space Clearance Check
	#var space_state := get_world_3d().direct_space_state
	#var clearance_shape := CapsuleShape3D.new()
	#clearance_shape.radius = player_radius
	#clearance_shape.height = player_height
	#
	#var query := PhysicsShapeQueryParameters3D.new()
	#query.shape = clearance_shape
	#var shape_origin := target_stand_pos + Vector3(0.0, (player_height / 2.0) + 0.1, 0.0)
	#query.transform = Transform3D(Basis(), shape_origin)
	#query.collision_mask = environment_collision_mask
	#query.exclude = [self.get_rid(), player.get_rid()]
	#
	#var hits := space_state.intersect_shape(query)
	#if not hits.is_empty():
		#return # Blocked by wall, abort grab
		#
	#_is_animating = true
	#holder = player
	#if label: label.hide()
#
	#if interact_comp:
		#interact_comp.is_currently_focused = false
		#interact_comp.unfocused.emit()
		#interact_comp.process_mode = Node.PROCESS_MODE_DISABLED 
		#
	#if "is_stunned" in holder:
		#holder.is_stunned = true
#
	## OVERRIDE PARENT: Keep gravity ON so it doesn't float!
	#freeze = false 
	#gravity_scale = 1.0  
	#add_collision_exception_with(holder)
#
	## 4. Tween the player into position smoothly
	#var look_dir: Vector3 = -snap_normal
	#var target_basis: Basis = Basis.looking_at(look_dir, Vector3.UP)
#
	#var tween: Tween = get_tree().create_tween().set_parallel(true)
	#tween.tween_property(holder, "global_position", target_stand_pos, 0.4).set_trans(Tween.TRANS_SINE)
	#tween.tween_property(holder, "quaternion", target_basis.get_rotation_quaternion(), 0.4).set_trans(Tween.TRANS_SINE)
	#
	#if "eyes" in holder:
		#tween.tween_property(holder.eyes, "rotation:x", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
#
	#tween.chain().tween_callback(_on_snap_complete.bind(target))
#
#func _on_snap_complete(target: Marker3D) -> void:
	#_is_animating = false
	#is_heavy_held = true
	#heavy_target = target
	#
	#_grab_time = Time.get_ticks_msec()
	#
	#global_grab_offset = global_position - holder.global_position
	#
	## LOCK IT DOWN: Box is a sled, it never rolls.
	#axis_lock_angular_x = true
	#axis_lock_angular_z = true
#
	#if "is_stunned" in holder:
		#holder.is_stunned = false
	#if "can_sprint" in holder:
		#holder.can_sprint = false
	#if "is_heavy_lifting" in holder:
		#holder.is_heavy_lifting = true
#
#func drop() -> void:
	#if Time.get_ticks_msec() - _grab_time < 100 or _is_animating:
		#return
		#
	#is_heavy_held = false
	#freeze = false 
	#gravity_scale = 1.0 
#
	## Keep it locked when dropped so it slides flat
	#axis_lock_angular_x = true
	#axis_lock_angular_z = true
#
	#if holder:
		#if "can_sprint" in holder:
			#holder.can_sprint = true
		#if "is_heavy_lifting" in holder:
			#holder.is_heavy_lifting = false
			#
		#if "held_object" in holder:
			#holder.held_object = null
		#if "weapon_holder" in holder and holder.weapon_holder:
			#holder.weapon_holder.show()
			#
		#var previous_holder := holder
		#_attempt_enable_collision(previous_holder)
#
	#if is_locked:
		#holder = null
		#if interact_comp: interact_comp.is_currently_focused = false
		#return
#
	#holder = null
	#if interact_comp:
		#interact_comp.process_mode = Node.PROCESS_MODE_INHERIT
		#interact_comp.is_currently_focused = false
#
#func throw(_impulse_vector: Vector3) -> void:
	#drop()
#
#func _physics_process(_delta: float) -> void:
	#if is_heavy_held and holder:
		#if _is_animating: return 
#
		## ---------------------------------------------------------
		## 1. AUTO-DETACH LOGIC (Stairs & Abyss)
		## ---------------------------------------------------------
		#var box_bottom_y: float = global_position.y - box_half_height
		#
		## Stop player from pulling it UP steep stairs
		#var is_too_high: bool = holder.global_position.y > box_bottom_y + 0.3
		#
		## If velocity is highly negative, it's plummeting off a ledge
		#var is_falling: bool = linear_velocity.y < -2.5
#
		#if is_too_high or is_falling:
			#var lurch_dir := (global_position - holder.global_position).normalized()
			#lurch_dir.y = 0.0
			#
			#drop()
			#
			## Give it a small central nudge when falling so it naturally clears the ledge
			#if is_falling:
				#apply_central_impulse(lurch_dir * mass * 1.5)
			#return
#
		## ---------------------------------------------------------
		## 2. POSITION VARIABLES
		## ---------------------------------------------------------
		#var target_pos := holder.global_position + global_grab_offset
		#if "direction" in holder and holder.direction.length() > 0.1:
			#target_pos += holder.direction * 0.35
			#
		#var current_pos := global_position
		#
		## Snag check
		#if current_pos.distance_to(target_pos) > drop_distance:
			#drop()
			#return
#
		## ---------------------------------------------------------
		## 3. STRICT X/Z PULLING (No lifting)
		## ---------------------------------------------------------
		#var distance_vector := Vector3(target_pos.x - current_pos.x, 0.0, target_pos.z - current_pos.z)
		#var pull_strength: float = drag_speed * mass * 15.0
		#
		#apply_central_force(distance_vector * pull_strength)
		#
		## Heavy X/Z Friction to keep it from behaving like a pendulum
		#var friction: float = 12.0 * mass
		#apply_central_force(Vector3(-linear_velocity.x, 0.0, -linear_velocity.z) * friction)
		#
		## ZERO out angular velocity to stop Godot's physics engine from 
		## jittering the box when it scrapes against stair edges
		#angular_velocity = Vector3.ZERO
