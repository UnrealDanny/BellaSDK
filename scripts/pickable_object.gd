extends RigidBody3D
class_name PickableObject

@export_category("Pickable Nodes")
@export var interact_comp: Interact_Component
@export var mesh: MeshInstance3D
@export var label: Label3D
@export var outline_material: ShaderMaterial

var is_held: bool = false
var hold_target: Marker3D = null
var holder: Node3D = null

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	if label: label.hide()
	
	if interact_comp:
		if not interact_comp.focused.is_connected(_on_interact_component_focused):
			interact_comp.focused.connect(_on_interact_component_focused)
		if not interact_comp.unfocused.is_connected(_on_interact_component_unfocused):
			interact_comp.unfocused.connect(_on_interact_component_unfocused)

func pick_up(target: Marker3D, player: Node3D) -> void:
	is_held = true
	hold_target = target
	holder = player
	if label: label.hide()
	
	freeze = false 
	gravity_scale = 0.0 
	if mesh: mesh.transparency = 0.25

	if interact_comp:
		interact_comp.is_currently_focused = false
		interact_comp.unfocused.emit()
	add_collision_exception_with(holder)
	
func drop() -> void:
	is_held = false
	hold_target = null
	gravity_scale = 1.0 
	
	if mesh: mesh.transparency = 0.0
	if holder:
		remove_collision_exception_with(holder)
		holder = null

func _physics_process(delta: float) -> void:
	if is_held and hold_target:
		var target_pos = hold_target.global_position
		var current_pos = global_position
		var distance_vector = target_pos - current_pos
		linear_velocity = distance_vector * 20.0
		angular_velocity = angular_velocity.lerp(Vector3.ZERO, 15.0 * delta)

func _on_interact_component_focused() -> void:
	if mesh and outline_material:
		mesh.material_overlay = outline_material
		
	if !is_held and label:
		_update_label_text()
		label.show()
	elif is_held and mesh:
		mesh.material_overlay = null

# NEW: Helper to fetch the current key from the InputMap
func _update_label_text() -> void:
	if not label: return
	
	var events = InputMap.action_get_events("interact")
	var key_name = "???"
	
	if events.size() > 0:
		var raw_text = events[0].as_text()
		
		# Keep the cleaning chain so "Left Mouse Button" stays "LMB"
		key_name = raw_text.replace(" (Physical)", "") \
						   .replace(" - Physical", "") \
						   .replace(" (Physics)", "") \
						   .replace(" - Physics", "") \
						   .replace("Left Mouse Button", "LMB") \
						   .replace("Right Mouse Button", "RMB") \
						   .replace("Middle Mouse Button", "MMB") \
						   .strip_edges()
	
	# Just the button in brackets. Example: "[E]" or "[LMB]"
	label.text = "[%s]" % [key_name]
		
func _on_interact_component_unfocused() -> void:
	if mesh: mesh.material_overlay = null
	if label: label.hide()
	
func throw(impulse_vector: Vector3):
	drop()
	apply_central_impulse(impulse_vector)
