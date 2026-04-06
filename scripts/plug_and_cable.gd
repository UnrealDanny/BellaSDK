extends Node3D

@export_group("Cable Setup")
@export var plug: RigidBody3D
@export var path: Path3D

@export_group("Cable Physics")
## How much the cable droops towards the floor.
@export var sag_amount: float = 0.5

var curve: Curve3D

func _ready() -> void:
	if path:
		curve = path.curve
		curve.clear_points()
		
		# Point 0: The Wall (Root Node position)
		curve.add_point(Vector3.ZERO)
		
		# Point 1: The Plug
		if plug:
			var start_pos := to_local(plug.global_position)
			
			# --- THE FIX: Prevent zero-length AND perfectly vertical lines! ---
			# If the plug is too close, or sitting perfectly straight down/up from the root:
			if start_pos.length() < 0.1 or (abs(start_pos.x) < 0.01 and abs(start_pos.z) < 0.01):
				start_pos = Vector3(0.05, -0.1, 0.05) # Add slight X/Z offset so it's not parallel to world UP
			# ------------------------------------------------------------------
			
			curve.add_point(start_pos)
			
			# Calculate the sag IMMEDIATELY on frame 0 so the CSG mesh doesn't crash on load
			var distance: float = maxf(0.1, Vector3.ZERO.distance_to(start_pos))
			var current_sag: float = distance * sag_amount
			curve.set_point_out(0, Vector3(0, -current_sag, 0))
			curve.set_point_in(1, Vector3(0, -current_sag, 0))

func _process(_delta: float) -> void:
	if not curve or not plug: 
		return
	
	var plug_local_pos := to_local(plug.global_position)
	
	# Apply the same safety check during gameplay so the player can't crash the game 
	# by holding the plug perfectly still in the exact center of the socket.
	if plug_local_pos.length() < 0.1 or (abs(plug_local_pos.x) < 0.01 and abs(plug_local_pos.z) < 0.01):
		plug_local_pos = Vector3(0.05, -0.1, 0.05)
		
	curve.set_point_position(1, plug_local_pos)
	
	var distance: float = maxf(0.1, Vector3.ZERO.distance_to(plug_local_pos))
	var current_sag: float = distance * sag_amount
	
	curve.set_point_out(0, Vector3(0, -current_sag, 0))
	curve.set_point_in(1, Vector3(0, -current_sag, 0))
