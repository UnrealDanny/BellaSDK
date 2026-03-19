@tool
extends StaticBody3D


@onready var interact_component: Interact_Component = $Interact_Component
@onready var button: MeshInstance3D = $Button
@onready var button_base: MeshInstance3D = $ButtonBase
@onready var label_interact: Label3D = $LabelInteract

#@export var target_door: Node3D
@export var targets: Array[Node3D]

var press_tween: Tween
var can_press: bool = true
var looking_at: bool = false
@export var outline_material: ShaderMaterial

func _ready() -> void:
	if interact_component:
		interact_component.focused.connect(_on_focus)
		interact_component.unfocused.connect(_on_unfocus)
		
		interact_component.interacted.connect(_on_interact)
		
	label_interact.hide()

func _on_focus() -> void:
	if button and outline_material:
		button.material_overlay = outline_material
		
	looking_at = true
	label_interact.show()

func _on_unfocus() -> void:
	if button:
		button.material_overlay = null
	label_interact.hide()
		
	looking_at = false
		
func _on_interact() -> void:
	# Ensure we don't have a mesh error
	if not button or not can_press:
		return
		
	can_press = false
		
	# Kill the old tween if the player spams the interact button
	if press_tween and press_tween.is_valid():
		press_tween.kill()
		
	# Create a new sequential tween
	press_tween = create_tween()
	press_tween.tween_property(button, "position:y", 0.02, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	press_tween.tween_property(button, "position:y", -0.02, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	button.material_overlay = null
	
	#if target_door and target_door.has_method("interact"):
		#target_door.interact()
	for target in targets:
		if target != null and target.has_method("interact"):
			target.interact()

	await get_tree().create_timer(1.0).timeout
	can_press = true
	
	if looking_at and can_press:
		button.material_overlay = outline_material
		
		
# --- EDITOR DEBUG LINE ---

var debug_line: MeshInstance3D

func _process(_delta: float) -> void:
	# Engine.is_editor_hint() ensures this line NEVER draws while playing the game
	if Engine.is_editor_hint():
		_draw_connection_line()

func _draw_connection_line() -> void:
	# If no door is assigned, delete the line and stop
	if not targets:
		if debug_line:
			debug_line.queue_free()
		return

	# If the line doesn't exist yet, build it
	if not debug_line:
		debug_line = MeshInstance3D.new()
		add_child(debug_line)
		
		var immediate_mesh = ImmediateMesh.new()
		debug_line.mesh = immediate_mesh
		
		# Make the line bright red and ignore lighting
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color.RED
		debug_line.material_override = mat

	# Draw the line from the button to the door
	var mesh = debug_line.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	for target in targets:
		if target:
			mesh.surface_add_vertex(Vector3.ZERO) 
			mesh.surface_add_vertex(to_local(target.global_position)) 
	
	mesh.surface_end()
