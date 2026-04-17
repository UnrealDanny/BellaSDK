@tool
extends UniversalCable3D 

@onready var interact_component: Interact_Component = $InteractArea/Interact_Component
@onready var highlight_component: HighlightComponent = $InteractArea/HighlightComponent

# NEW: Reference to the Label3D (Make sure this node exists in your scene!)
@onready var interact_label: Label3D = $InteractArea/Label3D
@export var label_offset_amount: float = 0.35

# --- THE LOCK ---
var player_on_zipline: bool = false

func _ready() -> void:
	super._ready()
	
	if Engine.is_editor_hint(): 
		return 
		
	if interact_component == null:
		push_error("Zipline: InteractComponent not found!")
		return
		
	# NEW: Hide label by default
	if interact_label:
		interact_label.hide()
		
	# NEW: Setup UI Text dynamically based on InputMap
	var action_name := "interact" 
	var events := InputMap.action_get_events(action_name)
	if events.size() > 0 and interact_label:
		var raw_text := events[0].as_text()
		var key_name := raw_text.split(" ")[0] 
		interact_label.text = "[" + key_name + "] to use ZIPLINE"
		
	# Connect signals
	interact_component.interacted.connect(_on_interact_component_interacted)
	
	# NEW: Connect focus signals to show/hide the label
	if not interact_component.focused.is_connected(_on_focused):
		interact_component.focused.connect(_on_focused)
	if not interact_component.unfocused.is_connected(_on_unfocused):
		interact_component.unfocused.connect(_on_unfocused)

# NEW: Move the label to where the player is looking
func _physics_process(_delta: float) -> void:
	if not is_inside_tree() or Engine.is_editor_hint(): return
	
	if interact_component and interact_component.is_currently_focused and not player_on_zipline:
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam and interact_label:
			var hit_point_val: Variant = interact_component.last_hit_position
			var hit_point: Vector3 = Vector3.ZERO
			
			if hit_point_val is Vector3:
				hit_point = hit_point_val
			
			var cam_right: Vector3 = cam.global_transform.basis.x
			var cam_up: Vector3 = cam.global_transform.basis.y
			
			var final_pos: Vector3 = hit_point + (cam_right * label_offset_amount) + (cam_up * 0.1)
			interact_label.global_position = final_pos

# NEW: Helper functions to show/hide the label
func _on_focused() -> void:
	if not player_on_zipline and interact_label:
		interact_label.show()

func _on_unfocused() -> void:
	if interact_label:
		interact_label.hide()

func _on_interact_component_interacted(player: CharacterBody3D) -> void:
	force_grab_zipline(player)
	
	if player_on_zipline: return

	if player and player.has_method("_on_zipline_grabbed"):
		player_on_zipline = true
		
		# NEW: Hide the label the moment the player interacts
		if interact_label:
			interact_label.hide()
		
		# Point A is ALWAYS the start of the curve, Point B is ALWAYS the end
		var point_a := to_global(curve.get_point_position(0))
		var point_b := to_global(curve.get_point_position(curve.get_point_count() - 1))
		
		# We always pass Point A and Point B in the same order so 'zipline_dir' stays consistent
		player._on_zipline_grabbed(self, point_a, point_b)
		
		if highlight_component:
			highlight_component.suppress(true)
			
# The player script will call this when they jump off or reach the end
func on_player_released() -> void:
	player_on_zipline = false
	
	if highlight_component:
		highlight_component.suppress(false)

func force_grab_zipline(player: CharacterBody3D) -> void:
	if player_on_zipline: return

	if player and player.has_method("_on_zipline_grabbed"):
		player_on_zipline = true
		
		if interact_label:
			interact_label.hide()
		
		# Point A is ALWAYS the start of the curve, Point B is ALWAYS the end
		var point_a := to_global(curve.get_point_position(0))
		var point_b := to_global(curve.get_point_position(curve.get_point_count() - 1))
		
		player._on_zipline_grabbed(self, point_a, point_b)
		
		if highlight_component:
			highlight_component.suppress(true)
