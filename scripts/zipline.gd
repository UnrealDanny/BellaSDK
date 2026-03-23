@tool
extends Path3D # <-- Upgraded to Path3D!

@export var outline_material: ShaderMaterial 

@onready var interact_component: Interact_Component = $InteractArea/Interact_Component
@onready var wire_col: CollisionShape3D = $InteractArea/CollisionShape3D
@onready var wire_mesh: MeshInstance3D = $WireMesh

var looking_at: bool = false
var player_on_zipline: bool = false

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_update_wire()

func _update_wire() -> void:
	if not curve or curve.get_point_count() < 2: return

	# --- NEW: THE FOOLPROOF 2-POINT LOCK ---
	# If you accidentally click and make a 3rd, 4th, or 5th point,
	# the script instantly deletes them before they even render!
	while curve.get_point_count() > 2:
		curve.remove_point(curve.get_point_count() - 1)
	# ---------------------------------------

	if not wire_mesh or not wire_col: return

	if not curve or curve.get_point_count() < 2: return
	if not wire_mesh or not wire_col: return

	# 1. Grab exact points from the interactive curve and convert to world space
	var start_pos = to_global(curve.get_point_position(0))
	var end_pos = to_global(curve.get_point_position(curve.get_point_count() - 1))

	# 2. Math and Distances
	var distance = start_pos.distance_to(end_pos)
	var center = start_pos.lerp(end_pos, 0.5)
	var direction = (end_pos - start_pos).normalized()

	# 3. Size the mesh and collision
	if wire_mesh.mesh: wire_mesh.mesh.height = distance
	if wire_col.shape: wire_col.shape.height = distance

	# 4. Position the line
	wire_mesh.global_position = center

	var up_vector = Vector3.UP
	if abs(direction.y) > 0.99:
		up_vector = Vector3.RIGHT
		
	wire_mesh.look_at(end_pos, up_vector)
	wire_mesh.rotate_object_local(Vector3.RIGHT, PI / 2.0) 
	wire_col.global_transform = wire_mesh.global_transform

func _ready() -> void:
	if Engine.is_editor_hint(): 
		return 
		
	_update_wire() 
	
	if interact_component == null:
		push_error("Zipline: InteractComponent not found!")
		return
		
	if not interact_component.interacted.is_connected(_on_interact_component_interacted):
		interact_component.interacted.connect(_on_interact_component_interacted)
		
	if not interact_component.focused.is_connected(_on_interact_component_focused):
		interact_component.focused.connect(_on_interact_component_focused)
		
	if not interact_component.unfocused.is_connected(_on_interact_component_unfocused):
		interact_component.unfocused.connect(_on_interact_component_unfocused)

# --- INTERACTION & OUTLINES ---
func _on_interact_component_interacted() -> void:
	var player = interact_component.get_character_hovered_by_cur_camera()
	if player and player.has_method("_on_zipline_grabbed"):
		_on_interact_component_unfocused()
		# Send the curve points to the player perfectly!
		var start_pos = to_global(curve.get_point_position(0))
		var end_pos = to_global(curve.get_point_position(curve.get_point_count() - 1))

		player._on_zipline_grabbed(start_pos, end_pos)
		player_on_zipline = true
		_on_interact_component_unfocused() 
		
func on_player_released() -> void:
	player_on_zipline = false

func _on_interact_component_focused() -> void:
	#if player_on_zipline: return 
	#if wire_mesh and outline_material:
		#wire_mesh.material_overlay = outline_material
	#looking_at = true
	if wire_mesh and outline_material:
		wire_mesh.material_overlay = outline_material
	looking_at = true

func _on_interact_component_unfocused() -> void:
	if wire_mesh:
		wire_mesh.material_overlay = null
	looking_at = false
