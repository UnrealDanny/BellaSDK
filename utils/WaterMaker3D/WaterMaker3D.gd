@tool
extends CSGBox3D

@export var water_texture_move_speed := Vector3(0.0025, 0.0025, 0.0025)
@export var water_texture_uv_scale := 0.04
@export var water_color := Color(0.3098039329052, 0.54117649793625, 0.86666667461395, 0.38823530077934)
@export var fog_color := Color(0, 0.04313725605607, 0.15686275064945)
@export_range(0.0, 250.0) var fog_fade_dist := 5.0

static var last_frame_drew_underwater_effect : int = -999

func _ready() -> void:
	self.process_priority = 999 # Call _process last to update move after any camera movement
	
# Track the current camera with an area so we can check if it is inside the water
# CHANGED: void -> bool so we can actually return true/false
func should_draw_camera_underwater_effect() -> bool: 
	var viewport: Viewport = get_viewport()
	# CASTING: Ensure 'camera' isn't a Variant
	var camera: Camera3D = viewport.get_camera_3d() if viewport else null
	
	if not camera: 
		return false
		
	# TYPING: Explicitly defining the AABB type
	var aabb: AABB = (global_transform * get_aabb()).grow(0.025)
	
	if not aabb.has_point(camera.global_position): 
		return false
		
	# TYPING: Ensure frame check is compared correctly
	if last_frame_drew_underwater_effect == Engine.get_process_frames(): 
		return false
	
	%CameraPosShapeCast3D.global_position = camera.global_position
	%CameraPosShapeCast3D.force_shapecast_update()
	
	# TYPING: Typed iterator for the loop
	for i: int in range(%CameraPosShapeCast3D.get_collision_count()):
		if %CameraPosShapeCast3D.get_collider(i) == %SwimmableArea3D:
			return true
			
	return false

func _update_mesh() -> void:
	if get_node_or_null("%CollisionShape3D"):
		%CollisionShape3D.shape.size = self.size

func _process(delta: float) -> void:
	_update_mesh()
	if self.material is StandardMaterial3D:
		if not Engine.is_editor_hint():
			self.material.uv1_offset += water_texture_move_speed * delta
		self.material.uv1_scale = Vector3(water_texture_uv_scale,water_texture_uv_scale,water_texture_uv_scale)
		self.material.albedo_color = water_color
	%FogVolume.material.set_shader_parameter("albedo", fog_color)
	%FogVolume.material.set_shader_parameter("emission", fog_color)
	%FogVolume.size = self.size
	%FogVolume.fade_distance = self.fog_fade_dist
	if not Engine.is_editor_hint():
		if should_draw_camera_underwater_effect():
			%WaterRippleOverlay.visible = true
			%FogVolume.material.set_shader_parameter("edge_fade", 0.1)
			last_frame_drew_underwater_effect = Engine.get_process_frames()
		else:
			%WaterRippleOverlay.visible = false
			%FogVolume.material.set_shader_parameter("edge_fade", 1.1)
