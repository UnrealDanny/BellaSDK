@tool
extends UniversalCable3D 

@onready var interact_component: Interact_Component = $InteractArea/Interact_Component
@onready var highlight_component: HighlightComponent = $InteractArea/HighlightComponent

# --- THE LOCK ---
var player_on_zipline: bool = false

func _ready() -> void:
	super._ready()
	
	if Engine.is_editor_hint(): 
		return 
		
	if interact_component == null:
		push_error("Zipline: InteractComponent not found!")
		return
		
	interact_component.interacted.connect(_on_interact_component_interacted)

# Remove the underscore from 'player' so we can use it!
func _on_interact_component_interacted(player: CharacterBody3D) -> void:
	if player_on_zipline: return

	if player and player.has_method("_on_zipline_grabbed"):
		player_on_zipline = true
		
		# Point A is ALWAYS the start of the curve, Point B is ALWAYS the end
		var point_a := to_global(curve.get_point_position(0))
		var point_b := to_global(curve.get_point_position(curve.get_point_count() - 1))
		
		# Determine if the player is closer to the start or the end
		#var start_at_end : bool = player.global_position.distance_to(point_a) > player.global_position.distance_to(point_b)

		# We always pass Point A and Point B in the same order so 'zipline_dir' stays consistent
		player._on_zipline_grabbed(self, point_a, point_b)
		
		if highlight_component:
			highlight_component.suppress(true)
			
		
# 5. The player script will call this when they jump off or reach the end
func on_player_released() -> void:
	player_on_zipline = false
	
	if highlight_component:
		highlight_component.suppress(false)
