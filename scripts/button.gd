@tool
extends StaticBody3D

@onready var interact_component: Interact_Component = $Interact_Component
@onready var highlight_component: HighlightComponent = $HighlightComponent # Add this reference
@onready var button: MeshInstance3D = $Button
@onready var button_base: MeshInstance3D = $ButtonBase
@onready var label_interact: Label3D = $LabelInteract

@export var targets: Array[Node3D]

var press_tween: Tween
var can_press: bool = true

func _ready() -> void:
	if interact_component and not Engine.is_editor_hint():
		interact_component.focused.connect(_on_focus)
		interact_component.unfocused.connect(_on_unfocus)
		interact_component.interacted.connect(_on_interact)
		
	label_interact.hide()

func _on_focus() -> void:
	# Highlighting is now handled automatically by HighlightComponent
	label_interact.show()

func _on_unfocus() -> void:
	# Un-highlighting is now handled automatically by HighlightComponent
	label_interact.hide()
		
func _on_interact(_player: CharacterBody3D) -> void:
	if not button or not can_press:
		return
		
	can_press = false
	
	# Temporarily hide the glow while the animation plays
	if highlight_component:
		highlight_component.suppress(true)
		
	if press_tween and press_tween.is_valid():
		press_tween.kill()
		
	press_tween = create_tween()
	press_tween.tween_property(button, "position:y", 0.02, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	press_tween.tween_property(button, "position:y", -0.02, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	for target in targets:
		if target != null and target.has_method("interact"):
			target.interact()

	await get_tree().create_timer(1.0).timeout
	can_press = true
	
	# Un-suppress the glow. If the player is still looking at it, it will glow again.
	if highlight_component:
		highlight_component.suppress(false)
		
# --- EDITOR DEBUG LINE ---

var debug_line: MeshInstance3D

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_draw_connection_line()

func _draw_connection_line() -> void:
	if not targets:
		if debug_line:
			debug_line.queue_free()
		return

	if not debug_line:
		debug_line = MeshInstance3D.new()
		add_child(debug_line)
		
		var immediate_mesh := ImmediateMesh.new()
		debug_line.mesh = immediate_mesh
		
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color.RED
		debug_line.material_override = mat

	var mesh := debug_line.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	for target in targets:
		if target:
			mesh.surface_add_vertex(Vector3.ZERO) 
			mesh.surface_add_vertex(to_local(target.global_position)) 
	
	mesh.surface_end()
