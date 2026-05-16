@tool
extends GPUParticles3D

# --- INSTRUCTIONS ---
# 1. Assign this script to a GPUParticles3D node.
# 2. Assign textures for 'droplet_shape_tex' and 'droplet_normal_tex'.
#    (If left empty, procedural approximations will be generated, but are less detailed).
# 3. Adjust particle physics (Amount, Lifetime, Velocity, Emission Shape) natively in the Inspector!

# --- EXPORTS ---
@export_group("Rain Textures")
# The alpha mask of the droplet (capsule or stretched drop shape)
@export var droplet_shape_tex: Texture2D:
	set(value):
		droplet_shape_tex = value
		_apply_textures()

# The normal map of the droplet (curved surface data)
@export var droplet_normal_tex: Texture2D:
	set(value):
		droplet_normal_tex = value
		_apply_textures()

@export_group("Rain Material")
@export_color_no_alpha var rain_tint: Color = Color(0.9, 0.95, 1.0):
	set(value):
		rain_tint = value
		_update_shader_params()

@export_range(0.0, 1.0, 0.01) var base_alpha: float = 0.5:
	set(value):
		base_alpha = value
		_update_shader_params()

# Determines how heavily the background bends. 
# NOTE: Use NEGATIVE values to pull from the "opposite" direction (inverting the image like a real water drop).
@export_range(-2.0, 2.0, 0.01) var refraction_strength: float = 0.35:
	set(value):
		refraction_strength = value
		_update_shader_params()

# Adds simple specular reflections for liquid sheen.
@export_range(0.0, 1.0, 0.01) var surface_shine: float = 0.6:
	set(value):
		surface_shine = value
		_update_shader_params()

# Controls how muddy/distorted the background inside the drop gets.
@export_range(0.0, 5.0, 0.1) var background_blur: float = 1.5:
	set(value):
		background_blur = value
		_update_shader_params()
		
@export var droplet_size: Vector2 = Vector2(0.5, 0.5):
	set(value):
		droplet_size = value
		_update_draw_mesh()


# --- INTERNAL RESOURCES ---
var _proc_mat: ParticleProcessMaterial
var _draw_mesh: QuadMesh
var _shader_mat: ShaderMaterial


# --- EMBEDDED REFRACTION SHADER ---
const RAIN_SHADER_CODE = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform sampler2D albedo_tex : hint_default_black, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;

// CRITICAL: filter_linear_mipmap is required to use textureLod() for blurring!
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform vec4 tint_color : source_color = vec4(0.9, 0.95, 1.0, 0.5);
uniform float refraction_strength = 0.35;
uniform float shine_strength = 0.6;
uniform float blur_amount = 1.5; // Controls the muddy background blur

void vertex() {
    // Forces the 2D plane to always face the camera without crashing
    mat4 modified_model_view = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
    modified_model_view = modified_model_view * mat4(
        vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), 
        vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), 
        vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), 
        vec4(0.0, 0.0, 0.0, 1.0)
    );
    MODELVIEW_MATRIX = modified_model_view;
    MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
    vec4 base = texture(albedo_tex, UV);
    vec3 n_tex = texture(normal_tex, UV).rgb * 2.0 - 1.0; 
    
    vec4 pColor = COLOR;
    float final_mask = base.r * tint_color.a * pColor.a;
    
    if (final_mask < 0.1) {
        discard;
    }

    // --- TRUE FISHEYE CONVEX LENS ---
    // Multiplied heavily to create massive distortion. 
    // If refraction_strength is negative, it pulls from the opposite direction.
    vec2 normal_offset = n_tex.xy * (refraction_strength * 20.0) * final_mask;
    vec2 dist_uv = SCREEN_UV + normal_offset;

    // --- CHROMATIC ABERRATION ---
    // Separates the RGB channels to make the distortion look muddier and thicker.
    float chrom_abb = 0.08 * refraction_strength * final_mask;
    
    // --- BACKGROUND BLUR ---
    // textureLod samples blurry mipmaps based on your 'background_blur' slider.
    float r = textureLod(screen_tex, dist_uv + vec2(chrom_abb, 0.0), blur_amount).r;
    float g = textureLod(screen_tex, dist_uv, blur_amount).g;
    float b = textureLod(screen_tex, dist_uv - vec2(chrom_abb, 0.0), blur_amount).b;
    
    vec3 refracted_bg = vec3(r, g, b);

    // --- ENHANCED SHINE ---
    vec3 light_dir = normalize(vec3(0.1, 0.5, 0.8));
    float spec = max(dot(n_tex, light_dir), 0.0);
    vec3 shine = pow(spec, 8.0) * shine_strength * vec3(1.0);
    
    ALBEDO = refracted_bg * tint_color.rgb;
    ALBEDO += shine * final_mask;
    ALPHA = final_mask;
}
"""

func _ready() -> void:
	_init_system()
	_apply_settings()

func _init_system() -> void:
	# 1. Mesh setup
	if draw_pass_1 == null or not (draw_pass_1 is QuadMesh):
		_draw_mesh = QuadMesh.new()
		draw_pass_1 = _draw_mesh
	else:
		_draw_mesh = draw_pass_1
		
	# 2. Material setup
	if _shader_mat == null:
		_shader_mat = ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = RAIN_SHADER_CODE
		_shader_mat.shader = shader
		_draw_mesh.material = _shader_mat
	
	# 3. Process setup - Only overwrite if it doesn't exist so we don't ruin user tweaks
	if process_material == null or not (process_material is ParticleProcessMaterial):
		_proc_mat = ParticleProcessMaterial.new()
		process_material = _proc_mat
		
		# Inject sensible default physics so it works out of the box
		_proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		_proc_mat.emission_box_extents = Vector3(10.0, 5.0, 10.0)
		_proc_mat.direction = Vector3.DOWN
		_proc_mat.spread = 2.0
		_proc_mat.gravity = Vector3(0, -9.8, 0)
		_proc_mat.initial_velocity_min = 35.0
		_proc_mat.initial_velocity_max = 45.0
		_proc_mat.particle_flag_align_y = false
	else:
		_proc_mat = process_material

func _apply_settings() -> void:
	# Basic GPU particle flags that optimize rendering
	explosiveness = 0.0
	interpolate = true
	draw_passes = 1
	collision_base_size = 0.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail_enabled = false
	
	# Pre-simulate the rain based on user's native lifetime setting
	preprocess = lifetime
	
	_update_draw_mesh()
	_apply_textures()
	_update_shader_params()

func _update_draw_mesh() -> void:
	if _draw_mesh:
		_draw_mesh.size = droplet_size

func _apply_textures() -> void:
	if _shader_mat == null: return
	
	if droplet_shape_tex:
		_shader_mat.set_shader_parameter("albedo_tex", droplet_shape_tex)
	else:
		# Fallback placeholder shape
		_shader_mat.set_shader_parameter("albedo_tex", _generate_fallback_albedo())

	if droplet_normal_tex:
		_shader_mat.set_shader_parameter("normal_tex", droplet_normal_tex)
	else:
		# Fallback placeholder normal
		_shader_mat.set_shader_parameter("normal_tex", _generate_fallback_normal())

func _update_shader_params() -> void:
	if _shader_mat == null: return
	
	var final_tint := rain_tint
	final_tint.a = base_alpha
	_shader_mat.set_shader_parameter("tint_color", final_tint)
	_shader_mat.set_shader_parameter("refraction_strength", refraction_strength)
	_shader_mat.set_shader_parameter("shine_strength", surface_shine)
	_shader_mat.set_shader_parameter("blur_amount", background_blur)

# --- Fallback Texture Generation (for testing without external assets) ---

func _generate_fallback_albedo() -> Texture2D:
	var image := Image.create(32, 128, false, Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var u := (float(x) / float(image.get_width() - 1)) * 2.0 - 1.0
			var y_stretch := (float(y) / float(image.get_height() - 1)) * 2.0 - 1.0
			var dist := sqrt(u*u + (y_stretch*y_stretch)*0.01)
			var val := 1.0 - smoothstep(0.7, 0.9, dist)
			image.set_pixel(x, y, Color(val, val, val, val))
	return ImageTexture.create_from_image(image)

func _generate_fallback_normal() -> Texture2D:
	var image := Image.create(32, 128, false, Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var u := float(x) / float(image.get_width() - 1)
			var y_pct := float(y) / float(image.get_height() - 1)
			var nx := (u * 2.0 - 1.0) * 0.8
			var ny := (y_pct * 2.0 - 1.0) * 0.1 
			var nz := sqrt(1.0 - nx*nx - ny*ny)
			image.set_pixel(x, y, Color(nx * 0.5 + 0.5, ny * 0.5 + 0.5, nz * 0.5 + 0.5, 1.0))
	return ImageTexture.create_from_image(image)
