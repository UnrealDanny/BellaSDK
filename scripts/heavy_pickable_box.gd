extends PickableObject
class_name HeavyPickableBox

var is_heavy_held: bool = false
var _is_animating: bool = false

@export_group("Movement Settings")
@export var drop_distance: float = 2.5 
@export var snap_duration: float = 0.3

@export_group("Box Dimensions")
@export var box_half_width: float = 1.0 

@export_group("Player Settings")
@export var player_radius: float = 0.5 
@export var player_height: float = 1.8 
@export_flags_3d_physics var environment_collision_mask: int = 1 

func pick_up(_target: Marker3D, player: Node3D) -> void:
	if is_locked or _is_animating: return
	
	# ---------------------------------------------------------
	# 1. FIXED ANTI-STAND LOGIC
	# ---------------------------------------------------------
	var height_diff := player.global_position.y - global_position.y
	var flat_dist := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
	
	# Lowered the height threshold to 0.3. If your feet are slightly above the center, it rejects the grab.
	if height_diff > 0.3 and flat_dist < (box_half_width + 0.3):
		return
	
	var to_player := (player.global_position - global_position)
	to_player.y = 0
	to_player = to_player.normalized()

	var b_fwd := -global_transform.basis.z.normalized()
	var b_right := global_transform.basis.x.normalized()

	var snap_normal: Vector3
	if abs(to_player.dot(b_fwd)) > abs(to_player.dot(b_right)):
		snap_normal = b_fwd if to_player.dot(b_fwd) > 0 else -b_fwd
	else:
		snap_normal = b_right if to_player.dot(b_right) > 0 else -b_right

	var hold_distance := box_half_width + player_radius + 0.2
	var target_stand_pos := global_position + (snap_normal * hold_distance)
	target_stand_pos.y = player.global_position.y 

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = player_radius * 0.8
	shape.height = player_height * 0.8
	query.shape = shape
	query.transform = Transform3D(Basis(), target_stand_pos + Vector3(0, (player_height/2) + 0.5, 0))
	query.collision_mask = environment_collision_mask
	query.exclude = [self.get_rid(), player.get_rid()]

	if not space_state.intersect_shape(query).is_empty():
		return 

	_is_animating = true
	holder = player
	
	# ---------------------------------------------------------
	# 2. THE GHOST PLAYER TRICK
	# ---------------------------------------------------------
	# The box ignores the player so you can walk forward without being blocked.
	add_collision_exception_with(holder)
	
	if "is_stunned" in holder: holder.is_stunned = true
	if interact_comp: interact_comp.process_mode = Node.PROCESS_MODE_DISABLED
	
	var look_at_box_basis := Basis.looking_at(-snap_normal, Vector3.UP)
	var tween := get_tree().create_tween().set_parallel(true)
	tween.tween_property(holder, "global_position", target_stand_pos, snap_duration)
	tween.tween_property(holder, "quaternion", look_at_box_basis.get_rotation_quaternion(), snap_duration)
	
	tween.chain().tween_callback(_finish_pickup)

func _finish_pickup() -> void:
	_is_animating = false
	is_heavy_held = true
	_grab_time = Time.get_ticks_msec()
	
	global_rotation.x = 0.0
	global_rotation.z = 0.0
	
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true
	
	# Box becomes a moving kinematic wall
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	
	if "is_stunned" in holder: holder.is_stunned = false
	if "is_heavy_lifting" in holder: holder.is_heavy_lifting = true
	
func _physics_process(delta: float) -> void:
	if is_heavy_held and holder:
		if _is_animating: return

		# 1. TIGHTEN THE VERTICAL DROP THRESHOLD
		# 1.5 meters is basically head height. If you walk up a few stairs, 
		# the box was allowed to drag behind you. 0.8 forces a drop much sooner.
		if abs(holder.global_position.y - global_position.y) > 0.8:
			drop() 
			return

		# ---------------------------------------------------------
		# 3. THE SQUISH CHECK (Wall Collision)
		# ---------------------------------------------------------
		var dist_to_player := global_position.distance_to(holder.global_position)
		var squish_limit := (box_half_width + player_radius) - 0.15
		
		if dist_to_player < squish_limit:
			drop()
			return

		var player_fwd := -holder.global_transform.basis.z
		player_fwd.y = 0.0 
		player_fwd = player_fwd.normalized()
		
		var hold_distance := box_half_width + player_radius + 0.2
		var target_pos := holder.global_position + (player_fwd * hold_distance)
		target_pos.y = global_position.y 

		if global_position.distance_to(target_pos) > drop_distance:
			drop()
			return
			
		var motion := target_pos - global_position
		
		# ---------------------------------------------------------
		# 4. CAMERA SWING FIX
		# ---------------------------------------------------------
		var max_speed := 8.0 * delta
		if motion.length() > max_speed:
			motion = motion.normalized() * max_speed
		
		# Sweep the box forward. If it hits a wall, it stops physically.
		var col := move_and_collide(motion)
		if col:
			var remainder := motion.slide(col.get_normal())
			
			# -> ANTI-CLIMB FIX <-
			# Prevent the slide calculation from redirecting horizontal push force upwards.
			# Using min() allows it to slide down slopes, but flat out refuses to climb them.
			remainder.y = min(0.0, remainder.y)
			
			move_and_collide(remainder)
			
func drop() -> void:
	if _is_animating: return
	
	is_heavy_held = false
	
	axis_lock_angular_x = false
	axis_lock_angular_y = false
	axis_lock_angular_z = false
	
	# Return to normal physics
	freeze = false
	
	if holder:
		if "is_heavy_lifting" in holder: holder.is_heavy_lifting = false
		
		if "held_object" in holder:
			holder.held_object = null
		elif "grabbed_object" in holder:
			holder.grabbed_object = null
			
		# VERY IMPORTANT: Uses your base class's safe collision timer
		# so you don't get stuck inside the box when you let go!
		var previous_holder := holder
		_wait_to_enable_collision(previous_holder)
			
	if interact_comp:
		interact_comp.process_mode = Node.PROCESS_MODE_INHERIT
			
	holder = null

func throw(_impulse: Vector3) -> void:
	drop()
