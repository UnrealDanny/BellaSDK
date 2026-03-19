@tool
extends Node3D

@onready var rope_body: RigidBody3D = $RopeBody
@onready var interact_component: Interact_Component = $RopeBody/Interact_Component
@onready var rope_mesh: MeshInstance3D = $RopeBody/MeshInstance3D
@onready var rope_col: CollisionShape3D = $RopeBody/CollisionShape3D
@onready var anchor: StaticBody3D = $Anchor
@onready var pivot: ConeTwistJoint3D = $Pivot

@export var outline_material: ShaderMaterial

var player_on_rope: bool = false

# This creates a slider in your editor!
@export_range(2.0, 30.0, 0.1) var rope_length: float = 5.0:
	set(value):
		rope_length = value
		_update_rope_size()

var looking_at: bool = false

func _ready() -> void:
	_update_rope_size()
	# We don't want interaction logic running inside the editor!

	if Engine.is_editor_hint(): return 
	
	if interact_component == null:
		push_error("Rope: InteractComponent not found")
		return
		
	interact_component.interacted.connect(_on_interacted)
	interact_component.focused.connect(_on_focus)
	interact_component.unfocused.connect(_on_unfocus)

func _update_rope_size() -> void:
	if not is_inside_tree() or rope_mesh == null or rope_col == null: return

	if rope_mesh.mesh: rope_mesh.mesh.height = rope_length
	if rope_col.shape: rope_col.shape.height = rope_length

	# Offset mesh and collision so they hang downward from the origin
	if rope_mesh: rope_mesh.position.y = -rope_length * 0.5
	if rope_col: rope_col.position.y = -rope_length * 0.5

	if anchor: anchor.position.y = 0.0
	if pivot: pivot.position.y = 0.0

	if rope_body: rope_body.position = Vector3.ZERO

# --- INTERACTION LOGIC BELOW ---

func _on_interacted() -> void:
	var player = interact_component.get_character_hovered_by_cur_camera()
	if player and player.has_method("_on_rope_grabbed"):
		player._on_rope_grabbed(rope_body)
		player_on_rope = true
		_on_unfocus() # Turn off the outline immediately upon grabbing!

func on_player_released() -> void:
	player_on_rope = false
	
func _on_focus() -> void:
	if player_on_rope: return  # ← don't show outline while player is on rope
	if rope_mesh and outline_material:
		rope_mesh.material_overlay = outline_material
	looking_at = true

func _on_unfocus() -> void:
	if rope_mesh:
		rope_mesh.material_overlay = null
	looking_at = false
