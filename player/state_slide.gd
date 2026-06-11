class_name StateSlide
extends PlayerState

# --------------------------------------
# EXPORTS
# --------------------------------------
@export_category("Slide Physics")
@export var slide_acceleration: float = 15.0
@export var max_slide_speed: float = 25.0
@export var slide_steering_speed: float = 8.0

# --------------------------------------
# STATE METHODS
# --------------------------------------
func enter(_msg: Dictionary = {}) -> void:
	print("StateSlide: enter() called. Player locked into slide.")
	
	player.crouching = true
	player.standing_collision.disabled = true
	player.crouching_collision.disabled = false

func exit() -> void:
	print("StateSlide: exit() called. Restoring default collision state.")
	
	if not player.crouch_cast_check.is_colliding():
		print("StateSlide: Headroom clear. Standing up.")
		player.crouching = false
		player.standing_collision.disabled = false
		player.crouching_collision.disabled = true

func physics_update(delta: float) -> void:
	# 1. Exit Condition: Airborne
	if not player.is_on_floor():
		print("StateSlide: Floor lost. Transitioning to Air.")
		state_machine.transition_to("Air")
		return

	var floor_normal: Vector3 = player.get_floor_normal()

	# 2. Exit Condition: Floor flattened out and momentum is lost
	if floor_normal.y > 0.99 and player.velocity.length_squared() < 1.0:
		print("StateSlide: Ground flat, low speed. Transitioning to Ground.")
		state_machine.transition_to("Ground")
		return

	# 3. Calculate downhill direction safely
	var downhill_dir: Vector3 = Vector3.DOWN.slide(floor_normal)
	if downhill_dir.length_squared() > 0.0001:
		downhill_dir = downhill_dir.normalized()
	else:
		downhill_dir = Vector3.ZERO

	# 4. Continuously accelerate down the slope using existing momentum
	player.velocity += downhill_dir * slide_acceleration * delta

	# 5. Handle Steering (Left/Right)
	var input_dir: Vector2 = Input.get_vector("left", "right", "forward", "backward")
	var camera_right: Vector3 = player.camera.global_transform.basis.x.normalized()
	var steer_dir: Vector3 = camera_right.slide(floor_normal)
	
	if steer_dir.length_squared() > 0.0001:
		steer_dir = steer_dir.normalized()
	else:
		steer_dir = Vector3.ZERO

	# Extract lateral momentum to steer without killing forward/downhill momentum
	var current_lateral: Vector3 = player.velocity.project(steer_dir)
	var forward_momentum: Vector3 = player.velocity - current_lateral

	# Calculate target steering and apply a smooth lerp for better game feel
	var target_lateral: Vector3 = steer_dir * (input_dir.x * slide_steering_speed)
	current_lateral = current_lateral.lerp(target_lateral, 10.0 * delta)

	# Recombine velocity
	player.velocity = forward_momentum + current_lateral

	# 6. Absolute speed cap
	if player.velocity.length_squared() > (max_slide_speed * max_slide_speed):
		print("StateSlide: Max speed reached. Capping velocity.")
		player.velocity = player.velocity.limit_length(max_slide_speed)

	# Apply gravity to keep glued to slopes
	player.velocity.y -= player.gravity * delta

	player.move_and_slide()

	# 7. Update Decoupled Components
	_update_components(delta, input_dir)

func _update_components(delta: float, input_dir: Vector2) -> void:
	print("StateSlide: Updating camera, footsteps, and interaction scanner.")
	player.camera_controller.update_camera(
		delta, input_dir, false, true, true, player.velocity.length() 
	)
	
	player.footstep_manager.process_surface_and_footsteps(
		delta, true, player.velocity.length(), false, true
	)
	
	player.interaction_scanner.process_interaction(delta)
