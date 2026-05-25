class_name FluidEmitter
extends Node3D

## Fluid Emitter System
## Simulates a thick "gel" or rain stream falling from a roof.

const FLUID_RENDER_LAYER = 20

@export var speed: float = 5.0:
	set(value):
		speed = value
		_update_particle_properties()

@export var gravity: Vector3 = Vector3(0.0, -9.8, 0.0):
	set(value):
		gravity = value
		_update_particle_properties()

@export var spawn_rate: int = 100:
	set(value):
		spawn_rate = value
		_update_particle_properties()

@export var fluid_color: Color = Color(0.2, 0.5, 0.9, 1.0):
	set(value):
		fluid_color = value
		_update_shader_parameters()

@export var drop_size: float = 0.5:
	set(value):
		drop_size = value
		_update_particle_properties()

@export var emission_box_extents: Vector3 = Vector3(2.0, 0.1, 2.0):
	set(value):
		emission_box_extents = value
		_update_particle_properties()

var _particles: GPUParticles3D
var _process_material: ParticleProcessMaterial
var _draw_pass_material: StandardMaterial3D
var _fluid_material: ShaderMaterial = ShaderMaterial.new()

@onready var _viewport: SubViewport = SubViewport.new()
@onready var _viewport_camera: Camera3D = Camera3D.new()
@onready var _canvas_layer: CanvasLayer = CanvasLayer.new()
@onready var _color_rect: ColorRect = ColorRect.new()


func _ready() -> void:
	_setup_viewport()
	_setup_particles()
	_setup_canvas()
	_update_particle_properties()


func _setup_viewport() -> void:
	_viewport.transparent_bg = true
	_viewport.size = get_viewport().size
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Isolate rendering using layers
	_viewport_camera.cull_mask = 1 << (FLUID_RENDER_LAYER - 1)

	# The viewport requires a camera to render 3D objects
	_viewport.add_child(_viewport_camera)

	add_child(_viewport)


func _setup_particles() -> void:
	_particles = GPUParticles3D.new()
	_process_material = ParticleProcessMaterial.new()
	_draw_pass_material = StandardMaterial3D.new()

	_draw_pass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_draw_pass_material.albedo_color = Color(1.0, 1.0, 1.0, 0.1)  # Soft particles for metaball
	_draw_pass_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.material = _draw_pass_material

	_particles.process_material = _process_material
	_particles.draw_pass_1 = sphere_mesh

	# Isolate particle rendering to the fluid render layer so main camera doesn't see raw particles
	_particles.layers = 1 << (FLUID_RENDER_LAYER - 1)
	_particles.extra_cull_margin = 10000.0

	_viewport.add_child(_particles)


func _setup_canvas() -> void:
	_canvas_layer.layer = 100  # Render on top

	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Prevent the ColorRect from blocking mouse input
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader: Shader = load("res://shader_scripts/fluid_blend.gdshader")
	_fluid_material.shader = shader

	var viewport_texture: ViewportTexture = _viewport.get_texture()
	_fluid_material.set_shader_parameter("fluid_texture", viewport_texture)
	_fluid_material.set_shader_parameter("fluid_color", fluid_color)

	_color_rect.material = _fluid_material
	_canvas_layer.add_child(_color_rect)

	add_child(_canvas_layer)


func _update_shader_parameters() -> void:
	if is_instance_valid(_fluid_material):
		_fluid_material.set_shader_parameter("fluid_color", fluid_color)


func _update_particle_properties() -> void:
	if not is_instance_valid(_particles) or not is_instance_valid(_process_material):
		return

	_particles.amount = spawn_rate

	_process_material.gravity = gravity
	_process_material.direction = Vector3(0.0, -1.0, 0.0)
	_process_material.initial_velocity_min = speed * 0.8
	_process_material.initial_velocity_max = speed * 1.2

	_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_process_material.emission_box_extents = emission_box_extents

	var sphere_mesh: SphereMesh = _particles.draw_pass_1 as SphereMesh
	if is_instance_valid(sphere_mesh):
		sphere_mesh.radius = drop_size
		sphere_mesh.height = drop_size * 2.0


func _process(_delta: float) -> void:
	_sync_camera()
	_sync_viewport_size()
	_sync_particle_transform()


func _sync_camera() -> void:
	var main_camera: Camera3D = get_viewport().get_camera_3d()
	if is_instance_valid(main_camera) and is_instance_valid(_viewport_camera):
		_viewport_camera.global_transform = main_camera.global_transform
		_viewport_camera.fov = main_camera.fov
		_viewport_camera.near = main_camera.near
		_viewport_camera.far = main_camera.far
		_viewport_camera.projection = main_camera.projection

		# Ensure main camera doesn't render the raw fluid particles
		var layer_bit: int = 1 << (FLUID_RENDER_LAYER - 1)
		if (main_camera.cull_mask & layer_bit) != 0:
			main_camera.cull_mask &= ~layer_bit


func _sync_viewport_size() -> void:
	if is_instance_valid(_viewport):
		var current_size: Vector2i = get_viewport().size
		if _viewport.size != current_size:
			_viewport.size = current_size


func _sync_particle_transform() -> void:
	if is_instance_valid(_particles):
		_particles.global_transform = self.global_transform
