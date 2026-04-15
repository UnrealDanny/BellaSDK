@tool
extends MeshInstance3D # Or CSGMesh3D depending on what you chose in Step 1

@export var water_color := Color(0.31, 0.54, 0.87, 0.38)
@export var fog_color := Color(0, 0.04, 0.16)
@export_range(0.0, 250.0) var fog_fade_dist := 5.0

# Add these to match the shader
@export var wave_amplitude := 0.2
@export var wave_frequency := 2.0
@export var wave_speed := 1.0

var floating_bodies: Array[RigidBody3D] = []

static var last_frame_drew_underwater_effect : int = -999

func _ready() -> void:
	self.process_priority = 999 
	
	# Connect the Area3D signals so we know when an object splashes in
	if get_node_or_null("%SwimmableArea3D"):
		%SwimmableArea3D.body_entered.connect(_on_swimmable_area_body_entered)
		%SwimmableArea3D.body_exited.connect(_on_swimmable_area_body_exited)

# --- THE UPDATE LOOP ---

#func _physics_process(_delta: float) -> void:
	## Continuously update the water height for all objects currently in the pool
	#for i in range(floating_bodies.size() - 1, -1, -1):
		#var body := floating_bodies[i]
		#
		## Safety check in case the object was destroyed/freed while in the water
		#if is_instance_valid(body):
			#if body.is_in_water:
				#body.current_water_height = get_wave_height_at_pos(body.global_position)
		#else:
			#floating_bodies.remove_at(i)
			
# NEW FUNCTION: Replicates the shader math to find the exact surface height at the camera's position
func get_wave_height_at_pos(global_pos: Vector3) -> float:
	var local_pos := to_local(global_pos)
	
	# Time must match the shader's TIME variable perfectly
	var time := (Time.get_ticks_msec() / 1000.0) * wave_speed
	
	# 1:1 replica of the vertex shader math to find the exact wave crest/trough
	var h1: float = sin(local_pos.x * wave_frequency + time) * wave_amplitude
	var h2: float = sin((local_pos.x * 0.8 + local_pos.z * 0.6) * (wave_frequency * 1.5) - time * 1.2) * (wave_amplitude * 0.6)
	var h3: float = cos((local_pos.z * 1.2 - local_pos.x * 0.3) * (wave_frequency * 0.8) + time * 0.7) * (wave_amplitude * 0.4)
	
	# Calculate the flat surface height + the chaotic wave math
	# Note: Assumes your MeshInstance3D is using a BoxMesh. 
	var local_surface_y: float = (mesh.size.y / 2.0) + h1 + h2 + h3 
	
	var surface_global_pos := to_global(Vector3(local_pos.x, local_surface_y, local_pos.z))
	return surface_global_pos.y

func should_draw_camera_underwater_effect() -> bool: 
	var viewport: Viewport = get_viewport()
	var camera: Camera3D = viewport.get_camera_3d() if viewport else null
	
	if not camera: return false
	if last_frame_drew_underwater_effect == Engine.get_process_frames(): return false
	
	%CameraPosShapeCast3D.global_position = camera.global_position
	%CameraPosShapeCast3D.force_shapecast_update()
	
	var in_swimmable_area := false
	for i: int in range(%CameraPosShapeCast3D.get_collision_count()):
		if %CameraPosShapeCast3D.get_collider(i) == %SwimmableArea3D:
			in_swimmable_area = true
			break
			
	# If we are inside the rough bounds of the Area3D, do the precise wave check
	if in_swimmable_area:
		# Check if the camera's Y is BELOW the mathematical wave height at that exact spot
		if camera.global_position.y < get_wave_height_at_pos(camera.global_position):
			return true
			
	return false

func _process(_delta: float) -> void:
	# Update shader parameters dynamically so editor sliders work
	if self.material_override is ShaderMaterial: # Using material_override is usually safer for MeshInstances
		var mat := self.material_override as ShaderMaterial
		mat.set_shader_parameter("albedo", water_color)
		mat.set_shader_parameter("wave_amplitude", wave_amplitude)
		mat.set_shader_parameter("wave_frequency", wave_frequency)
		mat.set_shader_parameter("wave_speed", wave_speed)

	# Keep your fog logic...
	%FogVolume.material.set_shader_parameter("albedo", fog_color)
	%FogVolume.material.set_shader_parameter("emission", fog_color)
	%FogVolume.fade_distance = self.fog_fade_dist
	
	if not Engine.is_editor_hint():
		if should_draw_camera_underwater_effect():
			%WaterRippleOverlay.visible = true
			%FogVolume.material.set_shader_parameter("edge_fade", 0.1)
			last_frame_drew_underwater_effect = Engine.get_process_frames()
		else:
			%WaterRippleOverlay.visible = false
			%FogVolume.material.set_shader_parameter("edge_fade", 1.1)

# --- PHYSICS & BUOYANCY SIGNALS ---

func _on_swimmable_area_body_entered(body: Node3D) -> void:
	if body is PickableObject:
		if not floating_bodies.has(body):
			floating_bodies.append(body)
			body.is_in_water = true
			# Pass the WaterMaker reference directly to the object!
			body.current_water_node = self 

func _on_swimmable_area_body_exited(body: Node3D) -> void:
	# THE FIX: Only check the array if the body is actually a PickableObject
	if body is PickableObject:
		if floating_bodies.has(body):
			floating_bodies.erase(body)
			body.is_in_water = false 
			body.current_water_node = null
