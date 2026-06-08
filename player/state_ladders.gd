class_name StateLadder
extends PlayerState

# --------------------------------------
# CONSTANTS
# --------------------------------------
const LADDER_SPEED: float = 5.0
const MAX_LADDER_SIDE_DIST: float = 0.6  # How far left/right you can go before stopping
const LADDER_CENTER_SNAP_SPEED: float = 8.0  # How fast you slide back to the middle

# --------------------------------------
# VARIABLES
# --------------------------------------
var current_ladder: Node3D = null


func enter(msg: Dictionary = {}) -> void:
	print("StateLadder: Initializing ladder state.")
	if msg.has("ladder_node"):
		current_ladder = msg["ladder_node"]
		_snap_to_ladder()


func exit() -> void:
	print("StateLadder: Exiting ladder state.")
	current_ladder = null


func physics_update(_delta: float) -> void:
	_handle_crouch_state()

	var input_dir: Vector2 = Input.get_vector("left", "right", "forward", "backward")

	# Calculate movement and apply it
	_calculate_ladder_velocity(input_dir)
	player.move_and_slide()

	# Check for dismounts (Jumping off, climbing to the top, hitting the floor)
	_handle_jump_input(input_dir)
	_check_transitions()


# --------------------------------------
# PRIVATE METHODS
# --------------------------------------
func _snap_to_ladder() -> void:
	if not current_ladder:
		return

	var push_out_distance: float = 0.6
	var ladder_forward: Vector3 = current_ladder.global_transform.basis.z.normalized()
	var target_pos: Vector3 = current_ladder.global_position + (ladder_forward * push_out_distance)
	target_pos.y = player.global_position.y  # Keep current height

	var tween := create_tween()
	(
		tween
		. tween_property(player, "global_position", target_pos, 0.15)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)


func _handle_crouch_state() -> void:
	var previous_crouch: bool = player.crouching
	player.crouching = Input.is_action_pressed("crouch")

	if player.crouching != previous_crouch:
		Events.player_crouch_changed.emit(player.crouching)


func _calculate_ladder_velocity(input_dir: Vector2) -> void:
	if not current_ladder:
		return

	# If crouching, slide down fast
	if player.crouching:
		player.velocity = Vector3.DOWN * LADDER_SPEED
		return

	var look_dir: Vector3 = -player.camera.global_transform.basis.z
	var right_dir: Vector3 = player.camera.global_transform.basis.x

	var local_pos: Vector3 = current_ladder.to_local(player.global_position)
	var offset_from_center: float = local_pos.x

	var ladder_right: Vector3 = current_ladder.global_transform.basis.x.normalized()
	var ladder_forward: Vector3 = current_ladder.global_transform.basis.z.normalized()

	# 1. W/S Input Projection
	var lateral_weight_ws: float = look_dir.dot(ladder_right)
	var vertical_weight_ws: float = 1.0 - absf(lateral_weight_ws)
	if look_dir.y < -0.15:
		vertical_weight_ws *= -1.0

	var forward_input: float = -input_dir.y
	var ws_lateral: float = lateral_weight_ws * forward_input
	var ws_vertical: float = vertical_weight_ws * forward_input

	# 2. A/D Input Projection
	var lateral_weight_ad: float = right_dir.dot(ladder_right)
	var vertical_weight_ad: float = 1.0 - absf(lateral_weight_ad)
	if right_dir.y < -0.15:
		vertical_weight_ad *= -1.0

	var strafe_input: float = input_dir.x
	var ad_lateral: float = lateral_weight_ad * strafe_input
	var ad_vertical: float = vertical_weight_ad * strafe_input

	# 3. Combine Intent
	var plane_intent := Vector2(ws_lateral + ad_lateral, ws_vertical + ad_vertical)
	if plane_intent.length() > 1.0:
		plane_intent = plane_intent.normalized()

	var intended_lateral: float = plane_intent.x
	var up_down_movement: float = plane_intent.y
	var lateral_movement: Vector3 = Vector3.ZERO

	# 4. Lateral Bounding & Centering
	if absf(intended_lateral) > 0.05:
		if intended_lateral > 0 and offset_from_center >= MAX_LADDER_SIDE_DIST:
			lateral_movement = Vector3.ZERO
		elif intended_lateral < 0 and offset_from_center <= -MAX_LADDER_SIDE_DIST:
			lateral_movement = Vector3.ZERO
		else:
			lateral_movement = ladder_right * intended_lateral * LADDER_SPEED
	else:
		lateral_movement = -ladder_right * (offset_from_center * LADDER_CENTER_SNAP_SPEED)
		if lateral_movement.length() > LADDER_SPEED:
			lateral_movement = lateral_movement.normalized() * LADDER_SPEED

	# 5. Depth Pull (Stick to the ladder surface)
	var depth_pull: Vector3 = -ladder_forward * (local_pos.z * 4.0)

	player.velocity = (Vector3.UP * up_down_movement * LADDER_SPEED) + lateral_movement + depth_pull


func _handle_jump_input(input_dir: Vector2) -> void:
	if not Input.is_action_just_pressed("jump") or not current_ladder:
		return

	var look_dir: Vector3 = -player.camera.global_transform.basis.z
	
	# CONDITION: Block jump entirely when looking up (Pitch threshold 0.3)
	if look_dir.y > 0.3:
		print("StateLadder: Jump blocked. Player is looking up.")
		return

	var right_dir: Vector3 = player.camera.global_transform.basis.x
	var ladder_outward: Vector3 = current_ladder.global_transform.basis.z.normalized()
	
	# FLATTEN VECTORS
	var flat_look: Vector3 = Vector3(look_dir.x, 0.0, look_dir.z).normalized()
	var flat_outward: Vector3 = Vector3(ladder_outward.x, 0.0, ladder_outward.z).normalized()
	var flat_right: Vector3 = Vector3(right_dir.x, 0.0, right_dir.z).normalized()
	
	var dot_outward: float = flat_look.dot(flat_outward)
	var strafe_input: float = input_dir.x
	
	# ---------------------------------------------------------
	# INTENT 1: SIDE JUMP (Ladder to Ladder)
	# ---------------------------------------------------------
	if absf(strafe_input) > 0.1:
		print("StateLadder: Intentional Side Jump. Pushing laterally.")
		player.velocity = (flat_right * strafe_input * 7.5) + Vector3(0.0, 4.5, 0.0)
		player.move_and_slide() # Force impulse to register immediately
		state_machine.transition_to("Air")
		return
		
	# ---------------------------------------------------------
	# INTENT 2: BACK EJECT (Looking away from the ladder)
	# ---------------------------------------------------------
	if dot_outward > 0.2:
		print("StateLadder: Intentional Back Eject. Pushing in look direction.")
		# Bumped lateral velocity slightly to 7.0 to ensure a clean break
		player.velocity = (flat_look * 7.0) + Vector3(0.0, 4.5, 0.0)
		player.move_and_slide() # Force impulse to register immediately
		state_machine.transition_to("Air")
		return
		
	# ---------------------------------------------------------
	# INTENT 3: BLOCKED (Looking at the ladder)
	# ---------------------------------------------------------
	print("StateLadder: Jump blocked. Player is facing the ladder.")


func _check_transitions() -> void:
	if player.is_on_floor() and player.velocity.y < 0.0:
		# Dismount on the ground
		state_machine.transition_to("Ground")
