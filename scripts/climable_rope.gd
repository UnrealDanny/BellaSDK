@tool
extends Node3D

@onready var rope_body: RigidBody3D = $RopeBody
@onready var interact_component: Interact_Component = $RopeBody/Interact_Component
@onready var highlight_component: HighlightComponent = $RopeBody/HighlightComponent 
@onready var rope_mesh: MeshInstance3D = $RopeBody/MeshInstance3D
@onready var rope_col: CollisionShape3D = $RopeBody/CollisionShape3D
@onready var anchor: StaticBody3D = $Anchor
@onready var pivot: ConeTwistJoint3D = $Pivot
@onready var interact_label: Label3D = $RopeBody/Label3D

var player_on_rope: bool = false

# --- NEW: SWING VARS ---
@export_category("Rope Properties")
@export var is_swingable: bool = false
@export var swing_force: float = 150.0 # Increased significantly so you actually move!
@export var label_offset_amount: float = 0.35


# --- SLOMO VARS ---
@export var activate_slomo: bool = false
var slomo_tween: Tween

@export_range(2.0, 30.0, 0.1) var rope_length: float = 5.0:
	set(value):
		rope_length = value
		_update_rope_size()

# climable_rope.gd
func _ready() -> void:
	interact_label.hide()
	_update_rope_size()
	
	if Engine.is_editor_hint(): return 
	
	# --- PHYSICS SETUP ---
	if rope_body:
		rope_body.freeze = not is_swingable
		rope_body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		rope_body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		rope_body.angular_damp = 2.5
		rope_body.linear_damp = 1.5

	if interact_component == null: return
		
	# --- UI SETUP ---
	# Fix: Use the variable we declared to satisfy the compiler
	var action_name := "interact" 
	var events := InputMap.action_get_events(action_name)
	
	if events.size() > 0:
		var raw_text := events[0].as_text()
		var key_name := raw_text.split(" ")[0] 
		interact_label.text = "[" + key_name + "] CLIMB"
	
	# --- SIGNAL CONNECTIONS ---
	# Fix: Always check is_connected to prevent the "Already Connected" error
	if not interact_component.interacted.is_connected(_on_interacted):
		interact_component.interacted.connect(_on_interacted)
		
	if not interact_component.focused.is_connected(_on_focused):
		interact_component.focused.connect(_on_focused)
		
	if not interact_component.unfocused.is_connected(_on_unfocused):
		interact_component.unfocused.connect(_on_unfocused)

	# Connect signals (using the pattern we established)
	if not interact_component.interacted.is_connected(_on_interacted):
		interact_component.interacted.connect(_on_interacted)
	if not interact_component.focused.is_connected(_on_focused):
		interact_component.focused.connect(_on_focused)
	if not interact_component.unfocused.is_connected(_on_unfocused):
		interact_component.unfocused.connect(_on_unfocused)
		
# --- THE SLOMO ENGINE ---
func _set_slomo(target_scale: float) -> void:
	if slomo_tween:
		slomo_tween.kill()
	
	slomo_tween = create_tween()
	# CRITICAL: We tell the tween to ignore time_scale so the 
	# transition remains fast even while the game slows down!
	slomo_tween.set_ignore_time_scale(true)
	slomo_tween.tween_property(Engine, "time_scale", target_scale, 0.25)
	#slomo_tween.tween_property(Engine, "time_scale", target_scale, 0.25)\
		#.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _physics_process(_delta: float) -> void:
	# 1. Safety check for Tool Mode
	if not is_inside_tree(): return
	
	# 2. Get the node as a generic Object to bypass the "Node" type restriction
	var comp: Object = get_node_or_null("RopeBody/Interact_Component")
	
	# 3. Use .get() to check the variables safely
	# This avoids the "Invalid Access" error because it's a dynamic check
	if comp and comp.get("is_currently_focused") == true and not player_on_rope:
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam:
			# THE FIX: Explicitly type hit_point_val as a Variant
			var hit_point_val: Variant = comp.get("last_hit_position")
			var hit_point: Vector3 = Vector3.ZERO
			
			# Check if the variant is actually the Vector3 we want
			if hit_point_val is Vector3:
				hit_point = hit_point_val
			
			# Proceed with the rest of the math
			var cam_right: Vector3 = cam.global_transform.basis.x
			var cam_up: Vector3 = cam.global_transform.basis.y
			
			var final_pos: Vector3 = hit_point + (cam_right * label_offset_amount) + (cam_up * 0.1)
			interact_label.global_position = final_pos
		
# Helper functions for the signals (keeps _ready clean)
func _on_focused() -> void:
	if not player_on_rope:
		interact_label.show()
		if activate_slomo:
			_set_slomo(0.3) # Slow things down to 30%

func _on_unfocused() -> void:
	interact_label.hide()
	# If we look away without grabbing, return to normal
	if activate_slomo:
		_set_slomo(1.0)
	
func _update_rope_size() -> void:
	if not is_inside_tree() or rope_mesh == null or rope_col == null: return

	if rope_mesh.mesh: rope_mesh.mesh.height = rope_length
	if rope_col.shape: rope_col.shape.height = rope_length

	if rope_mesh: rope_mesh.position.y = -rope_length * 0.5
	if rope_col: rope_col.position.y = -rope_length * 0.5

	if anchor: anchor.position.y = 0.0
	if pivot: pivot.position.y = 0.0

	if rope_body: rope_body.position = Vector3.ZERO

# Update this function to receive the player directly
func _on_interacted(player: CharacterBody3D) -> void:
	if player.has_method("_on_rope_grabbed"):
		player.call("_on_rope_grabbed", rope_body)
		player_on_rope = true
		interact_label.hide()
		
		if activate_slomo:
			_set_slomo(1.0)
		
		rope_body.angular_damp = 0.0
		rope_body.linear_damp = 0.0
		if highlight_component: highlight_component.suppress(true)

func on_player_released() -> void:
	player_on_rope = false
	
	# THE BRAKE FIX: Crank up the air friction the millisecond you let go.
	# The physics engine will mathematically kill the swing within roughly 3 seconds.
	if rope_body:
		rope_body.angular_damp = 2.5
		rope_body.linear_damp = 1.5
	
	if highlight_component:
		highlight_component.suppress(false)
		
	if activate_slomo:
		Engine.time_scale = 1.0
