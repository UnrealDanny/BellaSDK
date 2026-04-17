extends Node
class_name HighlightComponent

@export var outline_material: ShaderMaterial
## Leave this EMPTY for FBX/GLTF/OBJ files! The script will find them automatically.
@export var target_meshes: Array[MeshInstance3D] 

var _is_focused: bool = false
var _is_suppressed: bool = false

func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	var interact := get_parent().get_node_or_null("Interact_Component")
	if interact:
		interact.focused.connect(_on_focus)
		interact.unfocused.connect(_on_unfocus)
	else:
		push_warning("HighlightComponent: No Interact_Component found in parent!")

func _on_focus() -> void:
	_is_focused = true
	if not _is_suppressed:
		_update_materials(outline_material)

func _on_unfocus() -> void:
	_is_focused = false
	_update_materials(null)

func suppress(state: bool) -> void:
	_is_suppressed = state
	if _is_suppressed:
		_update_materials(null)
	elif _is_focused:
		_update_materials(outline_material)

func _update_materials(mat: Material) -> void:
	var actually_applied: int = 0
	
	# 1. If you manually assigned a mesh in the Inspector, use that.
	if target_meshes.size() > 0:
		for m in target_meshes:
			if m != null:
				_apply_to_mesh(m, mat)
				actually_applied += 1
				
	# 2. THE FBX/OBJ MAGIC
	# If the array is empty, ask the parent (the Valve Node3D) to dig through 
	# all of its children, infinitely deep, and return EVERY MeshInstance3D it finds.
	if actually_applied == 0:
		var all_hidden_meshes := get_parent().find_children("*", "MeshInstance3D")
		for m in all_hidden_meshes:
			_apply_to_mesh(m as MeshInstance3D, mat)

# --- THE NUCLEAR CULLING FIX ---
func _apply_to_mesh(mesh: MeshInstance3D, mat: Material) -> void:
	mesh.material_overlay = mat
	
	if mat != null:
		# extra_cull_margin fails on imported FBX files.
		# custom_aabb physically forces Godot to draw a massive 4x4x4 meter 
		# invisible box around the mesh. The camera can't miss it!
		mesh.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	else:
		# Clear the custom bounding box when we aren't looking at it
		mesh.custom_aabb = AABB()
