@tool
extends Area3D

@export_category("Level Design")
## Changes the size of the trigger box directly from the inspector.
@export var trigger_size: Vector3 = Vector3(2.0, 2.0, 2.0):
	set(value):
		trigger_size = value
		_update_bounds()

@export_category("Screenshake Settings")
@export var trigger_once: bool = true
@export_range(0.0, 16.0) var shake_intensity: float = 4.0
@export var shake_duration: float = 2.5

var _triggered: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	# Delete the visual mesh so it costs zero performance in the compiled game
	var editor_mesh: MeshInstance3D = get_node_or_null("EditorVisual")
	if editor_mesh:
		editor_mesh.queue_free()
		
	body_entered.connect(_on_body_entered)


func _update_bounds() -> void:
	# 1. Update the invisible physics collision shape
	var col: CollisionShape3D = get_node_or_null("CollisionShape3D")
	if col:
		if not col.shape:
			col.shape = BoxShape3D.new()
			
		# Duplicate the shape so resizing one trigger doesn't resize all of them!
		if not col.shape.resource_local_to_scene:
			col.shape = col.shape.duplicate()
			col.shape.resource_local_to_scene = true
			
		if col.shape is BoxShape3D:
			var box := col.shape as BoxShape3D
			box.size = trigger_size
			
	# 2. Update the visible editor mesh (if it exists)
	var mesh: MeshInstance3D = get_node_or_null("EditorVisual")
	if mesh and mesh.mesh is BoxMesh:
		var box_mesh := mesh.mesh as BoxMesh
		box_mesh.size = trigger_size


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
		
	if trigger_once and _triggered:
		return

	_triggered = true
	print("ScreenshakeTrigger activated by: ", body.name, ". Emitting event.")
	Events.screenshake_requested.emit(shake_intensity, shake_duration)
