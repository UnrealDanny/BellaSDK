extends RigidBody3D
class_name PickableObject

@onready var interact_comp: Interact_Component = $Interact_Component
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $Label3D

@export var outline_material: ShaderMaterial

var is_held: bool = false
var hold_target: Marker3D = null # This will be a point in front of the player's camera
var holder: Node3D = null

func _ready() -> void:
	# Ensure the box behaves like a physical object in the world
	collision_layer = 1
	collision_mask = 1
	label.hide()
	

# The Player script will call this when grabbing the box
func pick_up(target: Marker3D, player: Node3D) -> void:
	is_held = true
	hold_target = target
	holder = player
	label.hide()
	
	freeze = true
	#gravity_scale = 0.0 
	mesh.transparency = 0.25

	# Optional: Turn off the glowing outline while carrying it
	interact_comp.is_currently_focused = false
	interact_comp.unfocused.emit()
	add_collision_exception_with(holder)
	
# The Player script will call this to let go
func drop() -> void:
	is_held = false
	hold_target = null
	#gravity_scale = 1.0 # Turn gravity back on so it falls!
	freeze = false
	
	mesh.transparency = 0.0
	
	if holder:
		remove_collision_exception_with(holder)
		holder = null

func _physics_process(_delta: float) -> void:
	if is_held and hold_target:
		#var direction = hold_target.global_position - global_position
		#linear_velocity = direction * 15.0
		#angular_velocity = lerp(angular_velocity, Vector3.ZERO, 0.1)
		global_transform = hold_target.global_transform


func _on_interact_component_focused() -> void:
	if mesh and outline_material:
		mesh.material_overlay = outline_material
		
	if !is_held:
		label.show()
	else:
		mesh.material_overlay = null
		
func _on_interact_component_unfocused() -> void:
	mesh.material_overlay = null
	label.hide()
	
func throw(impulse_vector: Vector3):
	# 1. Fire your existing drop logic to detach it from the player and wake up the physics
	drop()

	# 2. Apply the massive burst of speed!
	# (Assuming PickableObject extends RigidBody3D)
	apply_central_impulse(impulse_vector)
