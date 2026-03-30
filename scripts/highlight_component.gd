extends Node
class_name HighlightComponent

@export var outline_material: ShaderMaterial
# The new array! Assign ONLY the moving 'Button' MeshInstance3D here in the Inspector.
## Use this if you want to highlight a specific mesh. Otherwise everything will be highlihted
@export var target_meshes: Array[MeshInstance3D] 

var _is_focused: bool = false
var _is_suppressed: bool = false

func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	var interact = get_parent().get_node_or_null("Interact_Component")
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

# --- THE FIX IS HERE ---
# A router function that decides whether to use the specific array or the recursive fallback
func _update_materials(mat: Material) -> void:
	if target_meshes.size() > 0:
		# Array has items! ONLY highlight what is explicitly assigned.
		for mesh in target_meshes:
			if mesh != null:
				mesh.material_overlay = mat
	else:
		# Array is empty. Fallback to highlighting the parent and everything inside it.
		_apply_outline_recursive(get_parent(), mat)

# The old recursive function, renamed for clarity
func _apply_outline_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_overlay = mat
		
	for child in node.get_children():
		_apply_outline_recursive(child, mat)
