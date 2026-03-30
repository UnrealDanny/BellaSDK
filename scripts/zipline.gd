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

func _on_interact_component_interacted() -> void:
	# 1. If someone is already riding, completely ignore new clicks!
	if player_on_zipline: 
		return

	var player = interact_component.get_character_hovered_by_cur_camera()
	if player and player.has_method("_on_zipline_grabbed"):
		
		# 2. Lock the zipline so it can't be clicked again
		player_on_zipline = true
		
		var start_pos = to_global(curve.get_point_position(0))
		var end_pos = to_global(curve.get_point_position(curve.get_point_count() - 1))

		# 3. Pass 'self' as the first argument so the player can release it later!
		player._on_zipline_grabbed(self, start_pos, end_pos)
		
		# 4. Turn off the outline immediately
		if highlight_component:
			highlight_component.suppress(true)
		
# 5. The player script will call this when they jump off or reach the end
func on_player_released() -> void:
	player_on_zipline = false
	
	if highlight_component:
		highlight_component.suppress(false)
