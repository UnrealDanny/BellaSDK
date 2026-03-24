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

@onready var flash_light_node: Node3D = $Head/Eyes/Camera3D/FlashLightNode
@onready var flashlight: SpotLight3D = $Head/Eyes/Camera3D/FlashLightNode/Flashlight

@onready var interact_shapecast: ShapeCast3D = %InteractShapeCast
@onready var hold_position: Marker3D = $Head/Eyes/Camera3D/HoldPosition

@export var walking_speed 	:= 5.0
@export var sprinting_speed := 6.5
@export var crouching_speed := 3.0
@export var swimming_speed  := 4.0

@export var sway_amount : float = 5.0
@export var smooth_speed : float = 10.0

@export var base_fov 	:= 75.0
@export var sprint_fov 	:= 85.0

# SPEED VARS

var current_speed 			:= 0.0
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

const CameraTiltLeft 		:= 3.0
const CameraTiltRight 	:= -3.0

## FLASHLIGHT VARS
var flashlight_rotation_smoothness := 10.0
var flashlight_position_smoothness := 10.0

var default_flashlight_pos := Vector3.ZERO
var sway_target := Vector2.ZERO

var bob_freq 	:= 2.0
var bob_amp 	:= 1.0
var bob_time 	:= 0.0

# SPRINT FOV VARS
var zoom_fov := 10.0
var fov_change_speed 	:= 12.0
var target_fov = base_fov

# UI VARS

# INTERACT VARS

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
var rope_local_grab_dir: Vector3 = Vector3.ZERO

# SWIM VARS
var swim_up_speed 		:= 5
var base_light_energy: float = 1.0
var base_spot_range: float = 10.0
var is_swimming: bool = false
var head_in_water := false


# UPDRAFT VARS
var in_updraft: bool = false
var current_updraft_strength: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# DEVTOOLS VARS
var noclip_speed_multiplier := 4.0
var is_menu_open: bool = false

# ZIPLINE VARS
var zipline_grab_timer: float = 0.0
var is_auto_sliding: bool = false
var on_zipline: bool = false
var zipline_start: Vector3
var zipline_end: Vector3
var zipline_dir: Vector3
var zipline_length: float
var zipline_progress: float = 0.0
var is_zipline_sliding: bool = false

var ZIPLINE_SLIDE_SPEED: float = 18.0
var ZIPLINE_HANG_OFFSET: float = 1.9 # Distance from the wire to the player's origin

# SHOOT VARS
var damage = 100

# OTHER VARS
var input_dir: Vector2 = Vector2.ZERO
var _frames_since_grounded: int = 0
var is_using_zoom: bool = false




# --------------------------------------
# MAIN SCRIPT
# --------------------------------------
func _ready() -> void:
	Events.debug_menu_toggled.connect(_on_debug_menu_toggled)
	Events.noclip_ui_button_pressed.connect(toggle_noclip)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	default_flashlight_pos = flash_light_node.position
	flashlight.visible = false
	if flashlight:
		base_light_energy = flashlight.light_energy
		base_spot_range = flashlight.spot_range
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			noclip_speed_multiplier = min(100, noclip_speed_multiplier * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			noclip_speed_multiplier = max(0.1, noclip_speed_multiplier * 0.9)
			
	# --- COMBAT INPUTS ---
	if event.is_action_pressed("shoot"): 
		# Check if we have a weapon equipped in our hands
		var holder = %WeaponHolder
		if holder.get_child_count() > 0:
			var current_weapon = holder.get_child(0)
			
			# If the weapon has a shoot function, call it and pass the camera!
			if current_weapon.has_method("shoot"):
				current_weapon.shoot(cam) # Pass your Camera3D reference here
	
func _input(event: InputEvent) -> void:
	# MOUSE LOOKING LOGIC
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		sway_target += event.relative
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
	# ---------------------------------------------------------
	# 1. GLOBAL GATHERING (Things that apply to every state)
	# ---------------------------------------------------------
	input_dir = Input.get_vector("left", "right", "forward", "backward")
	if Input.is_action_pressed("zoom"):
		input_dir = Vector2.ZERO # Stop moving if zooming
		
	var is_truly_grounded = _frames_since_grounded < 3
	if is_on_floor(): _last_frame_was_on_floor = Engine.get_physics_frames()
	
	if is_on_floor() or _snapped_to_stairs_last_frame:
		_frames_since_grounded = 0
	else:
		_frames_since_grounded += 1

	# Check for swimming (this handles its own states internally)
	is_swimming = _handle_water_physics(delta)
	if not is_swimming: swimming = false

	# ---------------------------------------------------------
	# 2. THE STATE MACHINE (Only ONE of these will run per frame)
	# ---------------------------------------------------------
	if Input.is_action_just_pressed("noclip"):
		toggle_noclip()

	if flying:
		_handle_noclip_physics(delta)
		
	elif is_swimming:
		pass # Velocity is already handled perfectly inside _handle_water_physics!
		
	elif on_ladder:
		_handle_ladder_physics(delta)
		
	elif on_monkey_bars:
		_handle_monkey_bars_physics(delta)
		
	elif on_zipline:
		_handle_zipline_physics(delta)
		
	elif current_rope != null:
		_handle_rope_physics(delta)
		
	else:
		# If we aren't doing anything special, run standard walking/gravity
		_handle_ground_physics(delta, is_truly_grounded)

	# ---------------------------------------------------------
	# 3. FINALIZE MOVEMENT (Always happens at the very end)
	# ---------------------------------------------------------
	last_velocity = velocity 
	
	if not _snap_up_stairs_check(delta):
		move_and_slide()         
		_snap_down_to_stairs_check()
		
	_slide_camera_smooth_back_to_origin(delta)		
	
func _process(delta: float) -> void:
	# 1. FLASHLIGHT ANIMATION
	update_flashlight(delta)
	if Input.is_action_just_pressed("flashlight"):
		flashlight.visible = !flashlight.visible
		
	# 2. INTERACT & THROW
	current_interactable = get_interactable_component_at_shapecast()
	if current_interactable:
		current_interactable.hover_cursor(self)
	
	if Input.is_action_just_pressed("interact"):
		if held_object:
			held_object.drop()
			held_object = null
		elif current_interactable:
			current_interactable.interact_with()
			var parent_node = current_interactable.get_parent()
			if parent_node is PickableObject:
				held_object = parent_node
				held_object.pick_up(hold_position, self)
				
	if Input.is_action_just_pressed("shoot") and held_object:
		var throw_force = 12.0
		var throw_direction = -cam.global_transform.basis.z.normalized()
		throw_direction.y += 0.2 
		held_object.throw(throw_direction.normalized() * throw_force)
		held_object = null

	# 3. CAMERA ZOOM CONTROLS
	if Input.is_action_just_pressed("zoom"):
		Events.player_zoomed.emit(true)
		is_using_zoom = true
	elif Input.is_action_just_released("zoom"):
		Events.player_zoomed.emit(false)
		is_using_zoom = false
		
	if Input.is_action_pressed("zoom"):
		target_fov = zoom_fov
		mouse_sensitivity = mouse_sensitivity_zoom
	elif sprint_active and input_dir.length() > 0.1 and not is_swimming:
		target_fov = sprint_fov
		mouse_sensitivity = mouse_sensitivity_base    
	else:
		target_fov = base_fov
		mouse_sensitivity = mouse_sensitivity_base

	# 4. RENDER SMOOTH FOV (Only do this ONCE per frame!)
	cam.fov = lerp(cam.fov, target_fov, delta * fov_change_speed)
	
# ---------------------------------------------
# FUNCTIONS
# ---------------------------------------------
	
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
# MONKE BARS
# --------------------------------------
var on_monkey_bars: bool = false
var MONKEY_BAR_SPEED: float = 2.5 # Slower and heavier than the ladder

func enter_monkey_bars() -> void:
	on_monkey_bars = true
	# Optional: Snap vertical velocity to 0 the instant they grab the bars
	velocity.y = 0.0 

func exit_monkey_bars() -> void:
	on_monkey_bars = false
	
# --------------------------------------
# ROPES
# --------------------------------------
var on_rope: bool = false
func _on_rope_grabbed(rope_body: RigidBody3D) -> void:
	current_rope = rope_body
	velocity = Vector3.ZERO
	add_collision_exception_with(current_rope)
	on_rope = true
	
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
	on_rope = false

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

	# --- TRUE 3D SWIMMING ---
	input_dir = Input.get_vector("left", "right", "forward", "backward")
	var swim_dir = (cam.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var target_velocity = swim_dir * swimming_speed
		
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

# --- APPLY VERTICAL LERP (Swimming/Sinking) ---
	if not just_water_jumped:
		velocity.y = lerpf(velocity.y, target_velocity.y, 4.0 * delta)

	# --- THE LOST SWIMMING ANIMATIONS ---
	var target_anim = ""
	if input_dir.x > 0.1: # Moving Right
		target_anim = "swimming_underwater_sideways_right"
		eyes.rotation.z = lerp(eyes.rotation.z, deg_to_rad(CameraTiltRight * 2), delta * lerp_speed / 3)
	elif input_dir.x < -0.1: # Moving Left
		target_anim = "swimming_underwater_sideways_left"
		eyes.rotation.z = lerp(eyes.rotation.z, deg_to_rad(CameraTiltLeft * 2), delta * lerp_speed / 3)
	elif abs(input_dir.y) > 0.1: # Forward/Backward
		target_anim = "swimming"
		eyes.rotation.z = lerp(eyes.rotation.z, 0.0, delta * lerp_speed / 3)
	elif (Input.is_action_pressed("jump") or Input.is_action_pressed("sprint")) and head_in_water:
		target_anim = "swimming_up"
		eyes.rotation.z = lerp(eyes.rotation.z, 0.0, delta * lerp_speed / 3)
	else:
		target_anim = "RESET"
		eyes.rotation.z = lerp(eyes.rotation.z, 0.0, delta * lerp_speed / 3)
			
	if target_anim != "" and camera_anims.current_animation != target_anim:
		camera_anims.play(target_anim, 2)
	# ------------------------------------

	return true
	
func enter_updraft(strength: float) -> void:
	in_updraft = true
	current_updraft_strength = strength

func exit_updraft() -> void:
	in_updraft = false
	current_updraft_strength = 0.0
	
func toggle_noclip() -> void:
	walking = false
	sprinting = false
	crouching = false
	
	flying = !flying
	noclip_speed_multiplier = 4.0
	
	# Handle collisions ONCE when toggled, not every frame
	if flying:
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = true
	else:
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = false
		
	# Tell the UI to update its button text and messages
	Events.noclip_toggled.emit(flying)

# -----------------------------
# ZIPLINE LOGIC
# -----------------------------
func _on_zipline_grabbed(start_pos: Vector3, end_pos: Vector3) -> void:
	zipline_start = start_pos
	zipline_end = end_pos
	velocity = Vector3.ZERO
	on_zipline = true

	zipline_dir = (zipline_end - zipline_start).normalized()
	zipline_length = zipline_start.distance_to(zipline_end)

	var grab_point = Geometry3D.get_closest_point_to_segment(cam.global_position, zipline_start, zipline_end)
	var grab_distance = zipline_start.distance_to(grab_point)

	zipline_progress = grab_distance / zipline_length
	zipline_progress = clamp(zipline_progress, 0.05, 0.95)

	is_zipline_sliding = abs(zipline_dir.y) > 0.15

	# THE NEW MODE CHECK: Are we grabbing the top half or the bottom half?
	if is_zipline_sliding:
		var mid_point_y = (zipline_start.y + zipline_end.y) / 2.0
		# If you grab above the middle, it's a one-way trip!
		is_auto_sliding = global_position.y > mid_point_y
	else:
		is_auto_sliding = false

func _on_zipline_released() -> void:
	on_zipline = false
	velocity = (cam.global_transform.basis.z * -3.0) + Vector3(0, 1.5, 0)
	
func _on_debug_menu_toggled(is_open: bool) -> void:
	is_menu_open = is_open

# -------------------------------------------------------------------
# HELPER FUNCTIONS
# -------------------------------------------------------------------
func _handle_ground_physics(delta: float, is_truly_grounded: bool) -> void:
	# 1. CAMERA TILT
	if Input.is_action_pressed("left"):
		eyes.rotation.z = lerp(eyes.rotation.z, deg_to_rad(CameraTiltLeft), delta * lerp_speed)
	elif Input.is_action_pressed("right"):
		eyes.rotation.z = lerp(eyes.rotation.z, deg_to_rad(CameraTiltRight), delta * lerp_speed)
	else:
		eyes.rotation.z = lerp(eyes.rotation.z, deg_to_rad(0), delta * lerp_speed)

	# 2. CROUCHING
	if Input.is_action_pressed("crouch") and is_truly_grounded:
		if not crouching: 
			Events.player_crouch_changed.emit(true)
		crouching = true 
		current_speed = lerp(current_speed, crouching_speed, delta * lerp_speed)
		head.position.y = lerp(head.position.y, crouching_depth, delta * lerp_speed)
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
		walking = false
		sprinting = false

	# 3. STANDING UP
	elif !crouch_cast_check.is_colliding():
		if crouching: 
			Events.player_crouch_changed.emit(false)
		crouching = false 
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		head.position.y = lerp(head.position.y, 1.8, delta * lerp_speed)

	# 4. SPRINTING & WALKING
	var is_moving = input_dir.length() > 0.1
	
	if Input.is_action_pressed("sprint") and standing_collision_shape.disabled == false and is_moving and is_on_floor(): 
		sprint_active = true
	else:
		sprint_active = false
		
	if sprint_active:
		current_speed = lerp(current_speed, sprinting_speed, delta * lerp_speed)
		walking = false
		sprinting = true
	elif is_moving and crouching_collision_shape.disabled == true:
		current_speed = lerp(current_speed, walking_speed, delta * lerp_speed)
		walking = true    
		sprinting = false    

	# 5. HEADBOB
	_handle_headbob(delta) # (You should make a helper for headbob too!)

	# 6. JUMPING
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if sprinting:
			velocity.y = sprint_jump_velocity
		elif crouching:
			velocity.y = crouch_jump_velocity
		else:
			velocity.y = jump_velocity
		camera_anims.play("jump")
			
	# Handle landing anims...
	if is_on_floor():
		if last_velocity.y < 0.0:
			if sprinting: camera_anims.play("jump_landing")
			else: camera_anims.play("landing")

	# 7. APPLY MOVEMENT TO VELOCITY
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

	# 8. GRAVITY
	if in_updraft:
		velocity.y = lerp(velocity.y, current_updraft_strength, delta * 4.0)
	elif not is_on_floor():
		velocity.y -= gravity * delta

func _handle_ladder_physics(_delta: float) -> void:
	#if on_ladder:
	# 1. Force state restrictions
	sprinting = false
	crouching = false

	# 2. Get camera directions for Source-style movement
	var look_dir = -cam.global_transform.basis.z # Forward
	var right_dir = cam.global_transform.basis.x # Right

	# 3. Calculate movement vector based on where we are looking
	var ladder_vel = (look_dir * -input_dir.y) + (right_dir * input_dir.x)

	# 4. Apply speed
	velocity = ladder_vel.normalized() * LADDER_SPEED

	# 5. Dismount by jumping backwards off the ladder
	if Input.is_action_just_pressed("jump"):
		on_ladder = false
		velocity = -look_dir * 5.0 # Shove player backward
		velocity.y = 5.0 # And slightly up
			
func _handle_monkey_bars_physics(_delta: float) -> void:
	sprinting = false
	crouching = false

	# 2. Get camera directions
	var look_dir = -cam.global_transform.basis.z # Forward
	var right_dir = cam.global_transform.basis.x # Right
	
	# THE SECRET SAUCE: Flatten the Y axis so looking up/down doesn't move you vertically
	look_dir.y = 0
	right_dir.y = 0
	
	# Re-normalize so moving diagonally isn't faster
	look_dir = look_dir.normalized()
	right_dir = right_dir.normalized()

	# 3. Calculate horizontal movement vector
	var bar_vel = (look_dir * -input_dir.y) + (right_dir * input_dir.x)

	# 4. Apply speed and lock gravity
	velocity.x = bar_vel.x * MONKEY_BAR_SPEED
	velocity.z = bar_vel.z * MONKEY_BAR_SPEED
	velocity.y = 0.0 # Keeps you perfectly glued to the ceiling height
	
	var blend_time = 0.3
	if Input.is_action_pressed("forward"):
		# Only call play() if we are coming from a dead stop
		if camera_anims.assigned_animation != "MonkeMoves":
			camera_anims.play("MonkeMoves", blend_time)
		camera_anims.speed_scale = 1.0
		
	elif Input.is_action_pressed("backward"):
		# Only call play() if we are coming from a dead stop
		if camera_anims.assigned_animation != "MonkeMoves":
			camera_anims.play("MonkeMoves", blend_time)
		camera_anims.speed_scale = -1.0
		
	else:
		# We are idle. Crossfade back to the resting pose.
		if camera_anims.assigned_animation != "RESET":
			camera_anims.play("RESET", blend_time)
			camera_anims.speed_scale = 1.0 # Fix the speed so it doesn't try to play RESET backward!

	# 5. Dismount by dropping (Crouch or Jump)
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("crouch"):
		on_monkey_bars = false
		# Gravity will naturally take over on the very next frame
		
func _handle_zipline_physics(delta: float) -> void:
		#elif on_zipline:
	sprinting = false
	crouching = false
	walking = false

	# 1. Base directions
	var slide_direction = 1.0 if zipline_dir.y < 0 else -1.0
	var downhill_vector = zipline_dir * slide_direction

	var look_forward = -cam.global_transform.basis.z
	if not is_zipline_sliding:
		look_forward.y = 0
	look_forward = look_forward.normalized()

	# --- THE NEW MODE SWITCHER ---
	# If we are holding on manually, check if the player wants to let go and slide!
	if not is_auto_sliding and is_zipline_sliding:
		var looking_downhill = look_forward.dot(downhill_vector) > 0
		
		# ONLY trigger auto-slide if looking downhill AND pressing forward
		if Input.is_action_just_pressed("forward") and looking_downhill:
			is_auto_sliding = true
	# -----------------------------

	# 2. Apply Movement
	if is_auto_sliding:
		# UNSTOPPABLE GRAVITY SLIDE (Hands-free)
		zipline_progress += slide_direction * (ZIPLINE_SLIDE_SPEED / zipline_length) * delta
		
		if camera_anims.assigned_animation != "RESET":
			camera_anims.play("RESET", 0.3)
			camera_anims.speed_scale = 1.0
			
	else:
		# MANUAL CLIMBING (Going Uphill, Uphill-Backwards, or Flat wire)
		var move_input = -input_dir.y # +1 for W, -1 for S

		if move_input == 0:
			# Freeze in place when letting go of keys!
			if camera_anims.assigned_animation != "RESET":
				camera_anims.play("RESET", 0.3)
				camera_anims.speed_scale = 1.0
		else:
			var requested_dir = look_forward * move_input
			var move_amount = requested_dir.dot(zipline_dir)

			# Determine if our manual input is pushing us downhill
			var moving_downhill = false
			if is_zipline_sliding:
				if (slide_direction > 0 and move_amount > 0) or (slide_direction < 0 and move_amount < 0):
					moving_downhill = true
			
			# Uphill is a slow struggle. Downhill manual backing-up is regular climbing speed.
			current_speed = MONKEY_BAR_SPEED
			if is_zipline_sliding and not moving_downhill:
				current_speed *= 0.5 
				
			zipline_progress += move_amount * (current_speed / zipline_length) * delta

			# Play climbing animations
			if camera_anims.assigned_animation != "MonkeMoves":
				camera_anims.play("MonkeMoves", 0.3)
			camera_anims.speed_scale = sign(move_input)

	# 3. Apply exact position
	zipline_progress = clamp(zipline_progress, 0.0, 1.0)
	var target_pos = zipline_start.lerp(zipline_end, zipline_progress)
	target_pos.y -= ZIPLINE_HANG_OFFSET
	global_position = target_pos
	velocity = Vector3.ZERO

	# 4. Dismount checks
	if zipline_progress >= 1.0 or zipline_progress <= 0.0:
		_on_zipline_released()
	elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("crouch"):
		_on_zipline_released()
		
func _handle_rope_physics(delta: float) -> void:
	#if current_rope != null:
	sprinting = false
	crouching = false
	walking = false
	
	_handle_headbob(delta)

	var look_dir := -cam.global_transform.basis.z
		
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
			
func _handle_noclip_physics(delta: float) -> void:
	var fly_dir = (cam.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	current_speed = sprinting_speed * noclip_speed_multiplier

	Events.noclip_speed_changed.emit(noclip_speed_multiplier)
				
	if fly_dir:
		velocity = fly_dir * current_speed
	else:
		velocity = Vector3.ZERO
		direction = Vector3.ZERO
	
	if !swimming:
		if Input.is_action_pressed("left"):
			eyes.rotation.z = lerp(eyes.rotation.z, deg_to_rad(CameraTiltLeft), delta * lerp_speed)
		elif Input.is_action_pressed("right"):
			eyes.rotation.z = lerp(eyes.rotation.z, deg_to_rad(CameraTiltRight), delta * lerp_speed)
		else:
			eyes.rotation.z = lerp(eyes.rotation.z, deg_to_rad(0), delta * lerp_speed)

func _handle_headbob(delta: float) -> void:
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
