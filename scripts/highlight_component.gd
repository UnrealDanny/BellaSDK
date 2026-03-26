extends Node
class_name HighlightComponent

@export var outline_material: ShaderMaterial

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
		_apply_outline(get_parent(), outline_material)

func _on_unfocus() -> void:
	_is_focused = false
	_apply_outline(get_parent(), null)

# --- NEW: THE SUPPRESSOR ---
# Allows other scripts (like the Valve) to temporarily hide the glow
func suppress(state: bool) -> void:
	_is_suppressed = state
	if _is_suppressed:
		_apply_outline(get_parent(), null)
	elif _is_focused:
		_apply_outline(get_parent(), outline_material)

func _apply_outline(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_overlay = mat
		
	for child in node.get_children():
		_apply_outline(child, mat)
