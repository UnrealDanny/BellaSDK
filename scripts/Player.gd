extends CharacterBody3D

# BASED GODOT YOUTUBERS
# LUKKY - https://www.youtube.com/watch?v=xIKErMgJ1Yk - FPS CONTROLLER
# https://www.youtube.com/@stayathomedev - FPS CONTROLLER + HE HELPED ME STARTED

# PLAYER NODES

@onready var head: Node3D = $Head
@onready var eyes: Node3D = $Head/Eyes
@onready var standing_collision_shape: CollisionShape3D = $StandingCollisionShape
@onready var crouching_collision_shape: CollisionShape3D = $CrouchingCollisionShape
@onready var crouch_cast_check: RayCast3D = $CrouchCastCheck
@onready var cam: Camera3D = $Head/Eyes/Camera3D
@onready var camera_anims: AnimationPlayer = $Head/Eyes/CameraAnims
@onready var fisheye_zoom: ColorRect = $UIElements/CanvasLayer/FisheyeZoom

@onready var vignette: ColorRect = $UIElements/CanvasLayer/Vignette
@onready var ui: CanvasLayer = $UI
@onready var ui_circle_zoom: TextureRect = $UIElements/CanvasLayer/MarginContainer/UICircleZoom
@onready var ui_circle_zoom_inner: TextureRect = $UIElements/CanvasLayer/MarginContainer/UICircleZoomInner

@onready var flash_light_node: Node3D = $Head/Eyes/Camera3D/FlashLightNode
@onready var flashlight: SpotLight3D = $Head/Eyes/Camera3D/FlashLightNode/Flashlight


# SPEED VARS

var current_speed 			:= 0.0
@export var walking_speed 	:= 5.0
@export var sprinting_speed := 6.5
@export var crouching_speed := 3.0
@export var swimming_speed  := 4.0
const jump_velocity 		:= 4.5
const crouch_jump_velocity 	:= 3.5
const sprint_jump_velocity 	:= 5

# SPEED STATES

var walking 		:= false
var sprinting 		:= false
var crouching 		:= false
var sprint_active 	:= false
var flying 			:= false
var swimming 		:= false

# INPUT VARS

var mouse_sensitivity := 0.5
var mouse_sensitivity_base := 0.5
var mouse_sensitivity_zoom := mouse_sensitivity / 10
var direction 			:= Vector3.ZERO

# HEADBOB VARS
const head_bobbing_sprinting_speed 	:= 22.0
const head_bobbing_walking_speed 	:= 14.0
const head_bobbing_crouching_speed 	:= 10.0
const head_bobbing_idle_speed 		:= 3.0

const head_bobbing_sprinting_intensity 	:= 0.2
const head_bobbing_walking_intensity 	:= 0.1
const head_bobbing_crouching_intensity 	:= 0.08
const head_bobbing_idle_intensity 		:= 0.02

var head_bobbing_vector 			:= Vector2.ZERO
var head_bobbing_index 				:= 0.0
var head_bobbing_current_intensity 	:= 0.0

# MOVEMENT VARS
var lerp_speed 			:= 15.0
var air_lerp_speed 		:= 3.0
var crouching_depth		:= 0.7
var last_velocity 		:= Vector3.ZERO

var CameraTiltLeft 		:= 3.0
var CameraTiltRight 	:= -3.0

## FLASHLIGHT VARS
var flashlight_rotation_smoothness := 10.0
var flashlight_position_smoothness := 10.0
@export var sway_amount : float = 5.0
@export var smooth_speed : float = 10.0
var mouse_delta := Vector2.ZERO
var default_flashlight_pos := Vector3.ZERO
var sway_target := Vector2.ZERO

var bob_freq 	:= 2.0
var bob_amp 	:= 1.0
var bob_time 	:= 0.0

# SPRINT FOV VARS
@export var base_fov 	:= 75.0
@export var sprint_fov 	:= 85.0
var zoom_fov := 10.0
var fov_change_speed 	:= 12.0
var target_fov = base_fov

# UI VARS
var target_alpha: float = 0.0

# INTERACT VARS
@onready var interact_shapecast: ShapeCast3D = %InteractShapeCast
@onready var hold_position: Marker3D = $Head/Eyes/Camera3D/HoldPosition
var current_interactable: Interact_Component = null
var held_object: PickableObject = null

# STAIRS AND STEEP SURFACES VARS
const MAX_STEP_HEIGHT = 0.5
var _snapped_to_stairs_last_frame := false
var _last_frame_was_on_floor = -INF

# LADDER VARS
var on_ladder: bool = false
var LADDER_SPEED: float = 5.0

# ROPE VARS
var current_rope: RigidBody3D = null
var rope_offset: float = 0.0
const ROPE_CLIMB_SPEED: float = 1.0
const ROPE_CLAMP: float = 4.5
var ROPE_SWING_FORCE: float = 5.0
var rope_local_grab_dir: Vector3 = Vector3.ZERO

# SWIM VARS
var swim_up_speed 		:= 5
var wish_dir := Vector3.ZERO
var cam_aligned_wish_dir := Vector3.ZERO
var was_in_water: bool = false
var base_light_energy: float = 1.0
var base_spot_range: float = 10.0
var is_swimming: bool = false
@export var float_offset: float = 1.5 # The height from your feet to your neck. Increase to float higher!
@export var water_drag: float = 0.05 # How "thick" the water feels (slows down movement)
@export var buoyancy_force: float = 15.0 #
var current_water_height: float = 0.0
var head_in_water := false

# DEVTOOLS VARS
var noclip_speed_multiplier := 4.0
var is_menu_open: bool = false

# OTHER VARS
var vignette_target_alpha: float = 0.0
var zoom_tween: Tween
var input_dir: Vector2 = Vector2.ZERO
var _frames_since_grounded: int = 0

# --------------------------------------
# MAIN SCRIPT
# --------------------------------------


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
	ui_circle_zoom.pivot_offset = ui_circle_zoom.size / 2
	ui_circle_zoom.scale = Vector2.ZERO
	ui_circle_zoom.modulate.a = 0.0
	ui_circle_zoom.hide()
	ui_circle_zoom_inner.pivot_offset = ui_circle_zoom_inner.size / 2
	ui_circle_zoom_inner.scale = Vector2.ZERO
	ui_circle_zoom_inner.modulate.a = 0.0
	ui_circle_zoom_inner.hide()
	
	default_flashlight_pos = flash_light_node.position
	flashlight.visible = false
	if flashlight:
		base_light_energy = flashlight.light_energy
		base_spot_range = flashlight.spot_range
	
	Events.debug_menu_toggled.connect(_on_debug_menu_toggled)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			noclip_speed_multiplier = min(100, noclip_speed_multiplier * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			noclip_speed_multiplier = max(0.1, noclip_speed_multiplier * 0.9)
	
func _input(event: InputEvent) -> void:
	# MOUSE LOOKING LOGIC
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		sway_target += event.relative

	if event is InputEventMouseMotion:
		mouse_delta = event.relative
# --------------------------------------
# SMOOTH STAIRS AND OTHER DIFFICULT TERRAIN
# --------------------------------------
func is_surface_too_steep(normal : Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > self.floor_max_angle
	
func _run_body_test_motion(from : Transform3D, motion : Vector3, result = null) -> bool:
	if not result: result = PhysicsTestMotionResult3D.new()
	var params = PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	return PhysicsServer3D.body_test_motion(self.get_rid(), params, result)
	
func _snap_down_to_stairs_check() -> void:
	var did_snap := false
	var floor_below : bool = %StairsBelowCast.is_colliding() and not is_surface_too_steep(%StairsBelowCast.get_collision_normal())
	var was_on_floor_last_frame = Engine.get_physics_frames() - _last_frame_was_on_floor == 1
	if not is_on_floor() and velocity.y <= 0 and (was_on_floor_last_frame or _snapped_to_stairs_last_frame) and floor_below:
		var body_test_result = PhysicsTestMotionResult3D.new()
		if _run_body_test_motion(self.global_transform, Vector3(0, -MAX_STEP_HEIGHT,0), body_test_result):
			#_save_camera_pos_for_smoothing()
			var old_pos_y = self.global_position.y
			var translate_y = body_test_result.get_travel().y
			self.position.y += translate_y
			apply_floor_snap()
			did_snap = true
			
			_apply_camera_smoothing(self.global_position.y - old_pos_y)
	_snapped_to_stairs_last_frame = did_snap

func _snap_up_stairs_check(delta) -> bool:
	if not is_on_floor() and not _snapped_to_stairs_last_frame: return false
	if self.velocity.y > 0 or (self.velocity * Vector3(1,0,1)).length() == 0: return false
	var expected_move_motion = self.velocity * Vector3(1, 0, 1) * delta
	
	var step_pos_with_clearance = self.global_transform
	step_pos_with_clearance.origin += expected_move_motion + Vector3(0, MAX_STEP_HEIGHT * 2, 0)
	
	#var step_pos_with_clearance = self.global_transform.translated(expected_move_motion + Vector3(0, MAX_STEP_HEIGHT *2,0))
	var down_check_result = PhysicsTestMotionResult3D.new()
	if (_run_body_test_motion(step_pos_with_clearance, Vector3(0, -MAX_STEP_HEIGHT * 2, 0), down_check_result) 
	and (down_check_result.get_collider().is_class("StaticBody3D") or down_check_result.get_collider().is_class("CSGShape3D"))):
		var step_height = ((step_pos_with_clearance.origin + down_check_result.get_travel()) - self.global_position).y
		if step_height > MAX_STEP_HEIGHT or step_height <= 0.01 or (down_check_result.get_collision_point() - self.global_position).y > MAX_STEP_HEIGHT: return false
		%StairsAheadCast.global_position = down_check_result.get_collision_point() + Vector3(0, MAX_STEP_HEIGHT, 0) + expected_move_motion.normalized() * 0.1
		%StairsAheadCast.force_raycast_update()
		if %StairsAheadCast.is_colliding() and not is_surface_too_steep(%StairsAheadCast.get_collision_normal()):
			#_save_camera_pos_for_smoothing()
			var old_pos_y = self.global_position.y
			self.global_position = step_pos_with_clearance.origin + down_check_result.get_travel()
			apply_floor_snap()
			_snapped_to_stairs_last_frame = true
			_apply_camera_smoothing(self.global_position.y - old_pos_y)
			return true
	return false

func _apply_camera_smoothing(snap_amount: float):
	eyes.position.y -= snap_amount
	
	eyes.position.y = clampf(eyes.position.y, -0.5, 0.5)

func _slide_camera_smooth_back_to_origin(delta):
	if eyes.position.y == 0.0: 
		return
		
	var move_amount = max(self.velocity.length() * delta, walking_speed / 2.0 * delta)
	eyes.position.y = move_toward(eyes.position.y, 0.0, move_amount)

func _physics_process(delta: float) -> void:
	input_dir = Input.get_vector("left", "right", "forward", "backward")
	var is_truly_grounded = _frames_since_grounded < 3
	
	#water vars
	wish_dir = self.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	cam_aligned_wish_dir = cam.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)

	is_swimming = _handle_water_physics(delta)
	
	if not is_swimming:
		swimming = false
	
	if is_on_floor(): _last_frame_was_on_floor = Engine.get_physics_frames()
	
	if is_on_floor() or _snapped_to_stairs_last_frame:
		_frames_since_grounded = 0
	else:
		_frames_since_grounded += 1
	
	if Input.is_action_pressed("zoom"):
		input_dir = Vector2.ZERO
		
	# NOCLIP  /  NOCLIP  /  NOCLIP  /  NOCLIP  /  NOCLIP
	if Input.is_action_just_pressed("noclip"):
		walking = false
		sprinting = false
		crouching = false
		
		flying = !flying
		noclip_speed_multiplier = 4.0
		Events.noclip_toggled.emit(flying)

		
	if flying:
		var fly_dir = (cam.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		current_speed = sprinting_speed * noclip_speed_multiplier
		
		Events.noclip_speed_changed.emit(noclip_speed_multiplier)
		
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = true
				
		if fly_dir:
			velocity = fly_dir * current_speed
		else:
			velocity = Vector3.ZERO
			direction = Vector3.ZERO
		
	#/ NOCLIP  /  NOCLIP  /  NOCLIP  /  NOCLIP  /  NOCLIP
	if !swimming:
		if Input.is_action_pressed("left"):
			eyes.rotation.z = lerp(eyes.rotation.z, deg_to_rad(CameraTiltLeft), delta * lerp_speed)
		elif Input.is_action_pressed("right"):
			eyes.rotation.z = lerp(eyes.rotation.z, deg_to_rad(CameraTiltRight), delta * lerp_speed)
		else:
			eyes.rotation.z = lerp(eyes.rotation.z, deg_to_rad(0), delta * lerp_speed)
	
	# CROUCHING
	if Input.is_action_pressed("crouch") and is_truly_grounded and !is_swimming:
		current_speed = lerp(current_speed, crouching_speed, delta * lerp_speed)
		head.position.y = lerp(head.position.y, crouching_depth, delta * lerp_speed)
		
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
		
		walking = false
		sprinting = false
		crouching = true
		flying = false
		
	# CROUCH CAST CHECK
	elif !crouch_cast_check.is_colliding() and !flying:
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		
		head.position.y = lerp(head.position.y, 1.8, delta * lerp_speed)
		crouching = false
	# -----------------------------------
	# SPRINT
	# -----------------------------------
	if Input.is_action_pressed("sprint") and standing_collision_shape.disabled == false and input_dir != Vector2.ZERO: 
		if is_on_floor() and !is_swimming:
			sprint_active = true
	else:
		sprint_active = false
		
	if sprint_active:
		current_speed = lerp(current_speed, sprinting_speed, delta * lerp_speed)
		
		if input_dir.y < -0.1: 
			target_fov = sprint_fov
		else:
			target_fov = base_fov
		
		walking = false
		sprinting = true
		crouching = false
		flying = false
		
	elif input_dir != Vector2.ZERO and crouching_collision_shape.disabled == true and !flying:
		# walking mechanic
		current_speed = lerp(current_speed, walking_speed, delta * lerp_speed)
		target_fov = base_fov
		
		walking = true	
		sprinting = false	
		crouching = false
		flying = false
			
	# HANDLE HEADBOB
	
	# 1. Figure out if we are actively pulling ourselves up/down the rope
	var is_climbing_rope = false
	var climb_factor = 0.0
	
	if current_rope != null:
		var look_dir := -cam.global_transform.basis.z
		var climb_input: float = (look_dir * -input_dir.y).y
		if abs(climb_input) > 0.1:
			is_climbing_rope = true
			climb_factor = abs(climb_input)

	 #2. Add the climbing state to your intensity/speed checks
	if is_climbing_rope:
		# Rope climbing feels heavy! We multiply the walking intensity slightly.
		head_bobbing_current_intensity = head_bobbing_walking_intensity * 1.5 
		head_bobbing_index += ROPE_CLIMB_SPEED * climb_factor * delta * 12.6
	elif sprinting and input_dir != Vector2.ZERO:
		if abs(input_dir.y) > 0.1:
			head_bobbing_current_intensity = head_bobbing_sprinting_intensity * 1.2
			head_bobbing_index += head_bobbing_sprinting_speed * 1.2 * delta
		else:
			head_bobbing_current_intensity = head_bobbing_walking_intensity * 0.5
			head_bobbing_index += head_bobbing_walking_speed * delta
	elif walking and input_dir != Vector2.ZERO:
		head_bobbing_current_intensity = head_bobbing_walking_intensity
		head_bobbing_index += head_bobbing_walking_speed * delta
	elif crouching and input_dir != Vector2.ZERO:
		head_bobbing_current_intensity = head_bobbing_crouching_intensity
		head_bobbing_index += head_bobbing_crouching_speed * 1.4 * delta
	else:
		# Idle — slow subtle breathing bob (This now handles floor idle AND hanging idle!)
		head_bobbing_current_intensity = head_bobbing_idle_intensity
		head_bobbing_index += head_bobbing_idle_speed * delta
		
	# 3. THE FIX: Tell the script it is allowed to bob while hanging!
	if is_on_floor() or current_rope != null:
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = sin(head_bobbing_index/2) + 0.5

		eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y * (head_bobbing_current_intensity/2.0), delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, head_bobbing_vector.x * head_bobbing_current_intensity, delta * lerp_speed)
		
	# Add the gravity.
	if not is_on_floor() and !flying:
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if sprinting:
			velocity.y = sprint_jump_velocity
			camera_anims.play("jump")
		elif crouching:
			velocity.y = crouch_jump_velocity
			camera_anims.play("jump")
		else:
			velocity.y = jump_velocity
			camera_anims.play("jump")
			
	#Handle landing
	if is_on_floor() and !is_swimming:
		if last_velocity.y < 0.0:
			if sprinting:
				camera_anims.play("jump_landing")
			else:
				camera_anims.play("landing")
		
	var target_anim = ""
	
	if is_swimming:
		# 1. LATERAL MOVEMENT (Side-to-Side) - Highest Priority
		if input_dir.x > 0.1: # Moving Right
			target_anim = "swimming_underwater_sideways_right"
			eyes.rotation.z = lerp(eyes.rotation.z, deg_to_rad(CameraTiltRight * 2), delta * lerp_speed / 3)
			
		elif input_dir.x < -0.1: # Moving Left
			target_anim = "swimming_underwater_sideways_left"
			eyes.rotation.z = lerp(eyes.rotation.z, deg_to_rad(CameraTiltLeft * 2), delta * lerp_speed / 3)
		
		# 2. FORWARD/BACKWARD MOVEMENT
			
		elif abs(input_dir.y) > 0.1:
			target_anim = "swimming"
			eyes.rotation.z = lerp(eyes.rotation.z, 0.0, delta * lerp_speed / 3)

		# 3. VERTICAL MOVEMENT (Only if submerged)
		elif (Input.is_action_pressed("jump") or Input.is_action_pressed("sprint")) and head_in_water:
			target_anim = "swimming_up"
			eyes.rotation.z = lerp(eyes.rotation.z, 0.0, delta * lerp_speed / 3)

		# 4. IDLE / TREADING
		else:
			target_anim = "RESET"
			eyes.rotation.z = lerp(eyes.rotation.z, 0.0, delta * lerp_speed / 3)
			
	if target_anim != "":
		if camera_anims.current_animation != target_anim:
			camera_anims.play(target_anim, 2)
		
	#if not is_on_floor() and is_swimming:
		#if input_dir.length() > 0.1:
			#target_anim = "swimming"
		#elif Input.is_action_pressed("jump") or Input.is_action_pressed("sprint") and !head_in_water:
			#target_anim = "swimming_up"
			#
	#elif is_on_floor() and is_swimming:
		#if Input.is_action_pressed("forward") or Input.is_action_pressed("backward"):
			#target_anim = "walking_underwater"
		#else:
			#target_anim = "RESET" 
#
	## 2. Execute the animation change smoothly
	#if target_anim != "":
		#if camera_anims.current_animation != target_anim:
			#camera_anims.play(target_anim, 0.3)
		#else:
			## Play the swimming or landing anim with a quick 0.2s blend for smoothness
			#camera_anims.play(target_anim, 0.2)
			#
	##var target_z_tilt = 0.0
	#
	#if is_swimming:
		#if input_dir.x > 0.1: # Moving Right
			#eyes.rotation.z = lerp(eyes.rotation.z, deg_to_rad(CameraTiltRight * 2), delta * lerp_speed / 3)
			#target_anim = "walking_underwater_sideways_right"
		#elif input_dir.x < -0.1: # Moving Left
			#eyes.rotation.z = lerp(eyes.rotation.z, deg_to_rad(CameraTiltLeft * 2), delta * lerp_speed / 3)
			#target_anim = "walking_underwater_sideways_left"
		#else:
			#eyes.rotation.z = lerp(eyes.rotation.z, deg_to_rad(CameraTiltLeft * 0), delta * lerp_speed / 3)
		
			
	if is_on_floor():
		direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * lerp_speed)
	else:
		if input_dir != Vector2.ZERO:
			direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * air_lerp_speed)
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
			
	# --------------------------
	# LADDER LOGIC 
	# -------------------------
	if on_ladder:
		# 1. Force state restrictions
		sprinting = false
		crouching = false

		# 2. Get camera directions for Source-style movement
		var look_dir = -cam.global_transform.basis.z # Forward
		var right_dir = cam.global_transform.basis.x # Right

		# 3. Calculate movement vector based on where we are looking
		# (input_dir.y is negative when pressing 'W', so we multiply by -1 to go forward)
		var ladder_vel = (look_dir * -input_dir.y) + (right_dir * input_dir.x)

		# 4. Apply speed
		velocity = ladder_vel.normalized() * LADDER_SPEED

		# 5. Dismount by jumping backwards off the ladder
		if Input.is_action_just_pressed("jump"):
			on_ladder = false
			velocity = -look_dir * 5.0 # Shove player backward
			velocity.y = 5.0 # And slightly up
		
	# ROPE LOGIC
	if current_rope != null:
		sprinting = false
		crouching = false
		walking = false

		var look_dir := -cam.global_transform.basis.z
		#var swing_forward = Vector3(look_dir.x, 0, look_dir.z).normalized()
		#var swing_right = Vector3(cam.global_transform.basis.x.x, 0, cam.global_transform.basis.x.z).normalized()
		#var swing_force = (swing_forward * -input_dir.y) + (swing_right * input_dir.x)
		#if swing_force.length() > 0.1:
			#current_rope.apply_central_force(swing_force * ROPE_SWING_FORCE)
			
		var rope_root = current_rope.get_parent()
		var local_top = current_rope.to_local(rope_root.global_position).y
		var max_length = rope_root.rope_length
		var top_limit = local_top - 2.5
		var bottom_limit = local_top - max_length + 0.5

		# 2. Climb Math
		var climb_input: float = (look_dir * -input_dir.y).y
		if abs(climb_input) > 0.1:
			rope_offset += climb_input * ROPE_CLIMB_SPEED * delta
			rope_offset = clamp(rope_offset, bottom_limit, top_limit)

		# 3. Position Update
		var target_local_pos = Vector3(rope_local_grab_dir.x, rope_offset, rope_local_grab_dir.z)
		var target_pos = current_rope.to_global(target_local_pos)

		global_position = global_position.lerp(target_pos, delta * 30.0)
		velocity = Vector3.ZERO

		if Input.is_action_just_pressed("jump"):
			_on_rope_released()
			velocity = look_dir + Vector3.UP
		elif Input.is_action_just_pressed("interact"):
			_on_rope_released()
		else:
			return

	# -------------------------------------- #
	# LAST CHECKS   						 #
	# -------------------------------------- #
	last_velocity = velocity # ALWAYS goes before move_and_slide()
	
	if not _snap_up_stairs_check(delta):
		move_and_slide()         
		_snap_down_to_stairs_check()
		
	
	_slide_camera_smooth_back_to_origin(delta)
	cam.fov = lerp(cam.fov, target_fov, delta * fov_change_speed)
	
	

	# -------------------------------------- #
	# CROUCH VIGNETTE  						 #
	# -------------------------------------- #
	var target_vignette_opacity = 10.0 if crouching else 0.0
	var current_opacity = vignette.material.get_shader_parameter("vignette_opacity")
	if current_opacity == null:
		current_opacity = 0.0
	var new_opacity = lerp(current_opacity, target_vignette_opacity, delta * lerp_speed)
	vignette.material.set_shader_parameter("vignette_opacity", new_opacity)
		
		


func _process(delta: float) -> void:
	input_dir = Input.get_vector("left", "right", "forward", "backward")
	
	
		
	update_flashlight(delta)
	if Input.is_action_just_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
		

		#var target_rotation = get_parent().global_transform.basis.get_euler()
		#global_rotation.x = lerp_angle(global_rotation.x, target_rotation.x, smooth_speed * delta)
		#global_rotation.y = lerp_angle(global_rotation.y, target_rotation.y, smooth_speed * delta)
		
	# INTERACT  /  INTERACT  /  INTERACT  /  INTERACT  /  INTERACT
	current_interactable = get_interactable_component_at_shapecast()
	if current_interactable:
		current_interactable.hover_cursor(self)
	
	if Input.is_action_just_pressed("interact"):
		# SCENARIO A: Our hands are full. Drop the box!
		if held_object:
			held_object.drop()
			held_object = null
		# SCENARIO B: Our hands are empty, and we are looking at something
		elif current_interactable:
			print("interacting")
			current_interactable.interact_with()
			var parent_node = current_interactable.get_parent()
			if parent_node is PickableObject:
				held_object = parent_node
				held_object.pick_up(hold_position, self)
				
	# --- THE NEW THROW MECHANIC ---
	if Input.is_action_just_pressed("shoot") and held_object:
		var throw_force = 12.0 # How hard you chuck it (adjust to taste!)

		# In Godot, -Z is always "forward" for cameras
		# We grab the camera's forward vector so the box goes exactly where you are looking
		var throw_direction = -cam.global_transform.basis.z.normalized()

		# Optional: Add a slight upward tilt so throws feel more natural, like a basketball shot
		throw_direction.y += 0.2 
		throw_direction = throw_direction.normalized()

		# Tell the object to launch itself, then wipe our hands clean
		held_object.throw(throw_direction * throw_force)
		held_object = null
		
	# INTERACT  /  INTERACT  /  INTERACT  /  INTERACT  /  INTERACT
			
	# -------------------------------------- #
	# ZOOM MECHANIC   						 #
	# -------------------------------------- #
		
	# 1. FOV and Sensitivity Logic
	if Input.is_action_pressed("zoom"):
		# Zoom always takes priority, even if swimming or sprinting
		target_fov = zoom_fov
		mouse_sensitivity = mouse_sensitivity_zoom
	elif sprint_active and input_dir.y < -0.1:
		# Sprint FOV only triggers if we aren't swimming (usually feels better)
		target_fov = sprint_fov
		mouse_sensitivity = mouse_sensitivity_base	
	else:
		# Default state (Walking or Swimming)
		target_fov = base_fov
		mouse_sensitivity = mouse_sensitivity_base

	cam.fov = lerp(cam.fov, target_fov, delta * 8.0)
		
	if Input.is_action_just_pressed("zoom"):
		if zoom_tween and zoom_tween.is_valid():
			zoom_tween.kill()
			
		ui.hide()
		ui_circle_zoom.show()
		ui_circle_zoom_inner.show()
		
		# Create the tween exactly once when the button is first pressed
		zoom_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		zoom_tween.tween_property(ui_circle_zoom, "scale", Vector2(1.0, 1.0), 0.5)
		zoom_tween.tween_property(ui_circle_zoom, "modulate:a", 1.0, 0.3)
		zoom_tween.tween_property(ui_circle_zoom, "rotation", deg_to_rad(15), 1)
		
		zoom_tween.tween_property(ui_circle_zoom_inner, "scale", Vector2(1.0, 1.0), 0.5)
		zoom_tween.tween_property(ui_circle_zoom_inner, "modulate:a", 0.1, 0.3)
		zoom_tween.tween_property(ui_circle_zoom_inner, "rotation", deg_to_rad(-45), 1)
		
		zoom_tween.tween_property(fisheye_zoom.material, "shader_parameter/effect_strength", 0.4, 0.2)
		
	elif Input.is_action_just_released("zoom"):
		if zoom_tween and zoom_tween.is_valid():
			zoom_tween.kill()
				
		# Create a new tween exactly once when the button is let go
		zoom_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		zoom_tween.tween_property(ui_circle_zoom, "scale", Vector2(0.0, 0.0), 0.5)
		zoom_tween.tween_property(ui_circle_zoom, "modulate:a", 0.0, 0.3)
		zoom_tween.tween_property(ui_circle_zoom, "rotation", deg_to_rad(0), 0.25)
		
		zoom_tween.tween_property(ui_circle_zoom_inner, "scale", Vector2(0.0, 0.0), 0.5)
		zoom_tween.tween_property(ui_circle_zoom_inner, "modulate:a", 0.0, 0.3)
		zoom_tween.tween_property(ui_circle_zoom_inner, "rotation", deg_to_rad(0), 0.25)
		
		zoom_tween.tween_property(fisheye_zoom.material, "shader_parameter/effect_strength", 0.0, 0.2)
		
		ui.show()
		
#FLASHLIGHT SCRIPT
#func update_flashlight(delta: float) -> void:
	#flash_light_node.global_position = flash_light_node.global_position.lerp(
		#cam.global_position,
		#delta * flashlight_position_smoothness
	#)
#
	#flash_light_node.global_transform.basis = flash_light_node.global_transform.basis.slerp(
		#cam.global_transform.basis.orthonormalized(),
		#delta * flashlight_rotation_smoothness
	#)
		#
	#var target_pos = cam.global_position
		#
	#var current_f = 0.0
	#var current_a = 0.0
	#
	#if is_on_floor():
		#var is_actually_moving = velocity.length() > 0.1
		#
		#if is_actually_moving:
			#if sprinting:
				#current_f = bob_freq * 2.5
				#current_a = bob_amp * 0.2
			#elif crouching:
				#current_f = bob_freq * 3.0
				#current_a = bob_amp * 0.15
			#elif walking:
				#current_f = bob_freq
				#current_a = bob_amp * 0.20
		#else: 
			#if crouching:
				#current_f = bob_freq * 0.3 # Even slower breathing when crouched
				#current_a = bob_amp * 0.1  # Smaller movements
			#else:
				#current_f = bob_freq * 0.5
				#current_a = bob_amp * 0.21
#
### Only run the math if there is a frequency/amplitude set		
	#if current_f > 0:
	## If moving, bob based on speed. If idle, bob at a constant slow rate.
		#var speed_factor = velocity.length()
		#if speed_factor < 0.1:
			## Constant rate for idle (the 2.0 here controls idle "breath" speed)
			#bob_time += delta * 2.0 * current_f
		#else:
			#bob_time += delta * speed_factor * current_f
		#target_pos += cam.global_transform.basis.x * cos(bob_time * 0.5) * current_a
		#target_pos += cam.global_transform.basis.y * sin(bob_time) * current_a
	#else:
	## This only happens if you are in the air and current_f remains 0.0
		#bob_time = 0
		#
#
	#flashlight.global_position = flashlight.global_position.lerp(
		#target_pos, 
		#delta * flashlight_position_smoothness
	#)
#
	#flashlight.global_transform.basis = flashlight.global_transform.basis.slerp(
		#cam.global_transform.basis, 
		#delta * flashlight_rotation_smoothness
	#)
	
func update_flashlight(delta: float) -> void:
	# 1. Start from your custom offset, NOT Vector3.ZERO!
	var target_pos = default_flashlight_pos 
	
	var current_f = 0.0
	var current_a = 0.0
	
	if is_on_floor():
		var is_actually_moving = velocity.length() > 0.1
		
		if is_actually_moving:
			if sprinting:
				current_f = bob_freq * 2.5
				current_a = bob_amp * 0.2
			elif crouching:
				current_f = bob_freq * 3.0
				current_a = bob_amp * 0.15
			elif walking:
				current_f = bob_freq
				current_a = bob_amp * 0.20
		else: 
			if crouching:
				current_f = bob_freq * 0.3 
				current_a = bob_amp * 0.1  
			else:
				current_f = bob_freq * 0.5
				current_a = bob_amp * 0.21

	if current_f > 0:
		var speed_factor = velocity.length()
		if speed_factor < 0.1:
			bob_time += delta * 2.0 * current_f
		else:
			bob_time += delta * speed_factor * current_f
			
		# Add the bob offsets directly to your default position
		target_pos.x += cos(bob_time * 0.5) * current_a
		target_pos.y += sin(bob_time) * current_a
	else:
		bob_time = 0

	# --- 2. LOCAL SWAY (The Spring System) ---
	# Clamp the accumulated mouse movement so the flashlight doesn't snap your neck
	var max_sway = 150.0 # Adjust this to allow more/less maximum drag
	sway_target.x = clamp(sway_target.x, -max_sway, max_sway)
	sway_target.y = clamp(sway_target.y, -max_sway, max_sway)

	# Convert the mouse drag into a tiny rotation target
	var target_rot = Vector3(
		-sway_target.y * (sway_amount * -0.002), 
		-sway_target.x * (sway_amount * -0.002), 
		0.0
	)

	# --- 3. APPLY LERPS TO THE NODE ---
	flash_light_node.position = flash_light_node.position.lerp(target_pos, delta * flashlight_position_smoothness)
	flash_light_node.rotation = flash_light_node.rotation.lerp(target_rot, delta * flashlight_rotation_smoothness)

	# --- 4. THE MAGIC: Drain the spring! ---
	# This smoothly pulls the target back to zero over time, creating the rubber-band lag effect
	sway_target = sway_target.lerp(Vector2.ZERO, delta * smooth_speed)
# --------------------------------------
# INTERACT
# --------------------------------------
# THAT'S AN OLD ORIGINAL INTERACT
#func get_interactable_component_at_shapecast() -> Interact_Component:
	#for i in interact_shapecast.get_collision_count():
		##Allow colliding with player
		#if i > 0 and interact_shapecast.get_collider(0) != $".":
			#return null
		#if interact_shapecast.get_collider(i).get_node_or_null("Interact_Component") is Interact_Component:
			#return interact_shapecast.get_collider(i).get_node_or_null("Interact_Component")
	#return null
	
func get_interactable_component_at_shapecast() -> Interact_Component:
	for i in interact_shapecast.get_collision_count():
		var collider = interact_shapecast.get_collider(i)
		
		# Skip the player if the cast accidentally hits our own hitbox
		if collider == self:
			continue
			
		var comp = collider.get_node_or_null("Interact_Component")
		if comp is Interact_Component:
			return comp
			
	return null

# --------------------------------------
# LADDERS
# --------------------------------------
func enter_ladder() -> void:
	on_ladder = true

func exit_ladder() -> void:
	on_ladder = false
	
# --------------------------------------
# ROPES
# --------------------------------------
var rope_horizontal_offset: Vector3 = Vector3.ZERO

func _on_rope_grabbed(rope_body: RigidBody3D) -> void:
	current_rope = rope_body
	velocity = Vector3.ZERO
	add_collision_exception_with(current_rope)

	# 1. Ask the swinging body exactly where the player is
	var local_pos = current_rope.to_local(global_position)
	rope_offset = local_pos.y

	# 2. Extract horizontal direction so we hang on the outside
	var local_flat_dir = Vector3(local_pos.x, 0, local_pos.z)
	if local_flat_dir.length() < 0.01:
		local_flat_dir = Vector3(0, 0, 1) 
	rope_local_grab_dir = local_flat_dir.normalized() * 0.6

	# 3. THE FIX: Dynamically find the exact local position of the ceiling anchor!
	var rope_root = current_rope.get_parent()
	var local_top = current_rope.to_local(rope_root.global_position).y

	# 4. Build our limits straight down from that anchor
	var max_length = rope_root.rope_length
	var top_limit = local_top -2.5
	var bottom_limit = local_top - max_length + 0.5

	# Clamp our starting grab height
	rope_offset = clamp(rope_offset, bottom_limit, top_limit)

	# 5. Instant snap
	var target_local_pos = Vector3(rope_local_grab_dir.x, rope_offset, rope_local_grab_dir.z)
	global_position = current_rope.to_global(target_local_pos)

func _on_rope_released() -> void:
	# Tell the rope to re-enable its outline logic
	if current_rope and current_rope.get_parent().has_method("on_player_released"):
		current_rope.get_parent().on_player_released()

	current_rope = null
	#standing_collision_shape.disabled = false
	#crouching_collision_shape.disabled = false

# ----------------------------
# WATER MECHANICS
# -----------------------------
func _handle_water_physics(delta: float) -> bool:
	# 1. Cleaner, more reliable water detection
	var in_water := false
	var water_areas = get_tree().get_nodes_in_group("water_area")
	
	for area in water_areas:
		if area.overlaps_body(self):
			in_water = true
			break
			
# --- 100% SUBMERGED FLASHLIGHT LOGIC ---
	head_in_water = false
	
	# Ask the physics engine what is exactly at the camera's coordinate
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsPointQueryParameters3D.new()
	var chin_offset = Vector3(0.0, 0.2, 0.0)
	query.position = cam.global_position - chin_offset
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var results = space_state.intersect_point(query)
	for result in results:
		if result.collider.is_in_group("water_area"):
			head_in_water = true
			break
			
	var target_energy = base_light_energy * 4.0 if head_in_water else base_light_energy
	var target_range = base_spot_range * 2.0 if head_in_water else base_spot_range

	# Smoothly Lerp the flashlight! 
	# (A weight of 4.0 * delta visually completes the transition in about ~1 second)
	if flashlight:
		flashlight.light_energy = lerpf(flashlight.light_energy, target_energy, 4.0 * delta)
		flashlight.spot_range = lerpf(flashlight.spot_range, target_range, 4.0 * delta)
			
	if not in_water:
		return false
	
	# 2. Gravity (Buoyancy) - Slow downward drift
	#if not is_on_floor():
		#velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * 0.1 * delta

	# --- PREVENT SPRINTING & CROUCHING ---
	# We force these states off. 
	walking = false
	sprinting = false
	crouching = false
	sprint_active = false
	flying = false
	swimming = true
	
	standing_collision_shape.disabled = false
	crouching_collision_shape.disabled = true
	head.position.y = lerp(head.position.y, 1.8, delta * lerp_speed)
	#target_fov = base_fov # now zoom works as intended

	# --- TRUE 3D SWIMMING ---
	input_dir = Input.get_vector("left", "right", "forward", "backward")
	var swim_dir = (cam.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var target_velocity = swim_dir * swimming_speed

	## Vertical swimming controls
	#var actively_swimming_vertical = false
	#if Input.is_action_pressed("jump") or Input.is_action_pressed("sprint"):
		#target_velocity.y += swim_up_speed
		#actively_swimming_vertical = true
	#elif Input.is_action_pressed("crouch"): 
		#target_velocity.y -= swim_up_speed
		#actively_swimming_vertical = true
		
	var actively_swimming_vertical = false
	var just_water_jumped = false
	
	if Input.is_action_just_pressed("jump") and !head_in_water:
		if interact_shapecast.is_colliding():
			var collision_normal = interact_shapecast.get_collision_normal(0)
			if abs(collision_normal.y) < 0.7:
				print("Vaulting off a wall/ledge!")
				velocity.y = 12 
				actively_swimming_vertical = true
				just_water_jumped = true
		else:
			pass

	# 2. MANUAL DIVING / SWIMMING UP
	elif Input.is_action_pressed("crouch"): 
		target_velocity.y -= swim_up_speed
		actively_swimming_vertical = true
	elif Input.is_action_pressed("jump") or Input.is_action_pressed("sprint"):
		if head_in_water:
			target_velocity.y += swim_up_speed
			actively_swimming_vertical = true

	# 3. AUTO-TREADING WATER (The Anti-Annoyance System)
	if not actively_swimming_vertical:
		if head_in_water:
			if input_dir == Vector2.ZERO:
				target_velocity.y = 3.0 # Natural buoyancy speed
			else:
				pass
		else:
			if target_velocity.y < 0.0:
				target_velocity.y = 0
			if velocity.y < 1.0 and velocity.y > -4.0:
				velocity.y = lerpf(velocity.y, 0.0, 10.0 * delta)

	# --- APPLY HORIZONTAL LERP (Steering) ---
	var target_xz = Vector2(target_velocity.x, target_velocity.z)
	var current_xz = Vector2(velocity.x, velocity.z)
	current_xz = current_xz.lerp(target_xz, 8.0 * delta)
	velocity.x = current_xz.x
	velocity.z = current_xz.y

	# --- APPLY VERTICAL LERP (Swimming/Sinking) ---
	# We skip the smoothing lerp on the exact frame we jump, so the burst is instant!
	if not just_water_jumped:
		velocity.y = lerpf(velocity.y, target_velocity.y, 4.0 * delta)

	return true
	#if Input.is_action_pressed("jump") or Input.is_action_pressed("sprint"):
		#if head_in_water:
			## We are submerged, swim up normally!
			#target_velocity.y += swim_up_speed
		#else:
			## OUR HEAD BROKE THE SURFACE! 
			## We set target_velocity to 0.0 so we hover exactly at the water line.
			#target_velocity.y = 3.0
			#
		#actively_swimming_vertical = true
		#
	#elif Input.is_action_pressed("crouch"): 
		#target_velocity.y -= swim_up_speed
		#actively_swimming_vertical = true
	#
	## 1. HORIZONTAL (X/Z): Apply tight 8.0 friction for snappy camera steering
	#var target_xz = Vector2(target_velocity.x, target_velocity.z)
	#var current_xz = Vector2(velocity.x, velocity.z)
	#current_xz = current_xz.lerp(target_xz, 8.0 * delta)
	#velocity.x = current_xz.x
	#velocity.z = current_xz.y
#
	## 2. VERTICAL (Y): Handle splashing, sinking, and drifting
	#var is_idle = input_dir.length() < 0.1 and not actively_swimming_vertical
#
	#if is_idle and not is_on_floor():
		## WE ARE IDLE: Apply slow sinking buoyancy
		#velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * 0.1 * delta
		#
		## Cap the sinking speed so you don't accelerate infinitely downwards
		## (e.g., -2.0 is a gentle terminal velocity for sinking)
		#velocity.y = clamp(velocity.y, -1.0, 100.0) 
		#
	#else:
		## WE ARE ACTIVELY SWIMMING: Use a softer friction (e.g., 3.0 or 4.0) for the Y-axis.
		## This allows you to splash deep into the water before the drag catches you!
		#velocity.y = lerpf(velocity.y, target_velocity.y, 4.0 * delta)
#
	#return true


	
func _on_debug_menu_toggled(is_open: bool) -> void:
	is_menu_open = is_open
